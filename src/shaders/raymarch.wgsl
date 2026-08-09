const MAX_RAY_STEPS: i32 = {{RAY_STEPS}};
const SHADOW_STEPS: i32 = {{SHADOW_STEPS}};
struct PointInstance {
          pos_scale: vec4<f32>,
          rot: vec4<f32>,
          color_csg: vec4<f32>,
          light_fields: vec4<f32>,
          interaction_fields: vec4<f32>,
          em_fields: vec4<f32>,
          shape_info: vec4<f32>,
      }
      struct Cell {
          header: vec4<f32>,
          ids: array<f32, {{MAX_IDS}}>,
      }
      struct SunData {
          dir: vec4<f32>,
          color: vec4<f32>,
          params: vec4<f32>,
      }
      struct Uniforms { 
          time: f32, 
          width: f32, 
          height: f32, 
          cell_size: f32,
          cam_pos: vec4<f32>, 
          cam_dir: vec4<f32>,
          cam_right: vec4<f32>,
          cam_up: vec4<f32>,
          bg_color: vec4<f32>,
          grid_dims: vec4<f32>,
          grid_origin: vec4<f32>,
          shadow_ao_quality: vec4<f32>,
          terrain_params1: vec4<f32>,
          terrain_params2: vec4<f32>,
          terrain_params3: vec4<f32>,
          cloud_params1: vec4<f32>,
          cloud_params2: vec4<f32>,
          misc_params: vec4<f32>,
          suns: array<SunData, 8>
      }
      @group(0) @binding(14) var<storage, read> instances: array<PointInstance>;
      struct CsgNode {
          info: vec4<f32>,
          pos: vec4<f32>,
          rot: vec4<f32>,
          params: vec4<f32>,
      }
      struct ChunkLookup {
          origin: vec4<i32>,
          slots: array<vec4<i32>, 8192>,
          skip_grid: array<vec4<i32>, 128>,
      }
      @group(0) @binding(0) var<storage, read> grid: array<Cell>;
      @group(0) @binding(1) var<uniform> u: Uniforms;
      @group(0) @binding(2) var<storage, read> csg_nodes: array<CsgNode>;
      @group(0) @binding(3) var voxel_texture: texture_3d<f32>;
      @group(0) @binding(4) var voxel_sampler: sampler;
      @group(0) @binding(5) var<storage, read> chunk_lookup: ChunkLookup;
      @group(0) @binding(6) var noise_texture: texture_3d<f32>;
      @group(0) @binding(7) var noise_sampler: sampler;
      @group(0) @binding(8) var light_texture: texture_3d<f32>;
      @group(0) @binding(9) var interaction_texture: texture_3d<f32>;
      @group(0) @binding(10) var water_texture: texture_3d<f32>;
      @group(0) @binding(11) var gas_texture: texture_3d<f32>;
      @group(0) @binding(12) var em_texture: texture_3d<f32>;
      @group(0) @binding(13) var gravity_texture: texture_3d<f32>;
      @group(0) @binding(15) var voxel_baked_values_texture: texture_3d<f32>;

      var<private> fractal_trap: f32 = 0.0;

      fn positive_mod(n: i32, m: i32) -> i32 {
          let r = n % m;
          if (r < 0) {
              return r + m;
          }
          return r;
      }

      fn getTerrainDistanceScale() -> f32 {
           let plains_scale = u.terrain_params1.x;
           let canyons_scale = u.terrain_params1.z;
           let mountains_scale = u.terrain_params2.x;
           let global_frequency = u.terrain_params2.w;
           
           let max_scale = max(plains_scale, max(canyons_scale, mountains_scale));
           let safety_factor = 1.0 / (1.0 + max_scale * global_frequency * 0.015);
           return 0.55 * safety_factor;
       }

      fn hash2d(x: f32, z: f32) -> f32 {
          let s = sin(x * 12.9898 + z * 78.233);
          let mult = s * 43758.5453123;
          return mult - floor(mult);
      }

      fn noise2d(x: f32, z: f32) -> f32 {
          let fx = floor(x);
          let fz = floor(z);
          let tx = x - fx;
          let tz = z - fz;
          
          let v00 = hash2d(fx, fz);
          let v10 = hash2d(fx + 1.0, fz);
          let v01 = hash2d(fx, fz + 1.0);
          let v11 = hash2d(fx + 1.0, fz + 1.0);
          
          let u = tx * tx * (3.0 - 2.0 * tx);
          let v = tz * tz * (3.0 - 2.0 * tz);
          
          let x0 = mix(v00, v10, u);
          let x1 = mix(v01, v11, u);
          
          return mix(x0, x1, v);
      }

      fn fbm2d(x: f32, z: f32) -> f32 {
          let n1 = noise2d(x, z);
          let n2 = 0.5 * noise2d(x * 2.0, z * 2.0);
          let n3 = 0.25 * noise2d(x * 4.0, z * 4.0);
          return n1 + n2 + n3;
      }

      fn rigid_fbm2d(x: f32, z: f32) -> f32 {
          let n1 = 1.0 - abs(noise2d(x, z) * 2.0 - 1.0);
          let n2 = 0.5 * (1.0 - abs(noise2d(x * 2.0, z * 2.0) * 2.0 - 1.0));
          let n3 = 0.25 * (1.0 - abs(noise2d(x * 4.0, z * 4.0) * 2.0 - 1.0));
          return n1 + n2 + n3;
      }

      fn fade(t: f32) -> f32 {
          return t * t * (3.0 - 2.0 * t);
      }

      fn getBiomeWeights(x: f32, z: f32) -> vec3<f32> {
          let b_val = noise2d(x * 0.003, z * 0.003);
          let w1 = clamp(1.0 - abs(b_val - 0.2) / 0.35, 0.0, 1.0);
          let w2 = clamp(1.0 - abs(b_val - 0.5) / 0.35, 0.0, 1.0);
          let w3 = clamp(1.0 - abs(b_val - 0.8) / 0.35, 0.0, 1.0);
          let sum = w1 + w2 + w3;
          let sum_safe = select(sum, 0.0001, sum < 0.0001);
          return vec3<f32>(w1, w2, w3) / sum_safe;
      }

      fn get_terrain_height(x: f32, z: f32) -> f32 {
          let W = getBiomeWeights(x, z);
          
          let plains_scale = u.terrain_params1.x;
          let plains_offset = u.terrain_params1.y;
          let canyons_scale = u.terrain_params1.z;
          let canyons_offset = u.terrain_params1.w;
          let mountains_scale = u.terrain_params2.x;
          let mountains_offset = u.terrain_params2.y;

          let h_plains = fbm2d(x * 0.015, z * 0.015) * plains_scale + plains_offset;
          
          let base_canyon = fbm2d(x * 0.012, z * 0.012);
          let bc5 = base_canyon * 5.0;
          let fbc = floor(bc5);
          let tbc = bc5 - fbc;
          let stepped_canyon = fbc + 0.1 * fade(tbc);
          let h_canyons = (stepped_canyon / 5.0) * canyons_scale + canyons_offset;
          
          let h_mountains = rigid_fbm2d(x * 0.01, z * 0.01) * mountains_scale + mountains_offset;
          
          return W.x * h_plains + W.y * h_canyons + W.z * h_mountains;
      }

      fn hash3d(x: f32, y: f32, z: f32) -> f32 {
          let s = sin(x * 12.9898 + y * 78.233 + z * 144.7272);
          let mult = s * 43758.5453123;
          return mult - floor(mult);
      }

      fn noise3d(x: f32, y: f32, z: f32) -> f32 {
          let fx = floor(x);
          let fy = floor(y);
          let fz = floor(z);
          let tx = x - fx;
          let ty = y - fy;
          let tz = z - fz;
          
          let v000 = hash3d(fx, fy, fz);
          let v100 = hash3d(fx + 1.0, fy, fz);
          let v010 = hash3d(fx, fy + 1.0, fz);
          let v110 = hash3d(fx + 1.0, fy + 1.0, fz);
          let v001 = hash3d(fx, fy, fz + 1.0);
          let v101 = hash3d(fx + 1.0, fy, fz + 1.0);
          let v011 = hash3d(fx, fy + 1.0, fz + 1.0);
          let v111 = hash3d(fx + 1.0, fy + 1.0, fz + 1.0);
          
          let u = tx * tx * (3.0 - 2.0 * tx);
          let v = ty * ty * (3.0 - 2.0 * ty);
          let w = tz * tz * (3.0 - 2.0 * tz);
          
          let x00 = mix(v000, v100, u);
          let x10 = mix(v010, v110, u);
          let x01 = mix(v001, v101, u);
          let x11 = mix(v011, v111, u);
          
          let y0 = mix(x00, x10, v);
          let y1 = mix(x01, x11, v);
          
          return mix(y0, y1, w);
      }

      fn getChunkSlot(chunk_q: vec3<i32>) -> i32 {
          if (any(chunk_q < vec3<i32>(0)) || any(chunk_q >= vec3<i32>(32))) {
              return -1;
          }
          let mx = u32(chunk_q.x) >> 2u;
          let my = u32(chunk_q.y) >> 2u;
          let mz = u32(chunk_q.z) >> 2u;
          let skip_idx = mx + (my << 3u) + (mz << 6u);
          let skip_val = chunk_lookup.skip_grid[skip_idx >> 2u][skip_idx & 3];
          if (skip_val == 0) {
              return -1;
          }
          let idx = chunk_q.x + chunk_q.y * 32 + chunk_q.z * 1024;
          return i32(chunk_lookup.slots[u32(idx) >> 2u][idx & 3]);
      }

      fn getVoxelAt(gx: i32, gy: i32, gz: i32, only_dist: bool) -> vec4<f32> {
          let qx = gx >> {{LOG_RES}}u;
          let qy = gy >> {{LOG_RES}}u;
          let qz = gz >> {{LOG_RES}}u;
          
          let lx = gx & {{VOXEL_RES_SUB_1}}i;
          let ly = gy & {{VOXEL_RES_SUB_1}}i;
          let lz = gz & {{VOXEL_RES_SUB_1}}i;
          
          let slot = getChunkSlot(vec3<i32>(qx, qy, qz) - chunk_lookup.origin.xyz);
          
          if (slot >= 0) {
              let slot_x = slot % {{SLOTS_PER_DIM}};
              let slot_y = (slot / {{SLOTS_PER_DIM}}) % {{SLOTS_PER_DIM}};
              let slot_z = slot / {{SLOTS_PER_DIM_SQ}};
              
              let atlas_coord = vec3<i32>((slot_x * {{VOXEL_RES}}i) + lx, (slot_y * {{VOXEL_RES}}i) + ly, (slot_z * {{VOXEL_RES}}i) + lz);
              let val = textureLoad(voxel_texture, atlas_coord, 0);
              if (only_dist) {
                  return vec4<f32>(val.xy, 1.0, 1.0);
              }
              let baked = textureLoad(voxel_baked_values_texture, atlas_coord, 0);
              return vec4<f32>(val.xy, baked.xy);
          } else {
              let px = (f32(gx) + 0.5) * u.cell_size;
              let py = (f32(gy) + 0.5) * u.cell_size;
              let pz = (f32(gz) + 0.5) * u.cell_size;
              let final_h = get_terrain_height(px, pz);
              
              let dist_xz = length(vec2<f32>(px, pz) - u.cam_pos.xz);
              let detail_fade = clamp((dist_xz - 256.0) / 128.0, 0.0, 1.0);
              let detail_h = fbm2d(px * 0.005, pz * 0.005) * 1.5 * detail_fade;
              
              let base_terrain_d = py - final_h;
              let terrain_d = (base_terrain_d - detail_h) * getTerrainDistanceScale();
              
              var cave_val = 0.0;
              var cave_sdf = -1000.0;
              if (base_terrain_d < 0.0) {
                  cave_val = noise3d(px * 0.08, py * 0.08, pz * 0.08);
                  cave_sdf = (cave_val - 0.65) * 12.5;
              }
              
              let voxel_d = max(cave_sdf, terrain_d);
              let mat_id = 1.0;
              
              if (only_dist) {
                  return vec4<f32>(voxel_d, mat_id, 1.0, 1.0);
              }

              let h_dx = get_terrain_height(px + 1.0, pz) - final_h;
              let h_dz = get_terrain_height(px, pz + 1.0) - final_h;
              let terrain_normal = normalize(vec3<f32>(-h_dx, 1.0, -h_dz));
              
              let num_suns = u32(round(u.misc_params.x));
              var shadow_factor = -1.0;
              for (var i = 0u; i < num_suns; i = i + 1u) {
                  let light_dir = normalize(u.suns[i].dir.xyz);
                  let dot_val = dot(terrain_normal, light_dir);
                  if (dot_val > shadow_factor) {
                      shadow_factor = dot_val;
                  }
              }
              let fallback_shadow = clamp(0.2 + 0.8 * smoothstep(-0.2, 0.2, shadow_factor), 0.2, 1.0);
              let fallback_ao = clamp(0.3 + 0.7 * terrain_normal.y, 0.1, 1.0);
              
              return vec4<f32>(voxel_d, mat_id, fallback_shadow, fallback_ao);
          }
      }

        fn sampleVoxelGrid(p: vec3<f32>, only_dist: bool) -> vec4<f32> {
            let slot = getChunkSlot(vec3<i32>(floor(p / 32.0)) - chunk_lookup.origin.xyz);
            
            if (slot < 0) {
                let final_h = get_terrain_height(p.x, p.z);
                
                let dist_xz = length(p.xz - u.cam_pos.xz);
                let detail_fade = clamp((dist_xz - 256.0) / 128.0, 0.0, 1.0);
                let detail_h = fbm2d(p.x * 0.005, p.z * 0.005) * 4.5 * detail_fade;
                
                let terrain_d = (p.y - (final_h + detail_h)) * getTerrainDistanceScale();
                let mat_id = 1.0;
                return vec4<f32>(terrain_d, mat_id, 1.0, 1.0);
            }
            
            let tx = p / {{VOXEL_CELL_SIZE}} - vec3<f32>(0.5);
            let c0 = vec3<i32>(floor(tx));
            let f = fract(tx);
            
            let lx = c0.x & {{VOXEL_RES_SUB_1}}i;
            let ly = c0.y & {{VOXEL_RES_SUB_1}}i;
            let lz = c0.z & {{VOXEL_RES_SUB_1}}i;
            
            var v0 = vec4<f32>(1000.0, 0.0, 0.0, 0.0);
            var v1 = vec4<f32>(1000.0, 0.0, 0.0, 0.0);
            var v2 = vec4<f32>(1000.0, 0.0, 0.0, 0.0);
            var v3 = vec4<f32>(1000.0, 0.0, 0.0, 0.0);
            var v4 = vec4<f32>(1000.0, 0.0, 0.0, 0.0);
            var v5 = vec4<f32>(1000.0, 0.0, 0.0, 0.0);
            var v6 = vec4<f32>(1000.0, 0.0, 0.0, 0.0);
            var v7 = vec4<f32>(1000.0, 0.0, 0.0, 0.0);
            
            var tex_val = vec4<f32>(1000.0, 0.0, 0.0, 0.0);
            var best_mat = 0.0;
            let local_pos = vec3<f32>(f32(lx), f32(ly), f32(lz)) + f;
            if (all(local_pos >= vec3<f32>(0.5)) && all(local_pos <= vec3<f32>({{VOXEL_RES_SUB_1}}.0))) {
                let slot_x = slot % {{SLOTS_PER_DIM}};
                let slot_y = (slot / {{SLOTS_PER_DIM}}) % {{SLOTS_PER_DIM}};
                let slot_z = slot / {{SLOTS_PER_DIM_SQ}};
                let base_uv3d = vec3<f32>(f32(slot_x * {{VOXEL_RES}}i), f32(slot_y * {{VOXEL_RES}}i), f32(slot_z * {{VOXEL_RES}}i));
                let sample_coords = (base_uv3d + local_pos + vec3<f32>(0.5)) / 384.0;
                tex_val = textureSampleLevel(voxel_texture, voxel_sampler, sample_coords, 0.0);
                tex_val.r = min(tex_val.r, 1.5);
                let closest_lx = i32(round(local_pos.x));
                let closest_ly = i32(round(local_pos.y));
                let closest_lz = i32(round(local_pos.z));
                let atlas_coord = vec3<i32>((slot_x * {{VOXEL_RES}}i) + closest_lx, (slot_y * {{VOXEL_RES}}i) + closest_ly, (slot_z * {{VOXEL_RES}}i) + closest_lz);
                let raw_val = textureLoad(voxel_texture, atlas_coord, 0);
                best_mat = raw_val.g;
                if (!only_dist) {
                    let baked_val = textureSampleLevel(voxel_baked_values_texture, voxel_sampler, sample_coords, 0.0);
                    tex_val.z = baked_val.r;
                    tex_val.w = baked_val.g;
                } else {
                    tex_val.z = 1.0;
                    tex_val.w = 1.0;
                }
            } else {
               v0 = getVoxelAt(c0.x,     c0.y,     c0.z,     only_dist);
               v1 = getVoxelAt(c0.x + 1, c0.y,     c0.z,     only_dist);
               v2 = getVoxelAt(c0.x,     c0.y + 1, c0.z,     only_dist);
               v3 = getVoxelAt(c0.x + 1, c0.y + 1, c0.z,     only_dist);
               v4 = getVoxelAt(c0.x,     c0.y,     c0.z + 1, only_dist);
               v5 = getVoxelAt(c0.x + 1, c0.y,     c0.z + 1, only_dist);
               v6 = getVoxelAt(c0.x,     c0.y + 1, c0.z + 1, only_dist);
               v7 = getVoxelAt(c0.x + 1, c0.y + 1, c0.z + 1, only_dist);
               
               v0.x = min(v0.x, 1.5);
               v1.x = min(v1.x, 1.5);
               v2.x = min(v2.x, 1.5);
               v3.x = min(v3.x, 1.5);
               v4.x = min(v4.x, 1.5);
               v5.x = min(v5.x, 1.5);
               v6.x = min(v6.x, 1.5);
               v7.x = min(v7.x, 1.5);
               
               best_mat = v0.y;
               var min_d_corner = v0.x;
               if (v1.x < min_d_corner) { min_d_corner = v1.x; best_mat = v1.y; }
               if (v2.x < min_d_corner) { min_d_corner = v2.x; best_mat = v2.y; }
               if (v3.x < min_d_corner) { min_d_corner = v3.x; best_mat = v3.y; }
               if (v4.x < min_d_corner) { min_d_corner = v4.x; best_mat = v4.y; }
               if (v5.x < min_d_corner) { min_d_corner = v5.x; best_mat = v5.y; }
               if (v6.x < min_d_corner) { min_d_corner = v6.x; best_mat = v6.y; }
               if (v7.x < min_d_corner) { min_d_corner = v7.x; best_mat = v7.y; }
               
               let sf = f;
               let v_01 = mix(v0, v1, sf.x);
               let v_23 = mix(v2, v3, sf.x);
               let v_45 = mix(v4, v5, sf.x);
               let v_67 = mix(v6, v7, sf.x);
               
               let v_y0 = mix(v_01, v_23, sf.y);
               let v_y1 = mix(v_45, v_67, sf.y);
               
               tex_val = mix(v_y0, v_y1, sf.z);
           }
           
           let dummy_sample = textureSampleLevel(voxel_texture, voxel_sampler, vec3<f32>(0.0), 0.0);
           let dummy = dummy_sample.r * 1e-10;
           
           return vec4<f32>(tex_val.r + dummy, best_mat, tex_val.z, tex_val.w);
       }

      fn getWaterAt(gx: i32, gy: i32, gz: i32) -> vec4<f32> {
          let qx = gx >> {{LOG_RES}}u;
          let qy = gy >> {{LOG_RES}}u;
          let qz = gz >> {{LOG_RES}}u;
          
          let lx = gx & {{VOXEL_RES_SUB_1}}i;
          let ly = gy & {{VOXEL_RES_SUB_1}}i;
          let lz = gz & {{VOXEL_RES_SUB_1}}i;
          
          let slot = getChunkSlot(vec3<i32>(qx, qy, qz) - chunk_lookup.origin.xyz);
          
          if (slot >= 0) {
              let slot_x = slot % {{SLOTS_PER_DIM}};
              let slot_y = (slot / {{SLOTS_PER_DIM}}) % {{SLOTS_PER_DIM}};
              let slot_z = slot / {{SLOTS_PER_DIM_SQ}};
              
              let atlas_coord = vec3<i32>((slot_x * {{VOXEL_RES}}i) + lx, (slot_y * {{VOXEL_RES}}i) + ly, (slot_z * {{VOXEL_RES}}i) + lz);
              return textureLoad(water_texture, atlas_coord, 0);
          } else {
              return vec4<f32>(0.0);
          }
      }

      fn getGasAt(gx: i32, gy: i32, gz: i32) -> vec4<f32> {
          let qx = gx >> {{LOG_RES}}u;
          let qy = gy >> {{LOG_RES}}u;
          let qz = gz >> {{LOG_RES}}u;
          
          let lx = gx & {{VOXEL_RES_SUB_1}}i;
          let ly = gy & {{VOXEL_RES_SUB_1}}i;
          let lz = gz & {{VOXEL_RES_SUB_1}}i;
          
          let slot = getChunkSlot(vec3<i32>(qx, qy, qz) - chunk_lookup.origin.xyz);
          
          if (slot >= 0) {
              let slot_x = slot % {{SLOTS_PER_DIM}};
              let slot_y = (slot / {{SLOTS_PER_DIM}}) % {{SLOTS_PER_DIM}};
              let slot_z = slot / {{SLOTS_PER_DIM_SQ}};
              
              let atlas_coord = vec3<i32>((slot_x * {{VOXEL_RES}}i) + lx, (slot_y * {{VOXEL_RES}}i) + ly, (slot_z * {{VOXEL_RES}}i) + lz);
              return textureLoad(gas_texture, atlas_coord, 0);
          } else {
              return vec4<f32>(0.0);
          }
      }

      fn sampleGasGrid(p: vec3<f32>) -> vec4<f32> {
          let slot = getChunkSlot(vec3<i32>(floor(p / 32.0)) - chunk_lookup.origin.xyz);
          
          if (slot < 0) {
              return vec4<f32>(0.0);
          }
          
          let tx = p / {{VOXEL_CELL_SIZE}} - vec3<f32>(0.5);
          let c0 = vec3<i32>(floor(tx));
          let f = fract(tx);
          
          let lx = c0.x & {{VOXEL_RES_SUB_1}}i;
          let ly = c0.y & {{VOXEL_RES_SUB_1}}i;
          let lz = c0.z & {{VOXEL_RES_SUB_1}}i;
          
          var tex_val = vec4<f32>(0.0);
          let local_pos = vec3<f32>(f32(lx), f32(ly), f32(lz)) + f;
          if (all(local_pos >= vec3<f32>(0.5)) && all(local_pos <= vec3<f32>({{VOXEL_RES_SUB_1}}.0))) {
              let slot_x = slot % {{SLOTS_PER_DIM}};
              let slot_y = (slot / {{SLOTS_PER_DIM}}) % {{SLOTS_PER_DIM}};
              let slot_z = slot / {{SLOTS_PER_DIM_SQ}};
              let base_uv3d = vec3<f32>(f32(slot_x * {{VOXEL_RES}}i), f32(slot_y * {{VOXEL_RES}}i), f32(slot_z * {{VOXEL_RES}}i));
              
              let sample_coords = (base_uv3d + local_pos + vec3<f32>(0.5)) / 384.0;
              tex_val = textureSampleLevel(gas_texture, voxel_sampler, sample_coords, 0.0);
          } else {
             let v0 = getGasAt(c0.x,     c0.y,     c0.z);
             let v1 = getGasAt(c0.x + 1, c0.y,     c0.z);
             let v2 = getGasAt(c0.x,     c0.y + 1, c0.z);
             let v3 = getGasAt(c0.x + 1, c0.y + 1, c0.z);
             let v4 = getGasAt(c0.x,     c0.y,     c0.z + 1);
             let v5 = getGasAt(c0.x + 1, c0.y,     c0.z + 1);
             let v6 = getGasAt(c0.x,     c0.y + 1, c0.z + 1);
             let v7 = getGasAt(c0.x + 1, c0.y + 1, c0.z + 1);
             
             let v_01 = mix(v0, v1, f.x);
             let v_23 = mix(v2, v3, f.x);
             let v_45 = mix(v4, v5, f.x);
             let v_67 = mix(v6, v7, f.x);
             
             let v_y0 = mix(v_01, v_23, f.y);
             let v_y1 = mix(v_45, v_67, f.y);
             
             tex_val = mix(v_y0, v_y1, f.z);
          }
          
          return tex_val;
      }

      fn getEMAt(gx: i32, gy: i32, gz: i32) -> vec4<f32> {
          let qx = gx >> {{LOG_RES}}u;
          let qy = gy >> {{LOG_RES}}u;
          let qz = gz >> {{LOG_RES}}u;
          
          let lx = gx & {{VOXEL_RES_SUB_1}}i;
          let ly = gy & {{VOXEL_RES_SUB_1}}i;
          let lz = gz & {{VOXEL_RES_SUB_1}}i;
          
          let slot = getChunkSlot(vec3<i32>(qx, qy, qz) - chunk_lookup.origin.xyz);
          
          if (slot >= 0) {
              let slot_x = slot % {{SLOTS_PER_DIM}};
              let slot_y = (slot / {{SLOTS_PER_DIM}}) % {{SLOTS_PER_DIM}};
              let slot_z = slot / {{SLOTS_PER_DIM_SQ}};
              
              let atlas_coord = vec3<i32>((slot_x * {{VOXEL_RES}}i) + lx, (slot_y * {{VOXEL_RES}}i) + ly, (slot_z * {{VOXEL_RES}}i) + lz);
              return textureLoad(em_texture, atlas_coord, 0);
          } else {
              return vec4<f32>(0.0);
          }
      }

      fn sampleEMGrid(p: vec3<f32>) -> vec4<f32> {
          let slot = getChunkSlot(vec3<i32>(floor(p / 32.0)) - chunk_lookup.origin.xyz);
          
          if (slot < 0) {
              return vec4<f32>(0.0);
          }
          
          let tx = p / {{VOXEL_CELL_SIZE}} - vec3<f32>(0.5);
          let c0 = vec3<i32>(floor(tx));
          let f = fract(tx);
          
          let lx = c0.x & {{VOXEL_RES_SUB_1}}i;
          let ly = c0.y & {{VOXEL_RES_SUB_1}}i;
          let lz = c0.z & {{VOXEL_RES_SUB_1}}i;
          
          var tex_val = vec4<f32>(0.0);
          let local_pos = vec3<f32>(f32(lx), f32(ly), f32(lz)) + f;
          if (all(local_pos >= vec3<f32>(0.5)) && all(local_pos <= vec3<f32>({{VOXEL_RES_SUB_1}}.0))) {
              let slot_x = slot % {{SLOTS_PER_DIM}};
              let slot_y = (slot / {{SLOTS_PER_DIM}}) % {{SLOTS_PER_DIM}};
              let slot_z = slot / {{SLOTS_PER_DIM_SQ}};
              let base_uv3d = vec3<f32>(f32(slot_x * {{VOXEL_RES}}i), f32(slot_y * {{VOXEL_RES}}i), f32(slot_z * {{VOXEL_RES}}i));
              
              let sample_coords = (base_uv3d + local_pos + vec3<f32>(0.5)) / 384.0;
              tex_val = textureSampleLevel(em_texture, voxel_sampler, sample_coords, 0.0);
          } else {
             let v0 = getEMAt(c0.x,     c0.y,     c0.z);
             let v1 = getEMAt(c0.x + 1, c0.y,     c0.z);
             let v2 = getEMAt(c0.x,     c0.y + 1, c0.z);
             let v3 = getEMAt(c0.x + 1, c0.y + 1, c0.z);
             let v4 = getEMAt(c0.x,     c0.y,     c0.z + 1);
             let v5 = getEMAt(c0.x + 1, c0.y,     c0.z + 1);
             let v6 = getEMAt(c0.x,     c0.y + 1, c0.z + 1);
             let v7 = getEMAt(c0.x + 1, c0.y + 1, c0.z + 1);
             
             let v_01 = mix(v0, v1, f.x);
             let v_23 = mix(v2, v3, f.x);
             let v_45 = mix(v4, v5, f.x);
             let v_67 = mix(v6, v7, f.x);
             
             let v_y0 = mix(v_01, v_23, f.y);
             let v_y1 = mix(v_45, v_67, f.y);
             
             tex_val = mix(v_y0, v_y1, f.z);
          }
          return tex_val;
      }

      fn sampleWaterGrid(p: vec3<f32>) -> vec4<f32> {
          let slot = getChunkSlot(vec3<i32>(floor(p / 32.0)) - chunk_lookup.origin.xyz);
          
          if (slot < 0) {
              return vec4<f32>(0.0);
          }
          
          let tx = p / {{VOXEL_CELL_SIZE}} - vec3<f32>(0.5);
          let c0 = vec3<i32>(floor(tx));
          let f = fract(tx);
          
          let lx = c0.x & {{VOXEL_RES_SUB_1}}i;
          let ly = c0.y & {{VOXEL_RES_SUB_1}}i;
          let lz = c0.z & {{VOXEL_RES_SUB_1}}i;
          
          var tex_val = vec4<f32>(0.0);
          let local_pos = vec3<f32>(f32(lx), f32(ly), f32(lz)) + f;
          if (all(local_pos >= vec3<f32>(0.5)) && all(local_pos <= vec3<f32>({{VOXEL_RES_SUB_1}}.0))) {
              let slot_x = slot % {{SLOTS_PER_DIM}};
              let slot_y = (slot / {{SLOTS_PER_DIM}}) % {{SLOTS_PER_DIM}};
              let slot_z = slot / {{SLOTS_PER_DIM_SQ}};
              let base_uv3d = vec3<f32>(f32(slot_x * {{VOXEL_RES}}i), f32(slot_y * {{VOXEL_RES}}i), f32(slot_z * {{VOXEL_RES}}i));
              
              let sample_coords = (base_uv3d + local_pos + vec3<f32>(0.5)) / 384.0;
              tex_val = textureSampleLevel(water_texture, voxel_sampler, sample_coords, 0.0);
          } else {
             let v0 = getWaterAt(c0.x,     c0.y,     c0.z);
             let v1 = getWaterAt(c0.x + 1, c0.y,     c0.z);
             let v2 = getWaterAt(c0.x,     c0.y + 1, c0.z);
             let v3 = getWaterAt(c0.x + 1, c0.y + 1, c0.z);
             let v4 = getWaterAt(c0.x,     c0.y,     c0.z + 1);
             let v5 = getWaterAt(c0.x + 1, c0.y,     c0.z + 1);
             let v6 = getWaterAt(c0.x,     c0.y + 1, c0.z + 1);
             let v7 = getWaterAt(c0.x + 1, c0.y + 1, c0.z + 1);
             
             let v_01 = mix(v0, v1, f.x);
             let v_23 = mix(v2, v3, f.x);
             let v_45 = mix(v4, v5, f.x);
             let v_67 = mix(v6, v7, f.x);
             
             let v_y0 = mix(v_01, v_23, f.y);
             let v_y1 = mix(v_45, v_67, f.y);
             
             tex_val = mix(v_y0, v_y1, f.z);
          }
          
          return tex_val;
      }

        fn getFieldsAt(gx: i32, gy: i32, gz: i32) -> vec4<f32> {
          let qx = gx >> {{LOG_RES}}u;
          let qy = gy >> {{LOG_RES}}u;
          let qz = gz >> {{LOG_RES}}u;
          
          let lx = gx & {{VOXEL_RES_SUB_1}}i;
          let ly = gy & {{VOXEL_RES_SUB_1}}i;
          let lz = gz & {{VOXEL_RES_SUB_1}}i;
          
          let slot = getChunkSlot(vec3<i32>(qx, qy, qz) - chunk_lookup.origin.xyz);
          
          if (slot >= 0) {
              let slot_x = slot % {{SLOTS_PER_DIM}};
              let slot_y = (slot / {{SLOTS_PER_DIM}}) % {{SLOTS_PER_DIM}};
              let slot_z = slot / {{SLOTS_PER_DIM_SQ}};
              let atlas_coord = vec3<i32>((slot_x * {{VOXEL_RES}}i) + lx, (slot_y * {{VOXEL_RES}}i) + ly, (slot_z * {{VOXEL_RES}}i) + lz);
              return textureLoad(light_texture, atlas_coord, 0);
          } else {
              return vec4<f32>(0.0);
          }
       }

        fn getInteractionAt(gx: i32, gy: i32, gz: i32) -> vec4<f32> {
          let qx = gx >> {{LOG_RES}}u;
          let qy = gy >> {{LOG_RES}}u;
          let qz = gz >> {{LOG_RES}}u;
          
          let lx = gx & {{VOXEL_RES_SUB_1}}i;
          let ly = gy & {{VOXEL_RES_SUB_1}}i;
          let lz = gz & {{VOXEL_RES_SUB_1}}i;
          
          let slot = getChunkSlot(vec3<i32>(qx, qy, qz) - chunk_lookup.origin.xyz);
          
          if (slot >= 0) {
              let slot_x = slot % {{SLOTS_PER_DIM}};
              let slot_y = (slot / {{SLOTS_PER_DIM}}) % {{SLOTS_PER_DIM}};
              let slot_z = slot / {{SLOTS_PER_DIM_SQ}};
              let atlas_coord = vec3<i32>((slot_x * {{VOXEL_RES}}i) + lx, (slot_y * {{VOXEL_RES}}i) + ly, (slot_z * {{VOXEL_RES}}i) + lz);
              return textureLoad(interaction_texture, atlas_coord, 0);
          } else {
              return vec4<f32>(0.0);
          }
       }

        fn sampleFieldsGrid(p: vec3<f32>) -> vec4<f32> {
          let tx = p / {{VOXEL_CELL_SIZE}} - vec3<f32>(0.5);
          let c0 = vec3<i32>(floor(tx));
          let f = fract(tx);
          
          let lx = c0.x & {{VOXEL_RES_SUB_1}}i;
          let ly = c0.y & {{VOXEL_RES_SUB_1}}i;
          let lz = c0.z & {{VOXEL_RES_SUB_1}}i;
          
          let qx = c0.x >> {{LOG_RES}}u;
          let qy = c0.y >> {{LOG_RES}}u;
          let qz = c0.z >> {{LOG_RES}}u;
          let slot = getChunkSlot(vec3<i32>(qx, qy, qz) - chunk_lookup.origin.xyz);
          
          if (slot < 0) {
              return vec4<f32>(0.0);
          }
          
          var v0 = vec4<f32>(0.0);
          var v1 = vec4<f32>(0.0);
          var v2 = vec4<f32>(0.0);
          var v3 = vec4<f32>(0.0);
          var v4 = vec4<f32>(0.0);
          var v5 = vec4<f32>(0.0);
          var v6 = vec4<f32>(0.0);
          var v7 = vec4<f32>(0.0);
          
          var tex_val = vec4<f32>(0.0);
          let local_pos = vec3<f32>(f32(lx), f32(ly), f32(lz)) + f;
          if (all(local_pos >= vec3<f32>(0.5)) && all(local_pos <= vec3<f32>({{VOXEL_RES_SUB_1}}.0))) {
              let slot_x = slot % {{SLOTS_PER_DIM}};
              let slot_y = (slot / {{SLOTS_PER_DIM}}) % {{SLOTS_PER_DIM}};
              let slot_z = slot / {{SLOTS_PER_DIM_SQ}};
              let base_uv3d = vec3<f32>(f32(slot_x * {{VOXEL_RES}}i), f32(slot_y * {{VOXEL_RES}}i), f32(slot_z * {{VOXEL_RES}}i));
              
              let sample_coords = (base_uv3d + local_pos + vec3<f32>(0.5)) / 384.0;
              tex_val = textureSampleLevel(light_texture, voxel_sampler, sample_coords, 0.0);
          } else {
              v0 = getFieldsAt(c0.x,     c0.y,     c0.z);
              v1 = getFieldsAt(c0.x + 1, c0.y,     c0.z);
              v2 = getFieldsAt(c0.x,     c0.y + 1, c0.z);
              v3 = getFieldsAt(c0.x + 1, c0.y + 1, c0.z);
              v4 = getFieldsAt(c0.x,     c0.y,     c0.z + 1);
              v5 = getFieldsAt(c0.x + 1, c0.y,     c0.z + 1);
              v6 = getFieldsAt(c0.x,     c0.y + 1, c0.z + 1);
              v7 = getFieldsAt(c0.x + 1, c0.y + 1, c0.z + 1);
              
              let sf = f;
              let v_01 = mix(v0, v1, sf.x);
              let v_23 = mix(v2, v3, sf.x);
              let v_45 = mix(v4, v5, sf.x);
              let v_67 = mix(v6, v7, sf.x);
              
              let v_y0 = mix(v_01, v_23, sf.y);
              let v_y1 = mix(v_45, v_67, sf.y);
              
              tex_val = mix(v_y0, v_y1, sf.z);
          }
          return tex_val;
      }

        fn sampleInteractionGrid(p: vec3<f32>) -> vec4<f32> {
          let tx = p / {{VOXEL_CELL_SIZE}} - vec3<f32>(0.5);
          let c0 = vec3<i32>(floor(tx));
          let f = fract(tx);
          
          let lx = c0.x & {{VOXEL_RES_SUB_1}}i;
          let ly = c0.y & {{VOXEL_RES_SUB_1}}i;
          let lz = c0.z & {{VOXEL_RES_SUB_1}}i;
          
          let qx = c0.x >> {{LOG_RES}}u;
          let qy = c0.y >> {{LOG_RES}}u;
          let qz = c0.z >> {{LOG_RES}}u;
          let slot = getChunkSlot(vec3<i32>(qx, qy, qz) - chunk_lookup.origin.xyz);
          
          if (slot < 0) {
              return vec4<f32>(0.0);
          }
          
          var v0 = vec4<f32>(0.0);
          var v1 = vec4<f32>(0.0);
          var v2 = vec4<f32>(0.0);
          var v3 = vec4<f32>(0.0);
          var v4 = vec4<f32>(0.0);
          var v5 = vec4<f32>(0.0);
          var v6 = vec4<f32>(0.0);
          var v7 = vec4<f32>(0.0);
          
          var tex_val = vec4<f32>(0.0);
          let local_pos = vec3<f32>(f32(lx), f32(ly), f32(lz)) + f;
          if (all(local_pos >= vec3<f32>(0.5)) && all(local_pos <= vec3<f32>({{VOXEL_RES_SUB_1}}.0))) {
              let slot_x = slot % {{SLOTS_PER_DIM}};
              let slot_y = (slot / {{SLOTS_PER_DIM}}) % {{SLOTS_PER_DIM}};
              let slot_z = slot / {{SLOTS_PER_DIM_SQ}};
              let base_uv3d = vec3<f32>(f32(slot_x * {{VOXEL_RES}}i), f32(slot_y * {{VOXEL_RES}}i), f32(slot_z * {{VOXEL_RES}}i));
              
              let sample_coords = (base_uv3d + local_pos + vec3<f32>(0.5)) / 384.0;
              tex_val = textureSampleLevel(interaction_texture, voxel_sampler, sample_coords, 0.0);
          } else {
              v0 = getInteractionAt(c0.x,     c0.y,     c0.z);
              v1 = getInteractionAt(c0.x + 1, c0.y,     c0.z);
              v2 = getInteractionAt(c0.x,     c0.y + 1, c0.z);
              v3 = getInteractionAt(c0.x + 1, c0.y + 1, c0.z);
              v4 = getInteractionAt(c0.x,     c0.y,     c0.z + 1);
              v5 = getInteractionAt(c0.x + 1, c0.y,     c0.z + 1);
              v6 = getInteractionAt(c0.x,     c0.y + 1, c0.z + 1);
              v7 = getInteractionAt(c0.x + 1, c0.y + 1, c0.z + 1);
              
              let sf = f;
              let v_01 = mix(v0, v1, sf.x);
              let v_23 = mix(v2, v3, sf.x);
              let v_45 = mix(v4, v5, sf.x);
              let v_67 = mix(v6, v7, sf.x);
              
              let v_y0 = mix(v_01, v_23, sf.y);
              let v_y1 = mix(v_45, v_67, sf.y);
              
              tex_val = mix(v_y0, v_y1, sf.z);
          }
          return tex_val;
       }

        fn getUniformFloat(idx: i32) -> f32 {
            if (idx == 0) { return u.time; }
            if (idx == 1) { return u.width; }
            if (idx == 2) { return u.height; }
            if (idx == 3) { return u.cell_size; }
            if (idx == 4) { return u.cam_pos.x; }
            if (idx == 5) { return u.cam_pos.y; }
            if (idx == 6) { return u.cam_pos.z; }
            if (idx == 7) { return u.cam_pos.w; }
            if (idx == 8) { return u.cam_dir.x; }
            if (idx == 9) { return u.cam_dir.y; }
            if (idx == 10) { return u.cam_dir.z; }
            if (idx == 11) { return u.cam_dir.w; }
            if (idx == 12) { return u.cam_right.x; }
            if (idx == 13) { return u.cam_right.y; }
            if (idx == 14) { return u.cam_right.z; }
            if (idx == 15) { return u.cam_right.w; }
            if (idx == 16) { return u.cam_up.x; }
            if (idx == 17) { return u.cam_up.y; }
            if (idx == 18) { return u.cam_up.z; }
            if (idx == 19) { return u.cam_up.w; }
            if (idx == 20) { return u.bg_color.x; }
            if (idx == 21) { return u.bg_color.y; }
            if (idx == 22) { return u.bg_color.z; }
            if (idx == 23) { return u.bg_color.w; }
            if (idx == 24) { return u.grid_dims.x; }
            if (idx == 25) { return u.grid_dims.y; }
            if (idx == 26) { return u.grid_dims.z; }
            if (idx == 27) { return u.grid_dims.w; }
            if (idx == 28) { return u.grid_origin.x; }
            if (idx == 29) { return u.grid_origin.y; }
            if (idx == 30) { return u.grid_origin.z; }
            if (idx == 31) { return u.grid_origin.w; }
            if (idx == 32) { return u.shadow_ao_quality.x; }
            if (idx == 33) { return u.shadow_ao_quality.y; }
            if (idx == 34) { return u.shadow_ao_quality.z; }
            if (idx == 35) { return u.shadow_ao_quality.w; }
            return 0.0;
        }

        fn sampleVoxelGridPoint(p: vec3<f32>, only_dist: bool) -> vec2<f32> {
            let slot = getChunkSlot(vec3<i32>(floor(p / 32.0)) - chunk_lookup.origin.xyz);
            
            if (slot >= 0) {
                let tx = p / {{VOXEL_CELL_SIZE}};
                let c0 = vec3<i32>(floor(tx));
                let val = getVoxelAt(c0.x, c0.y, c0.z, only_dist);
                return vec2<f32>(val.x, val.y);
            } else {
                let final_h = get_terrain_height(p.x, p.z);
                let dist_xz = length(p.xz - u.cam_pos.xz);
                let detail_fade = clamp((dist_xz - 256.0) / 128.0, 0.0, 1.0);
                let detail_h = fbm2d(p.x * 0.005, p.z * 0.005) * 1.5 * detail_fade;
                let terrain_d = (p.y - (final_h + detail_h)) * getTerrainDistanceScale();
                return vec2<f32>(terrain_d, 1.0);
            }
        }

      struct VertexOutput {
          @builtin(position) position: vec4<f32>,
          @location(0) uv: vec2<f32>,
      }

      @vertex
      fn vs_main(@builtin(vertex_index) vi: u32) -> VertexOutput {
          var pos = array<vec2<f32>, 3>(
              vec2<f32>(-1.0, -1.0),
              vec2<f32>( 3.0, -1.0),
              vec2<f32>(-1.0,  3.0)
          );
          var out: VertexOutput;
          out.position = vec4<f32>(pos[vi], 0.0, 1.0);
          out.uv = pos[vi];
          return out;
      }

      fn smin(a: f32, b: f32, k: f32) -> f32 {
          let h = max(k - abs(a - b), 0.0) / k;
          return min(a, b) - h * h * h * k * (1.0 / 6.0);
      }

      fn smax(a: f32, b: f32, k: f32) -> f32 {
          let h = max(k - abs(a - b), 0.0) / k;
          return max(a, b) + h * h * h * k * (1.0 / 6.0);
      }

       struct InterpolatedData {
            fields: vec4<f32>,
            interaction: vec4<f32>,
            color: vec3<f32>,
            emissive: vec3<f32>,
        }

        fn getInterpolatedFieldsAndColor(p: vec3<f32>) -> InterpolatedData {
            let p_local = p - u.grid_origin.xyz;
            let gx = i32(floor(p_local.x / u.cell_size));
            let gy = i32(floor(p_local.y / u.cell_size));
            let gz = i32(floor(p_local.z / u.cell_size));
            var sum_fields = vec4<f32>(0.0);
            var sum_fields_w = 0.0;
            var sum_color = vec3<f32>(0.0);
            var sum_color_w = 0.0;
            var sum_emissive = vec3<f32>(0.0);
            var light_absorption = 1.0;
            if (gx >= 0 && gx < i32(u.grid_dims.x) && gy >= 0 && gy < i32(u.grid_dims.y) && gz >= 0 && gz < i32(u.grid_dims.z)) {
                let idx = gx + i32(u.grid_dims.x) * (gy + i32(u.grid_dims.y) * gz);
                let cell = grid[idx];
                let count = min(i32(round(cell.header.x)), 64);
                for(var i = 0; i < count; i = i + 1) {
                    let s_idx = i32(round(cell.ids[i]));
                    if (s_idx >= 0 && s_idx < 1024) {
                      let s_data = instances[s_idx];
                      let raw_w = s_data.pos_scale.w;
                      if (raw_w != 0.0) {
                        let csg_root_idx = i32(round(s_data.color_csg.w));
                        
                        // Black hole light absorption
                        if (csg_root_idx == -10) {
                            let dist_to_sing = length(p - s_data.pos_scale.xyz);
                            let singularity_r = raw_w;
                            let pull_radius = singularity_r * 4.0;
                            if (dist_to_sing < pull_radius) {
                                let absorption = clamp((dist_to_sing - singularity_r) / (pull_radius - singularity_r), 0.0, 1.0);
                                light_absorption = min(light_absorption, absorption);
                            }
                        }

                        var s = 1.0;
                        if (csg_root_idx <= -99) {
                            s = f32(-99 - csg_root_idx) / 100.0;
                            if (s < 0.05) { s = 0.6; }
                        }
                        let local_p = toLocalSpace(p, s_data.pos_scale.xyz, s_data.rot);
                        let squashed_p = vec3<f32>(local_p.x, local_p.y / s, local_p.z);
                        let d = (length(squashed_p) - raw_w) * min(1.0, s);
                        let w_color = 1.0 / (d * d + 0.01);
                        var w_fields = w_color;
                        
                        var instance_fields = s_data.light_fields;
                        if (instance_fields.w > 0.0) {
                            let wave_phase = u.time * 8.0 - d * 2.0;
                            instance_fields.w += instance_fields.w * (sin(wave_phase) * 0.4 / (d * 0.2 + 1.0));
                        }
                        
                        sum_fields += instance_fields * w_fields;
                        sum_fields_w += w_fields;
                        
                        sum_color += s_data.color_csg.rgb * w_color;
                        sum_color_w += w_color;
                        if (csg_root_idx > -99) {
                            sum_emissive += s_data.color_csg.rgb * w_color * 0.3;
                        }
                      }
                    }
                }
            }
            var out: InterpolatedData;
            out.fields = sampleFieldsGrid(p);
            out.interaction = sampleInteractionGrid(p);
            if (sum_color_w > 0.0) {
                out.color = sum_color / sum_color_w;
            } else {
                out.color = vec3<f32>(0.0);
            }
            out.emissive = sum_emissive * light_absorption;
            return out;
        }

       fn getInterpolatedFields(p: vec3<f32>) -> vec4<f32> {
           return getInterpolatedFieldsAndColor(p).fields;
       }

        fn getWaterRipples(p: vec3<f32>) -> vec3<f32> {
            let p_local = p - u.grid_origin.xyz;
            let gx = i32(floor(p_local.x / u.cell_size));
            let gy = i32(floor(p_local.y / u.cell_size));
            let gz = i32(floor(p_local.z / u.cell_size));
            var ripple_offset = vec3<f32>(0.0);
            
            if (gx >= 0 && gx < i32(u.grid_dims.x) && gy >= 0 && gy < i32(u.grid_dims.y) && gz >= 0 && gz < i32(u.grid_dims.z)) {
                let idx = gx + i32(u.grid_dims.x) * (gy + i32(u.grid_dims.y) * gz);
                let cell = grid[idx];
                let count = min(i32(round(cell.header.x)), {{MAX_IDS}});
                for(var i = 0; i < count; i = i + 1) {
                    let s_idx = i32(round(cell.ids[i]));
                    if (s_idx >= 0 && s_idx < 1024) {
                      let s_data = instances[s_idx];
                      let raw_w = s_data.pos_scale.w;
                      if (raw_w != 0.0) {
                        if (s_data.light_fields.x > 0.0) { continue; } // Ignore explosion colors in default fog/fluid
                        let csg_root_idx = i32(round(s_data.color_csg.w));
                        var s = 1.0;
                        if (csg_root_idx <= -99) {
                            s = f32(-99 - csg_root_idx) / 100.0;
                            if (s < 0.05) { s = 0.6; }
                        }
                        let to_entity = p - s_data.pos_scale.xyz;
                        let local_p = toLocalSpace(p, s_data.pos_scale.xyz, s_data.rot);
                        let squashed_p = vec3<f32>(local_p.x, local_p.y / s, local_p.z);
                        let d = (length(squashed_p) - raw_w) * min(1.0, s);
                        
                        let energy = length(s_data.light_fields.xyz);
                        if (d < 16.0 && energy > 0.0) {
                            let wave_phase = u.time * 12.0 - d * 2.5;
                            let amp = cos(wave_phase) * exp(-d * 0.15) * 0.08;
                            let dir = normalize(to_entity);
                            ripple_offset += dir * amp;
                        }
                      }
                    }
                }
            }
            return ripple_offset;
        }

        fn getFieldDensity(fields: vec4<f32>, interaction: vec4<f32>, view_mode: f32) -> f32 {
            var d = 0.0;
            if (view_mode == 1.0) {
                // Temperature View
                d = clamp(abs(interaction.x) / 120.0, 0.0, 1.0) * 0.6;
            } else if (view_mode == 2.0) {
                // Light Field View
                d = fields.w * 0.8;
            } else if (view_mode == 3.0) {
                // Stress View - disable volumetric fog to keep solid surface crisp
                d = 0.0;
            } else if (view_mode == 4.0) {
                // Shear Stress View
                d = clamp(interaction.y, 0.0, 1.0) * 0.6;
            } else {
                // Default Normal View (Water Volume / SPH fluid)
                // Include temperature influence so hot/cold explosions/implosions generate fog density
                d = (interaction.z / 15.0) * 0.3 + interaction.y * 0.15 + clamp(abs(interaction.x) / 120.0, 0.0, 1.0) * 0.55;
            }
            return d;
        }

        fn getMaterialStressLimit(mat_id: f32) -> f32 {
            let props = get_material_properties(mat_id);
            return props.strength;
        }

        fn getFieldColor(p: vec3<f32>, default_color: vec3<f32>) -> vec3<f32> {
            let self_slot = getChunkSlot(vec3<i32>(floor(p / 32.0)) - chunk_lookup.origin.xyz);
            if (self_slot < 0) {
                return default_color;
            }

            let self_voxel = sampleVoxelGrid(p, true);

            let interaction = sampleInteractionGrid(p);
            let comp_stress = interaction.z; // fields.z
            let shear_stress = interaction.y; // fields.y

            let limit = getMaterialStressLimit(self_voxel.y);
            let total_stress = (comp_stress - 1.0) + shear_stress * 3.0;
            let norm_stress = clamp(total_stress / limit, 0.0, 1.0);

            // Heatmap color stops:
            let c0 = vec3<f32>(0.02, 0.10, 0.40); // Deep Blue (0.0)
            let c1 = vec3<f32>(0.00, 0.70, 0.90); // Cyan (0.25)
            let c2 = vec3<f32>(0.05, 0.80, 0.20); // Green (0.5)
            let c3 = vec3<f32>(0.95, 0.70, 0.00); // Yellow/Orange (0.75)
            let c4 = vec3<f32>(1.00, 0.05, 0.10); // Glowing Red (1.0)

            var col = c0;
            if (norm_stress < 0.25) {
                let t_val = norm_stress / 0.25;
                col = mix(c0, c1, t_val);
            } else if (norm_stress < 0.5) {
                let t_val = (norm_stress - 0.25) / 0.25;
                col = mix(c1, c2, t_val);
            } else if (norm_stress < 0.75) {
                let t_val = (norm_stress - 0.5) / 0.25;
                col = mix(c2, c3, t_val);
            } else {
                let t_val = (norm_stress - 0.75) / 0.25;
                col = mix(c3, c4, t_val);
            }

            // Add a subtle grid/contour effect to make stress levels feel structural
            let contour = abs(sin(norm_stress * 3.14159 * 10.0));
            col = mix(col, col * 1.35, (1.0 - contour) * 0.18);

            return col;
        }

        fn getFieldColorWeight(fields: vec4<f32>, interaction: vec4<f32>, view_mode: f32) -> f32 {
            if (view_mode == 1.0) {
                return clamp(abs(interaction.x) / 5.0, 0.0, 1.0);
            } else if (view_mode == 2.0) {
                return clamp(fields.w / 0.5, 0.0, 1.0);
            } else if (view_mode == 3.0) {
                // Disable volumetric stress aura so solid coloring remains sharp and clear
                return 0.0;
            } else if (view_mode == 4.0) {
                return clamp(interaction.y / 0.5, 0.0, 1.0);
            }
            return clamp(abs(interaction.x) / 5.0, 0.0, 1.0);
        }

       fn getInterpolatedColor(p: vec3<f32>) -> vec3<f32> {
           return getInterpolatedFieldsAndColor(p).color;
       }

        fn getVoxelColor(p: vec3<f32>, mat_id: i32) -> vec3<f32> {
            if (mat_id == 1) {
                return vec3<f32>(0.22, 0.44, 0.16); // Lush green
            } else if (mat_id == 2) {
                return vec3<f32>(0.72, 0.38, 0.22); // Terracotta orange
            } else if (mat_id == 3) {
                return vec3<f32>(0.42, 0.42, 0.45); // Stone grey
            } else if (mat_id == 4) {
                return vec3<f32>(0.15, 0.35, 0.75); // Water blue
            } else if (mat_id == 5) {
                return vec3<f32>(0.76, 0.68, 0.48); // Sand beige
            } else if (mat_id == 6) {
                return vec3<f32>(0.92, 0.94, 0.98); // Snow / Ice
            } else if (mat_id == 7) {
                return vec3<f32>(0.08, 0.07, 0.09); // Volcanic Obsidian
            } else if (mat_id == 8) {
                return vec3<f32>(0.05, 0.62, 0.54); // Deep Cave Moss
            } else if (mat_id == 9) {
                return vec3<f32>(0.20, 0.08, 0.30); // Amethyst Purple Crystal
            } else if (mat_id == 10) {
                return vec3<f32>(0.35, 0.25, 0.18); // Clay Brown
            }
            return vec3<f32>(0.4, 0.4, 0.5);
        }



      fn sdMandelbox(p: vec3<f32>, params: vec4<f32>) -> f32 {
          let scale = params.x * 6.0 - 3.0; // Map [0,1] to [-3,3]
          let foldingLimit = params.y * 3.0; // Map [0,1] to [0,3]
          let minRad2 = params.z * 1.5; // Map [0,1] to [0,1.5]
          let fixedRad2 = (params.w + 5.0) / 10.0 * 2.0; // Map gravity [-5,5] back to [0,2]
          
          var z = p;
          var dr = 1.0;
          var trap = 1e10;
          
          for (var i = 0; i < 7; i = i + 1) {
              // Box fold
              z = clamp(z, vec3<f32>(-foldingLimit), vec3<f32>(foldingLimit)) * 2.0 - z;
              
              // Sphere fold
              let r2 = dot(z, z);
              if (r2 < minRad2) {
                  let factor = fixedRad2 / minRad2;
                  z = z * factor;
                  dr = dr * factor;
              } else if (r2 < fixedRad2) {
                  let factor = fixedRad2 / r2;
                  z = z * factor;
                  dr = dr * factor;
              }
              
              // Scale and shift
              z = z * scale + p;
              dr = dr * abs(scale) + 1.0;
              
              trap = min(trap, dot(z.xz, z.xz));
          }
          
          fractal_trap = trap;
          return length(z) / abs(dr);
      }

      fn sdPlane(p: vec3<f32>, n: vec3<f32>, h: f32) -> f32 {
          return dot(p, n) + h;
      }

      fn sdSphere(p: vec3<f32>, s: f32) -> f32 {
          return length(p) - s;
      }

      fn sdBox(p: vec3<f32>, b: vec3<f32>) -> f32 {
          let q = abs(p) - b;
          return length(max(q, vec3<f32>(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0);
      }

      fn sdCylinder(p: vec3<f32>, r: f32, h: f32) -> f32 {
          let d = abs(vec2<f32>(length(p.xz), p.y)) - vec2<f32>(r, h);
          return min(max(d.x, d.y), 0.0) + length(max(d, vec2<f32>(0.0)));
      }

      fn sdCapsule(p: vec3<f32>, r: f32, h: f32) -> f32 {
          let py = clamp(p.y, -h, h);
          return length(p - vec3<f32>(0.0, py, 0.0)) - r;
      }

      fn sdTorus(p: vec3<f32>, t: vec2<f32>) -> f32 {
          let q = vec2<f32>(length(p.xz) - t.x, p.y);
          return length(q) - t.y;
      }

      fn sdOctahedron(p: vec3<f32>, s: f32) -> f32 {
          let q = abs(p);
          return (q.x + q.y + q.z - s) * 0.57735027;
      }

      fn q_inv(q: vec4<f32>) -> vec4<f32> {
          return vec4<f32>(-q.xyz, q.w);
      }

      fn rotateVector(v: vec3<f32>, q: vec4<f32>) -> vec3<f32> {
          let t = 2.0 * cross(q.xyz, v);
          return v + q.w * t + cross(q.xyz, t);
      }

      fn toLocalSpace(p: vec3<f32>, pos: vec3<f32>, rot: vec4<f32>) -> vec3<f32> {
          return rotateVector(p - pos, q_inv(rot));
      }

      fn getShapeDistance(p: vec3<f32>, shape_type: u32, size: vec3<f32>) -> f32 {
          var d = 10000.0;
          if (shape_type == 1u) {
              d = sdSphere(p, size.x);
          } else if (shape_type == 2u) {
              d = sdBox(p, size);
          } else if (shape_type == 3u) {
              d = sdCylinder(p, size.x, size.y);
          } else if (shape_type == 4u) {
              d = sdCapsule(p, size.x, size.y);
          } else if (shape_type == 5u) {
              d = sdTorus(p, size.xy);
          } else if (shape_type == 6u) {
              d = sdOctahedron(p, size.x);
          }
          return d;
      }

      fn evaluateCsgPrimitive(p: vec3<f32>, shape_type: u32, pos: vec3<f32>, scale: f32, rot: vec4<f32>, params: vec4<f32>) -> f32 {
          let local_p = toLocalSpace(p, pos, rot);
          return getShapeDistance(local_p, shape_type, params.xyz * scale);
      }

       fn evaluateNoise(p: vec3<f32>) -> f32 {
           return textureSampleLevel(noise_texture, noise_sampler, p * 0.1, 0.0).r - 0.5;
       }

      fn evaluateFbm(p: vec3<f32>) -> f32 {
          var v = 0.0;
          var a = 0.5;
          var shift = vec3<f32>(100.0);
          var cur_p = p;
          for (var i = 0; i < 3; i = i + 1) {
              v += a * evaluateNoise(cur_p) * 6.666;
              cur_p = cur_p * 2.0 + shift;
              a *= 0.5;
          }
          return v;
      }

      fn getDitherThreshold(pos: vec2<f32>) -> f32 {
          let x = i32(pos.x) % 4;
          let y = i32(pos.y) % 4;
          let index = x + y * 4;
          var threshold = array<f32, 16>(
              0.0625, 0.5625, 0.1875, 0.6875,
              0.8125, 0.3125, 0.9375, 0.4375,
              0.2500, 0.7500, 0.3750, 0.8750,
              0.0000, 0.5000, 0.1250, 0.6250
          );
          return threshold[index];
      }

      fn evaluateCsgTree(local_p: vec3<f32>, root_idx: i32) -> f32 {
          let base_idx = root_idx - (root_idx % 2);
          if (base_idx == root_idx) {
              let node = csg_nodes[root_idx];
              return evaluateCsgPrimitive(local_p, u32(round(node.info.x)), node.pos.xyz, node.pos.w, node.rot, node.params);
          }
          
          let base_node = csg_nodes[base_idx];
          var d = evaluateCsgPrimitive(local_p, u32(round(base_node.info.x)), base_node.pos.xyz, base_node.pos.w, base_node.rot, base_node.params);
          for (var idx = base_idx + 2; idx <= root_idx; idx = idx + 2) {
              let op_node = csg_nodes[idx];
              let right_child = i32(round(op_node.info.w));
              let right_node = csg_nodes[right_child];
              var d_right = 10000.0;
              let diff = local_p - right_node.pos.xyz;
              if (dot(diff, diff) < 9.0) {
                  d_right = evaluateCsgPrimitive(local_p, u32(round(right_node.info.x)), right_node.pos.xyz, right_node.pos.w, right_node.rot, right_node.params);
              }
              let op = u32(round(op_node.info.y));
              if (op == 0u) {
                  d = min(d, d_right);
              } else if (op == 1u) {
                  let d_right_noisy = d_right + evaluateNoise(local_p);
                  d = max(d, -d_right_noisy);
              } else {
                  d = max(d, d_right);
              }
          }
          return d;
      }

        fn getInstanceDist(p: vec3<f32>, s_idx: i32) -> f32 {
            let s_data = instances[s_idx];
            let raw_w = s_data.pos_scale.w;
            let local_p = toLocalSpace(p, s_data.pos_scale.xyz, s_data.rot);
           let inst_type = i32(round(s_data.shape_info.y));
           if (inst_type == 0) {
               let csg_root_idx = i32(round(s_data.shape_info.z));
               if (csg_root_idx >= 0) {
                   return evaluateCsgTree(local_p, csg_root_idx);
               } else {
                    let shape_type = u32(round(s_data.shape_info.x));
                    let size = select(vec3<f32>(raw_w), vec3<f32>(raw_w, 0.25 * raw_w, raw_w), shape_type == 5u);
                    return getShapeDistance(local_p, shape_type, size);
               }
           }
           return 10000.0;
       }

       fn get_wireframe_edge(lp: vec3<f32>, shape_type: u32, size: f32, thickness: f32) -> f32 {
          if (shape_type == 1u) {
              let rx = smoothstep(thickness, thickness - 0.01, abs(lp.x));
              let ry = smoothstep(thickness, thickness - 0.01, abs(lp.y));
              let rz = smoothstep(thickness, thickness - 0.01, abs(lp.z));
              return max(rx, max(ry, rz));
          } else if (shape_type == 2u) {
              let q = abs(lp) - vec3<f32>(size);
              let second_max = max(min(q.x, q.y), max(min(q.x, q.z), min(q.y, q.z)));
              return smoothstep(-thickness, -thickness + 0.01, second_max);
          } else if (shape_type == 4u) { // Capsule
              let r = size;
              let h = size;
              let angle = atan2(lp.z, lp.x);
              let long_line = smoothstep(0.95, 0.98, abs(sin(angle * 4.0)));
              let ring_y = smoothstep(thickness, thickness - 0.01, abs(lp.y));
              let ring_cap = smoothstep(thickness, thickness - 0.01, abs(abs(lp.y) - h));
              return max(long_line, max(ring_y, ring_cap));
          } else if (shape_type == 3u) { // Cylinder
              let r = size;
              let h = size;
              let rad = length(lp.xz);
              let rim = smoothstep(-thickness, -thickness + 0.01, min(rad - r, abs(lp.y) - h));
              let angle = atan2(lp.z, lp.x);
              let vertical_line = smoothstep(0.95, 0.98, abs(sin(angle * 6.0))) * step(abs(lp.y), h);
              return max(rim, vertical_line);
          } else if (shape_type == 5u) { // Torus
              let R = size;
              let major_angle = atan2(lp.z, lp.x);
              let ring_major = smoothstep(0.95, 0.98, abs(sin(major_angle * 8.0)));
              let local_angle = atan2(lp.y, length(lp.xz) - R);
              let ring_tube = smoothstep(0.95, 0.98, abs(sin(local_angle * 6.0)));
              return max(ring_major, ring_tube);
          } else {
              let ex = smoothstep(thickness, thickness - 0.01, abs(lp.x));
              let ey = smoothstep(thickness, thickness - 0.01, abs(lp.y));
              let ez = smoothstep(thickness, thickness - 0.01, abs(lp.z));
              return max(ex, max(ey, ez));
          }
       }

          fn worldSDF(p: vec3<f32>, rd: vec3<f32>, dither_threshold: f32, eval_metaballs: bool) -> vec4<f32> {
              let p_local = p - u.grid_origin.xyz;
              let gx = i32(floor(p_local.x / u.cell_size));
              let gy = i32(floor(p_local.y / u.cell_size));
              let gz = i32(floor(p_local.z / u.cell_size));

              let voxel_pt = sampleVoxelGridPoint(p, true);
              var voxel_dist = voxel_pt.x;
              if (voxel_dist < 2.0) {
                  let voxel_tri = sampleVoxelGrid(p, true);
                  voxel_dist = voxel_tri.x;
              }

              var d = vec2<f32>(voxel_dist, -1.0);
              var metaball_d = 10000.0;
              var has_metaballs = false;
              var metaball_idx = -1.0;

              let inside_grid = (gx >= 0 && gx < i32(u.grid_dims.x) && gy >= 0 && gy < i32(u.grid_dims.y) && gz >= 0 && gz < i32(u.grid_dims.z));
              if (inside_grid) {
                  let idx = gx + i32(u.grid_dims.x) * (gy + i32(u.grid_dims.y) * gz);
                  let cell = grid[idx];
                  let count = min(i32(round(cell.header.x)), {{MAX_IDS}});

                  // 1. Shockwave wave deformations
                  var wave_deformation = 0.0;
                  for(var i = 0; i < count; i = i + 1) {
                      let s_idx = i32(round(cell.ids[i]));
                      if (s_idx >= 0 && s_idx < 1024) {
                        let s_data = instances[s_idx];
                        let raw_w = s_data.pos_scale.w;
                        if (raw_w != 0.0 && s_data.light_fields.w != 0.0) {
                          let dist_to_center = length(p - s_data.pos_scale.xyz);
                          let d_front = dist_to_center - raw_w;
                          if (dist_to_center < 16.0 && abs(d_front) < 4.0) {
                            let wave_phase = d_front * 3.0;
                            let envelope = exp(-pow(d_front / 2.0, 2.0));
                            let amp = sin(wave_phase) * envelope * 0.35 * (s_data.light_fields.w / 30.0);
                            wave_deformation += amp;
                          }
                        }
                      }
                  }
                  d.x += wave_deformation;

                  // 2. Metaballs & CSG objects
                  for(var i = 0; i < count; i = i + 1) {
                      let s_idx = i32(round(cell.ids[i]));
                      if (s_idx >= 0 && s_idx < 1024) {
                        let s_data = instances[s_idx];
                        let raw_w = s_data.pos_scale.w;
                        if (raw_w != 0.0) {
                          var local_dist = 10000.0;
                          let local_p = toLocalSpace(p, s_data.pos_scale.xyz, s_data.rot);
                          let inst_type = i32(round(s_data.shape_info.y));
                          let csg_root_idx = i32(round(s_data.shape_info.z));
                          if (csg_root_idx == -3) {
                              continue;
                          }
                          let shape_type = u32(round(s_data.shape_info.x));

                          if (inst_type == 1) { // Black hole
                              let singularity_r = raw_w;
                              let accretion_r = max(s_data.light_fields.x, 0.1);
                              let accretion_h = max(s_data.light_fields.y, 0.01);
                              let k1 = max(s_data.light_fields.z, 0.01);
                              let k2 = max(s_data.light_fields.w, 0.01);
                              
                              let dist_to_center = length(p - s_data.pos_scale.xyz);
                              let d_singularity = dist_to_center - singularity_r;
                              
                              let local_to_center = toLocalSpace(p, s_data.pos_scale.xyz, s_data.rot);
                              let d_accretion = sdTorus(local_to_center, vec2<f32>(accretion_r, accretion_h));
                              
                               let orig_dx = d.x;
                               let blended_terrain = smin(d.x, d_accretion, k1);
                               d.x = smax(blended_terrain, -d_singularity, k2);
                               
                               if (d_accretion < orig_dx) {
                                   d = vec2<f32>(d.x, f32(s_idx));
                               }
                               if (d_singularity < d.x) {
                                   d = vec2<f32>(d_singularity, f32(s_idx));
                               }
                              continue;
                          }
                          if (inst_type == 2) { // GUI Panel
                               let width = s_data.light_fields.x;
                               let height = s_data.light_fields.y;
                               let slider1_val = s_data.light_fields.z;
                               let slider2_val = s_data.light_fields.w;

                               let board_half = vec3<f32>(width * 0.5, height * 0.5, 0.015);
                               let board_d = sdBox(local_p, board_half) - 0.005;

                               let slider1_track_pos = vec3<f32>(-0.5, 0.2, 0.0);
                               let slider1_track_d = sdBox(local_p - slider1_track_pos, vec3<f32>(0.5, 0.02, 0.015));

                               let knob1_x = -0.5 + (slider1_val - 0.5) * 1.0;
                               let knob1_pos = vec3<f32>(knob1_x, 0.2, 0.02);
                               let knob1_d = sdSphere(local_p - knob1_pos, 0.045);

                               let slider2_track_pos = vec3<f32>(-0.5, -0.2, 0.0);
                               let slider2_track_d = sdBox(local_p - slider2_track_pos, vec3<f32>(0.5, 0.02, 0.015));

                               let knob2_x = -0.5 + (slider2_val - 0.5) * 1.0;
                               let knob2_pos = vec3<f32>(knob2_x, -0.2, 0.02);
                               let knob2_d = sdSphere(local_p - knob2_pos, 0.045);

                               var final_d = max(board_d, -slider1_track_d);
                               final_d = max(final_d, -slider2_track_d);
                               final_d = min(final_d, knob1_d);
                               final_d = min(final_d, knob2_d);

                               if (final_d < d.x) {
                                   d = vec2<f32>(final_d, f32(s_idx));
                               }
                               continue;
                          }
                          if (inst_type == 0) { // CSG tree / shape primitive
                              if (csg_root_idx >= 0) {
                                  local_dist = evaluateCsgTree(local_p, csg_root_idx);
                              } else {
                                  if (shape_type == 1u && s_data.light_fields.x != 0.0) {
                                      continue;
                                  }
                                  let size = select(vec3<f32>(raw_w), vec3<f32>(raw_w, 0.25 * raw_w, raw_w), shape_type == 5u);
                                  local_dist = getShapeDistance(local_p, shape_type, size);
                              }
                              if (local_dist < d.x) { d = vec2<f32>(local_dist, f32(s_idx)); }
                          }
                        }
                      }
                  }

                  var t_exit = 100.0;
                  if (u.shadow_ao_quality.z <= 0.5) {
                      let cell_min = vec3<f32>(f32(gx), f32(gy), f32(gz)) * u.cell_size;
                      let cell_max = cell_min + vec3<f32>(u.cell_size);
                      if (rd.x > 0.0001) { t_exit = min(t_exit, (cell_max.x - p_local.x) / rd.x); }
                      else if (rd.x < -0.0001) { t_exit = min(t_exit, (cell_min.x - p_local.x) / rd.x); }
                      if (rd.y > 0.0001) { t_exit = min(t_exit, (cell_max.y - p_local.y) / rd.y); }
                      else if (rd.y < -0.0001) { t_exit = min(t_exit, (cell_min.y - p_local.y) / rd.y); }
                      if (rd.z > 0.0001) { t_exit = min(t_exit, (cell_max.z - p_local.z) / rd.z); }
                      else if (rd.z < -0.0001) { t_exit = min(t_exit, (cell_min.z - p_local.z) / rd.z); }
                  }

                  var h_step = min(d.x, max(t_exit + 0.01, 0.05));
                  if (u.shadow_ao_quality.z > 0.5) {
                      h_step = d.x;
                  }
                  return vec4<f32>(h_step, d.x, d.y, 10000.0);
              } else {
                  return vec4<f32>(d.x, d.x, d.y, 10000.0);
              }
          }

        fn getShadow(ro: vec3<f32>, rd: vec3<f32>, mint: f32, maxt: f32, k: f32, dither_threshold: f32, max_steps: i32) -> f32 {
            var res = 1.0;
            var t = mint;
            var last_h = 1e10;
            var dt = 0.0;
            for (var i = 0; i < max_steps; i = i + 1) {
                let sdf_val = worldSDF(ro + rd * t, rd, dither_threshold, false);
                let h = sdf_val.y;
                if (h < 0.001) {
                    return 0.0;
                }
                if (i > 0) {
                    let y = (h * h - last_h * last_h + dt * dt) / (2.0 * dt);
                    let d2 = h * h - y * y;
                    if (d2 >= 0.0) {
                        let d = sqrt(d2);
                        res = min(res, k * d / max(0.0001, t - y));
                    } else {
                        res = min(res, k * h / t);
                    }
                } else {
                    res = min(res, k * h / t);
                }
                last_h = h;
                let min_dt = 0.05 + 0.2 * t;
                dt = clamp(max(h, min_dt), 0.02, 5.0);
                t += dt;
                if (t > maxt) {
                    break;
                }
            }
            return clamp(res, 0.0, 1.0);
        }

        fn getAO(p: vec3<f32>, n: vec3<f32>, dither_threshold: f32) -> f32 {
            var occ = 0.0;
            var sca = 1.0;
            for (var i = 0; i < 5; i = i + 1) {
                let hr = 0.01 + 0.12 * f32(i) / 4.0;
                let aopos = p + n * hr;
                let d = worldSDF(aopos, vec3<f32>(0.0), dither_threshold, false).y;
                occ += -(d - hr) * sca;
                sca *= 0.95;
            }
            return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
        }

        fn getSkyColor(rd: vec3<f32>) -> vec3<f32> {
            let num_suns = u32(round(u.misc_params.x));
            
            // Find max altitude to drive zenith/horizon background colors
            var alt = -1.0;
            for (var i = 0u; i < num_suns; i = i + 1u) {
                let sun_dir = normalize(u.suns[i].dir.xyz);
                if (sun_dir.y > alt) {
                    alt = sun_dir.y;
                }
            }
            
            // Base colors based on sun altitude
            var zenith_color = vec3<f32>(0.05, 0.1, 0.25);
            var horizon_color = vec3<f32>(0.4, 0.65, 0.85);
            var ground_color = vec3<f32>(0.1, 0.08, 0.12);
            
            if (alt > 0.0) {
                let t_day = clamp(alt * 5.0, 0.0, 1.0);
                let zenith_noon = vec3<f32>(0.1, 0.3, 0.75);
                let horizon_noon = vec3<f32>(0.55, 0.75, 0.95);
                let zenith_sunset = vec3<f32>(0.15, 0.02, 0.22);
                let horizon_sunset = vec3<f32>(0.9, 0.15, 0.35);
                zenith_color = mix(zenith_sunset, zenith_noon, t_day);
                horizon_color = mix(horizon_sunset, horizon_noon, t_day);
            } else {
                let t_night = clamp(-alt * 5.0, 0.0, 1.0);
                let zenith_sunset = vec3<f32>(0.15, 0.02, 0.22);
                let horizon_sunset = vec3<f32>(0.9, 0.15, 0.35);
                let zenith_night = vec3<f32>(0.005, 0.005, 0.02);
                let horizon_night = vec3<f32>(0.015, 0.02, 0.05);
                ground_color = vec3<f32>(0.01, 0.008, 0.012);
                zenith_color = mix(zenith_sunset, zenith_night, t_night);
                horizon_color = mix(horizon_sunset, horizon_night, t_night);
            }
            
            let h_factor = max(0.0, rd.y);
            var color = mix(horizon_color, zenith_color, pow(h_factor, 0.6));
            if (rd.y < 0.0) {
                color = mix(horizon_color, ground_color, clamp(-rd.y * 3.0, 0.0, 1.0));
            }
            
            if (rd.y > 0.01) {
                let H = u.cloud_params1.z; // cloud_min_y used as plane height
                let t = H / rd.y;
                let cloud_pos = u.cam_pos.xz + rd.xz * t;
                
                let seed_offset = u.terrain_params2.z;
                let global_frequency = u.terrain_params2.w;

                let sx = cloud_pos.x + seed_offset + u.time * u.cloud_params1.y;
                let sz = cloud_pos.y + seed_offset;
                
                let cloud_val = fbm2d(sx * u.cloud_params2.w * global_frequency, sz * u.cloud_params2.w * global_frequency);
                let cloud_density = clamp((cloud_val - u.cloud_params1.x) * 4.0, 0.0, 1.0);
                let cloud_color = mix(u.cloud_params2.xyz, vec3<f32>(1.0, 0.95, 0.98), rd.y);
                
                // Dim clouds at night
                let cloud_light = mix(0.15, 1.0, clamp(alt * 5.0, 0.0, 1.0));
                color = mix(color, cloud_color * cloud_light, cloud_density * 0.65);
            }
            
            // Draw all active sun disks and glows
            for (var i = 0u; i < num_suns; i = i + 1u) {
                let sun_dir = normalize(u.suns[i].dir.xyz);
                let sun_col = u.suns[i].color.rgb;
                let intensity = u.suns[i].dir.w;
                let size = u.suns[i].color.w;
                let gassiness = u.suns[i].params.x;

                let sun_dot = max(dot(rd, sun_dir), 0.0);
                
                // Exponent for sun disk: size maps from 1.0 (small) to 100.0 (huge).
                // Let's use: exponent = 600.0 / size.
                let disk_exponent = max(1.0, 600.0 / max(0.01, size));
                let sun_disk = pow(sun_dot, disk_exponent);

                // Exponent for sun glow: gassiness maps from 1.0 to 10.0.
                // Let's use: exponent = 12.0 / gassiness.
                let glow_exponent = max(1.0, 12.0 / max(0.01, gassiness));
                let sun_glow = pow(sun_dot, glow_exponent);

                let sun_fade = clamp((sun_dir.y + 0.1) * 5.0, 0.0, 1.0);
                
                // Scale disk and glow by intensity!
                color += sun_disk * sun_col * 3.0 * sun_fade * intensity;
                color += sun_glow * sun_col * mix(vec3<f32>(0.9, 0.35, 0.1), vec3<f32>(1.0), clamp(sun_dir.y * 3.0, 0.0, 1.0)) * 1.2 * sun_fade * intensity;
            }
            
            return color;
        }

       fn computeFogScattering(p: vec3<f32>, res_y: f32, rd: vec3<f32>, dither_threshold: f32, dominant_sun_dir: vec3<f32>, dominant_sun_col: vec3<f32>) -> vec4<f32> {
            let gas_val = sampleGasGrid(p);
            let gas_id = round(gas_val.x);
            let gas_vol = gas_val.y;
            
            var steam = 0.0;
            var smoke = 0.0;
            var acid_fog = 0.0;
            var methane = 0.0;
            
            if (gas_id == 1.0) {
                steam = gas_vol;
            } else if (gas_id == 2.0) {
                smoke = gas_vol;
            } else if (gas_id == 3.0) {
                acid_fog = gas_vol;
            } else if (gas_id == 4.0) {
                methane = gas_vol;
            }
            
            let em_val = sampleEMGrid(p);
            let potential = em_val.w;
            
            let total_gas = steam + smoke + acid_fog + methane + abs(potential);
            if (total_gas < 0.01) {
                return vec4<f32>(0.0);
            }
            
            var base_color = vec3<f32>(0.0);
            var density_factor = 0.0;
            
            if (abs(potential) > 0.05) {
                let step_density = abs(potential) * 0.45 * min(res_y, 4.0);
                let glow_color = mix(vec3<f32>(0.05, 0.4, 0.95), vec3<f32>(0.6, 0.1, 0.95), clamp(potential * 0.5 + 0.5, 0.0, 1.0));
                base_color += glow_color * step_density * 3.0;
                density_factor += step_density * 0.15;
            }
           
           if (steam > 0.01) {
               let step_density = steam * 0.38 * min(res_y, 4.0);
               base_color += vec3<f32>(0.85, 0.90, 0.95) * step_density;
               density_factor += step_density;
           }
           if (smoke > 0.01) {
               let step_density = smoke * 0.85 * min(res_y, 4.0);
               base_color += vec3<f32>(0.38, 0.36, 0.35) * step_density;
               density_factor += step_density;
           }
           if (acid_fog > 0.01) {
               let step_density = acid_fog * 0.45 * min(res_y, 4.0);
               base_color += vec3<f32>(0.25, 0.95, 0.15) * step_density;
               density_factor += step_density;
           }
           if (methane > 0.01) {
               let step_density = methane * 0.22 * min(res_y, 4.0);
               base_color += vec3<f32>(0.92, 0.65, 0.12) * step_density;
               density_factor += step_density;
           }
           
           if (density_factor <= 0.0) {
               return vec4<f32>(0.0);
           }
           
           let norm_color = base_color / density_factor;
           
           let sun_dot = max(dot(rd, dominant_sun_dir), 0.0);
           let phase = 1.0 + 3.0 * pow(sun_dot, 8.0);
           
           let voxel_val = sampleVoxelGrid(p, false);
           let fog_shadow = voxel_val.z;
           
           let ambient_light = getSkyColor(rd) * 0.15;
           let step_lighting = ambient_light + dominant_sun_col * phase * fog_shadow;
           let lit_color = norm_color * step_lighting;
           
           return vec4<f32>(density_factor, lit_color * density_factor);
       }

       @fragment
        fn fs_main(frag_in: VertexOutput) -> @location(0) vec4<f32> {
            let dummy_grav = textureLoad(gravity_texture, vec3<i32>(0), 0);
            let aspect = u.width / u.height + dummy_grav.x * 0.0;
            let uv = frag_in.uv * vec2<f32>(aspect, 1.0);
            let ro = u.cam_pos.xyz;
            var rd = normalize(uv.x * u.cam_right.xyz + uv.y * u.cam_up.xyz + u.cam_dir.xyz * 1.7320508);
            
            // Apply gravitational lensing from black hole
            let max_instances = u32(round(u.suns[0].params.y));
            for(var i = 0u; i < max_instances; i = i + 1u) {
                let s_data = instances[i];
                if (s_data.pos_scale.w != 0.0 && i32(round(s_data.shape_info.y)) == 1) {
                    let to_singularity = s_data.pos_scale.xyz - ro;
                    let projection = dot(to_singularity, rd);
                    if (projection > 0.0) {
                        let closest_p = ro + rd * projection;
                        let to_ray = s_data.pos_scale.xyz - closest_p;
                        let min_dist = length(to_ray);
                        
                        let gravity = max(s_data.light_fields.w * 0.45, 0.05);
                        let deflection = normalize(to_ray) * (gravity / (min_dist * min_dist + 0.08));
                        rd = normalize(rd + deflection);
                    }
                }
            }
            let dither_threshold = getDitherThreshold(frag_in.position.xy);
            let cam_sky_visibility = getShadow(u.cam_pos.xyz, vec3<f32>(0.0, 1.0, 0.0), 0.05, 120.0, 4.0, dither_threshold, SHADOW_STEPS);
            let num_suns = u32(round(u.misc_params.x));
            var dominant_sun_dir = vec3<f32>(0.0, 1.0, 0.0);
            var dominant_sun_col = vec3<f32>(0.0);
            var max_alt = -1.0;
            for (var s_i = 0u; s_i < num_suns; s_i = s_i + 1u) {
                let s_dir = normalize(u.suns[s_i].dir.xyz);
                if (s_dir.y > max_alt) {
                    max_alt = s_dir.y;
                    dominant_sun_dir = s_dir;
                    dominant_sun_col = u.suns[s_i].color.rgb * u.suns[s_i].dir.w;
                }
            }
           
            var t = 0.0;
            var hitId = -1.0;
            var final_metaball_d = 10000.0;
            var fog_optical_depth = 0.0;
            var fog_color_accum = vec3<f32>(0.0);
            var max_water_sampled = 0.0;
            var max_lava_sampled = 0.0;
            var max_acid_sampled = 0.0;
            var max_oil_sampled = 0.0;
            // Raymarching path
            for(var i = 0; i < MAX_RAY_STEPS; i = i + 1) {
                let p = ro + rd * t;
                let res = worldSDF(p, rd, dither_threshold, true);
                hitId = res.z;
                final_metaball_d = res.w;
                
                let water_val = sampleWaterGrid(p);
                let liq_id = round(water_val.x);
                let liq_vol = water_val.y;
                if (liq_id == 1.0) {
                    max_water_sampled = max(max_water_sampled, liq_vol);
                } else if (liq_id == 2.0) {
                    max_lava_sampled = max(max_lava_sampled, liq_vol);
                } else if (liq_id == 3.0) {
                    max_acid_sampled = max(max_acid_sampled, liq_vol);
                } else if (liq_id == 4.0) {
                    max_oil_sampled = max(max_oil_sampled, liq_vol);
                }

                // Accumulate volumetric gases
                let fog_scatter = computeFogScattering(p, res.y, rd, dither_threshold, dominant_sun_dir, dominant_sun_col);
                fog_optical_depth += fog_scatter.x;
                fog_color_accum += fog_scatter.yzw;

                if (res.y < 0.008) { break; }
                let p_local = p - u.grid_origin.xyz;
                let grid_size = u.grid_dims.xyz * 32.0;
                let inside_grid = all(p_local >= vec3<f32>(0.0)) && all(p_local < grid_size);
                let step_limit = select(800.0, 0.85, inside_grid);
                t += min(step_limit, max(0.012, res.y * 0.95));
                if (t > 800.0) { break; }
            }
            if (t <= 800.0) {
                for (var j = 0; j < 2; j = j + 1) {
                    let p = ro + rd * t;
                    let res = worldSDF(p, rd, dither_threshold, true);
                    hitId = res.z;
                    final_metaball_d = res.w;

                    let water_val = sampleWaterGrid(p);
                    let liq_id = round(water_val.x);
                    let liq_vol = water_val.y;
                    if (liq_id == 1.0) {
                        max_water_sampled = max(max_water_sampled, liq_vol);
                    } else if (liq_id == 2.0) {
                        max_lava_sampled = max(max_lava_sampled, liq_vol);
                    } else if (liq_id == 3.0) {
                        max_acid_sampled = max(max_acid_sampled, liq_vol);
                    } else if (liq_id == 4.0) {
                        max_oil_sampled = max(max_oil_sampled, liq_vol);
                    }

                    // Accumulate volumetric gases
                    let fog_scatter = computeFogScattering(p, res.y, rd, dither_threshold, dominant_sun_dir, dominant_sun_col);
                    fog_optical_depth += fog_scatter.x;
                    fog_color_accum += fog_scatter.yzw;

                    t += res.y * 0.5;
                }
            }
            let dist_fog_density = 0.0022 * t;
            fog_optical_depth += dist_fog_density;
            fog_color_accum += getSkyColor(rd) * dist_fog_density;

            var color = getSkyColor(rd);
            if (t <= 800.0) {
                let p = ro + rd * t;
                var normal = vec3<f32>(0.0, 1.0, 0.0);
                var is_sphere = false;
                var is_exp = false;
                var exp_temp_factor = 0.0;
                var exp_n_col = 0.0;
                if (hitId != -1.0) {
                    let s_idx = i32(hitId);
                    let s_data = instances[s_idx];
                    let raw_w = s_data.pos_scale.w;
                    let shape_type = u32(round(s_data.shape_info.x));
                    let inst_type = i32(round(s_data.shape_info.y));
                    let csg_root_idx = i32(round(s_data.shape_info.z));
                    if (shape_type == 1u && inst_type == 0 && csg_root_idx < 0 && s_data.light_fields.x == 0.0) {
                        is_sphere = true;
                    }
                }

                if (is_sphere) {
                     let s_idx = i32(hitId);
                     let s_data = instances[s_idx];
                     normal = normalize(p - s_data.pos_scale.xyz);
                 } else if (hitId != -1.0) {
                     let s_idx = i32(hitId);
                     let eps = 0.005;
                     let d1 = getInstanceDist(p + vec3<f32>( eps, -eps, -eps), s_idx);
                     let d2 = getInstanceDist(p + vec3<f32>(-eps, -eps,  eps), s_idx);
                     let d3 = getInstanceDist(p + vec3<f32>(-eps,  eps, -eps), s_idx);
                     let d4 = getInstanceDist(p + vec3<f32>( eps,  eps,  eps), s_idx);
                     let grad = vec3<f32>( eps, -eps, -eps) * d1 +
                                vec3<f32>(-eps, -eps,  eps) * d2 +
                                vec3<f32>(-eps,  eps, -eps) * d3 +
                                vec3<f32>( eps,  eps,  eps) * d4;
                     let len = length(grad);
                     if (len > 1e-6) {
                         normal = grad / len;
                     } else {
                         normal = vec3<f32>(0.0, 1.0, 0.0);
                     }
                 } else {
                     let eps = 0.05 + 0.0005 * t;
                     let d1 = worldSDF(p + vec3<f32>( eps, -eps, -eps), rd, dither_threshold, false).y;
                     let d2 = worldSDF(p + vec3<f32>(-eps, -eps,  eps), rd, dither_threshold, false).y;
                     let d3 = worldSDF(p + vec3<f32>(-eps,  eps, -eps), rd, dither_threshold, false).y;
                     let d4 = worldSDF(p + vec3<f32>( eps,  eps,  eps), rd, dither_threshold, false).y;
                     let grad = vec3<f32>( eps, -eps, -eps) * d1 +
                                vec3<f32>(-eps, -eps,  eps) * d2 +
                                vec3<f32>(-eps,  eps, -eps) * d3 +
                                vec3<f32>( eps,  eps,  eps) * d4;
                     let len = length(grad);
                     if (len > 1e-6) {
                         normal = grad / len;
                     } else {
                         normal = vec3<f32>(0.0, 1.0, 0.0);
                     }
                 }

                // Sample voxel and metaball distances for color and shading blending
                let voxel_val = sampleVoxelGrid(p, false);
                let voxel_d = voxel_val.x;
                let fields = getInterpolatedFields(p);
                let is_wet = false;

                let num_suns = u32(round(u.misc_params.x));
                var direct_lighting = vec3<f32>(0.0);
                var specular = 0.0;
                var dominant_alt = -1.0;
                var dominant_light_dir = vec3<f32>(0.0, 1.0, 0.0);
                var max_alt = -1.0;
                var sky_visibility = 1.0;
                var ao = 1.0;

                let dist_to_cam = length(p - u.cam_pos.xyz);
                let blend_factor = smoothstep(32.0, 48.0, dist_to_cam);

                for (var i = 0u; i < num_suns; i = i + 1u) {
                    let sun_dir = normalize(u.suns[i].dir.xyz);
                    let sun_col = u.suns[i].color.rgb;
                    let intensity = u.suns[i].dir.w;
                    let diffuse = max(dot(normal, sun_dir), 0.0);

                    // Track dominant/max altitudes
                    if (sun_dir.y > dominant_alt) {
                        dominant_alt = sun_dir.y;
                        dominant_light_dir = sun_dir;
                    }
                    if (sun_dir.y > max_alt) {
                        max_alt = sun_dir.y;
                    }

                    // Shadow lookup for this light source
                    var shadow = 1.0;
                    if (blend_factor < 1.0) {
                        var rt_shadow = 1.0;
                        if (u.shadow_ao_quality.x > 0.0) {
                            if (diffuse <= 0.0) {
                                rt_shadow = 0.0;
                            } else {
                                let max_steps = select(SHADOW_STEPS, SHADOW_STEPS * 3 / 5, u.shadow_ao_quality.x == 1.0);
                                let shadow_dist = select(120.0, 250.0, t > 200.0);
                                rt_shadow = getShadow(p + normal * 0.02, sun_dir, 0.02, shadow_dist, 16.0, dither_threshold, max_steps);
                            }
                        }
                        shadow = mix(rt_shadow, voxel_val.z, blend_factor);
                    } else {
                        shadow = voxel_val.z;
                    }

                    // Accumulate diffuse lighting scaled by intensity
                    if (sun_dir.y > 0.0) {
                        let t_day = clamp(sun_dir.y * 4.0, 0.0, 1.0);
                        let final_sun_color = mix(vec3<f32>(1.0, 0.4, 0.1), sun_col, t_day);
                        direct_lighting += shadow * diffuse * final_sun_color * intensity;
                    }

                    // Accumulate specular highlights scaled by intensity
                    let view_dir = normalize(u.cam_pos.xyz - p);
                    let half_dir = normalize(sun_dir + view_dir);
                    specular += pow(max(dot(normal, half_dir), 0.0), 16.0) * 0.08 * shadow * intensity;
                }

                // AO and sky visibility are calculated once
                if (blend_factor < 1.0) {
                    var rt_ao = 1.0;
                    var rt_sky_vis = 1.0;
                    if (u.shadow_ao_quality.y > 0.0) {
                        if (hitId == -1.0) {
                            rt_ao = voxel_val.w;
                        } else {
                            rt_ao = getAO(p, normal, dither_threshold);
                        }
                    }
                    if (u.shadow_ao_quality.x > 0.0) {
                        rt_sky_vis = rt_ao;
                    }
                    ao = mix(rt_ao, voxel_val.w, blend_factor);
                    sky_visibility = mix(rt_sky_vis, voxel_val.z, blend_factor);
                } else {
                    sky_visibility = voxel_val.z;
                    ao = voxel_val.w;
                }

                // Dynamic ambient skylight based on maximum sun altitude
                var ambient_sky = vec3<f32>(0.15, 0.25, 0.35);
                var ground_bounce = vec3<f32>(0.06, 0.05, 0.05);
                
                if (max_alt > 0.0) {
                    let t_day = clamp(max_alt * 4.0, 0.0, 1.0);
                    ambient_sky = mix(vec3<f32>(0.15, 0.1, 0.2), ambient_sky, t_day);
                } else {
                    let t_night = clamp(-max_alt * 4.0, 0.0, 1.0);
                    ambient_sky = mix(vec3<f32>(0.15, 0.1, 0.2), vec3<f32>(0.01, 0.015, 0.03), t_night);
                    ground_bounce = mix(ground_bounce, vec3<f32>(0.002, 0.002, 0.004), t_night);
                }

                let ambient = mix(ground_bounce, ambient_sky, normal.y * 0.5 + 0.5) * sky_visibility;

                // Subsurface scattering (SSS) evaluated once along dominant light direction
                var sss = 0.0;
                let view_dir = normalize(u.cam_pos.xyz - p);
                if (!is_wet && dominant_alt > 0.0) {
                    let sss_steps = 4;
                    var sss_thickness = 0.0;
                    let sss_step_size = 0.15;
                    for (var s_i = 1; s_i <= sss_steps; s_i = s_i + 1) {
                        let sample_p = p - normal * (f32(s_i) * sss_step_size);
                        let s_res = worldSDF(sample_p, rd, dither_threshold, false);
                        sss_thickness += max(0.0, -s_res.y);
                    }
                    let sss_dot = pow(max(dot(view_dir, -dominant_light_dir), 0.0), 2.0);
                    sss = exp(-sss_thickness * 2.0) * sss_dot * 0.4;
                }

                var lighting = direct_lighting + ambient + sss * vec3<f32>(0.85, 0.38, 0.22) * clamp(dominant_alt * 5.0, 0.0, 1.0);
                
                // Dynamic diffuse Light Field contribution
                lighting += fields.xyz * 1.6;

                // Determine the base terrain color at p using dynamic biome blending
                let inside_p = p - normal * 0.4;
                let inside_voxel_val = sampleVoxelGrid(inside_p, false);
                var mat_id = i32(round(abs(inside_voxel_val.y)));
                if (mat_id < 3) {
                    let raw_mat = i32(round(abs(voxel_val.y)));
                    if (raw_mat >= 3) {
                        mat_id = raw_mat;
                    } else {
                        let deeper_p = p - normal * 0.8;
                        let deeper_voxel_val = sampleVoxelGrid(deeper_p, false);
                        let deeper_mat = i32(round(abs(deeper_voxel_val.y)));
                        if (deeper_mat >= 3) {
                            mat_id = deeper_mat;
                        }
                    }
                }
                var terr_col = vec3<f32>(0.4, 0.4, 0.5);
                var custom_glow = vec3<f32>(0.0);
                var custom_specular_mult = 1.0;
                
                // === DYNAMIC SHADING INJECTION ===
                
                if (mat_id == 11) {
                    // Custom Material 11: Glowing Neon Cyan
                    terr_col = vec3<f32>(0.02, 0.45, 0.6);
                    custom_glow = vec3<f32>(0.0, 0.9, 1.0) * 1.8;
                } else if (mat_id == 12) {
                    // Custom Material 12: Shiny Gold / Brass
                    terr_col = vec3<f32>(0.85, 0.62, 0.18);
                    custom_specular_mult = 4.0;
                } else if (mat_id == 13) {
                    // Custom Material 13: Pulsating Lava Crimson
                    terr_col = vec3<f32>(0.28, 0.05, 0.05);
                    let pulse = sin(u.time * 2.5) * 0.35 + 0.65;
                    custom_glow = vec3<f32>(1.0, 0.12, 0.0) * pulse * 2.2;
                } else if (mat_id == 14) {
                    // Custom Material 14: Dark Obsidian
                    terr_col = vec3<f32>(0.06, 0.06, 0.09);
                    custom_specular_mult = 2.5;
                } else if (mat_id == 3) {
                    // Custom Material 3: Stone grey
                    terr_col = vec3<f32>(0.42, 0.42, 0.45);
                    terr_col += noise3d(p.x * 0.25, p.y * 0.25, p.z * 0.25) * 0.05;
                } else if (mat_id == 4) {
                    // Custom Material 4: Water blue
                    terr_col = vec3<f32>(0.15, 0.35, 0.75);
                } else if (mat_id == 5) {
                    // Custom Material 5: Sand Beige
                    terr_col = vec3<f32>(0.76, 0.68, 0.48);
                    terr_col += noise3d(p.x * 0.15, p.y * 0.15, p.z * 0.15) * 0.03;
                } else if (mat_id == 6) {
                    // Custom Material 6: Snow / Ice
                    terr_col = vec3<f32>(0.92, 0.94, 0.98);
                    terr_col += noise3d(p.x * 0.4, p.y * 0.4, p.z * 0.4) * 0.02;
                    custom_specular_mult = 2.0;
                } else if (mat_id == 7) {
                    // Custom Material 7: Volcanic Obsidian
                    terr_col = vec3<f32>(0.05, 0.05, 0.07);
                    custom_specular_mult = 3.0;
                } else if (mat_id == 8) {
                    // Custom Material 8: Deep Cave Moss
                    terr_col = vec3<f32>(0.12, 0.38, 0.18);
                    terr_col += noise3d(p.x * 0.2, p.y * 0.2, p.z * 0.2) * 0.04;
                } else if (mat_id == 9) {
                    // Custom Material 9: Amethyst Purple Crystal
                    terr_col = vec3<f32>(0.16, 0.06, 0.24);
                    let pulse = sin(u.time * 2.0) * 0.25 + 0.75;
                    custom_glow = vec3<f32>(0.32, 0.08, 0.40) * pulse * 1.5;
                    custom_specular_mult = 4.0;
                } else if (mat_id == 10) {
                    // Custom Material 10: Clay Brown
                    terr_col = vec3<f32>(0.35, 0.25, 0.18);
                    terr_col += noise3d(p.x * 0.1, p.y * 0.1, p.z * 0.1) * 0.03;
                } else if (mat_id == 1 || mat_id == 2 || hitId == -1.0) {
                    let W = getBiomeWeights(p.x, p.z);
                    
                    // 1. Lush Plains Biome: Blend greens and add dark soil on steep banks/slopes
                    let grass_noise = fbm2d(p.x * 0.15, p.z * 0.15);
                    let grass_base = vec3<f32>(0.16, 0.36, 0.12);
                    let grass_high = vec3<f32>(0.32, 0.48, 0.18);
                    let grass_moss = vec3<f32>(0.22, 0.38, 0.14);
                    var plains_green = mix(grass_base, grass_high, grass_noise);
                    plains_green = mix(plains_green, grass_moss, noise2d(p.x * 0.04, p.z * 0.04));
                    
                    let dirt_col = vec3<f32>(0.30, 0.22, 0.14);
                    let plains_slope = smoothstep(0.70, 0.85, normal.y);
                    let col_plains = mix(dirt_col, plains_green, plains_slope);
                    
                    // 2. Terraced Canyons Biome: Layered sedimentary clay (terracotta, ochre orange, purple silt, sandstone beige)
                    let wave_distortion = fbm2d(p.x * 0.05, p.z * 0.05) * 2.5;
                    let layer_y = p.y + wave_distortion;
                    let layer_freq = 0.18;
                    let band_sin = sin(layer_y * layer_freq);
                    let band_cos = cos(layer_y * 0.09 - 1.2);
                    
                    let clay_red    = vec3<f32>(0.58, 0.22, 0.12);
                    let clay_ochre  = vec3<f32>(0.68, 0.38, 0.18);
                    let clay_purple = vec3<f32>(0.38, 0.28, 0.32);
                    let clay_beige  = vec3<f32>(0.72, 0.62, 0.48);
                    
                    var canyon_rock = mix(clay_red, clay_ochre, band_sin * 0.5 + 0.5);
                    canyon_rock = mix(canyon_rock, clay_purple, clamp(band_cos * 1.5, -1.0, 1.0) * 0.5 + 0.5);
                    canyon_rock = mix(canyon_rock, clay_beige, noise2d(p.x * 0.08, p.z * 0.08) * 0.3);
                    
                    let canyon_dust = vec3<f32>(0.76, 0.58, 0.40);
                    let canyon_slope = smoothstep(0.85, 0.94, normal.y);
                    let col_canyons = mix(canyon_rock, canyon_dust, canyon_slope);
                    
                    // 3. Sharp Ridge Mountains Biome: Granite rock with alpine snow caps
                    let rock_dark  = vec3<f32>(0.18, 0.20, 0.24);
                    let rock_light = vec3<f32>(0.34, 0.36, 0.40);
                    let rock_noise = fbm2d(p.x * 0.08, p.z * 0.08);
                    let mountain_rock = mix(rock_dark, rock_light, rock_noise);
                    
                    let mountain_snow = vec3<f32>(0.92, 0.94, 0.98);
                    let snow_noise = noise2d(p.x * 0.2, p.z * 0.2) * 2.0;
                    let snow_threshold_y = 12.0 + snow_noise;
                    
                    let altitude_factor = clamp((p.y - snow_threshold_y) / 8.0, 0.0, 1.0);
                    let slope_factor = smoothstep(0.40, 0.65, normal.y);
                    let extreme_altitude = clamp((p.y - 22.0) / 10.0, 0.0, 1.0);
                    let snow_accum = clamp(altitude_factor * slope_factor + extreme_altitude * smoothstep(0.20, 0.45, normal.y), 0.0, 1.0);
                    
                    let col_mountains = mix(mountain_rock, mountain_snow, snow_accum);
                    
                    terr_col = W.x * col_plains + W.y * col_canyons + W.z * col_mountains;
                }

                // Solid surface field color visualization override
                let view_mode = round(u.grid_origin.w);
                if (view_mode != 0.0) {
                    terr_col = getFieldColor(p, terr_col);
                }

                var base_col = terr_col;
                var edge = 0.0;



                if (hitId != -1.0) {
                    let s_idx = i32(hitId);
                    let s_data = instances[s_idx];
                    let inst_type = i32(round(s_data.shape_info.y));
                    let lp = toLocalSpace(p, s_data.pos_scale.xyz, s_data.rot);
                    if (inst_type == 2) {
                        let width = s_data.light_fields.x;
                        let height = s_data.light_fields.y;
                        let slider1_val = s_data.light_fields.z;
                        let slider2_val = s_data.light_fields.w;
                        let slider3_val = s_data.color_csg.x;
                        let slider4_val = s_data.color_csg.y;
                        let slider5_val = s_data.color_csg.z;

                        var panel_color = vec3<f32>(0.02, 0.15, 0.35); // base cyber blue
                        
                        let knob1_x = -0.5 + (slider1_val - 0.5) * 1.0;
                        let knob1_pos = vec3<f32>(knob1_x, 0.6, 0.02);
                        let d_knob1 = length(lp - knob1_pos);
                        
                        let knob2_x = -0.5 + (slider2_val - 0.5) * 1.0;
                        let knob2_pos = vec3<f32>(knob2_x, 0.3, 0.02);
                        let d_knob2 = length(lp - knob2_pos);

                        let knob3_x = -0.5 + (slider3_val - 0.5) * 1.0;
                        let knob3_pos = vec3<f32>(knob3_x, 0.0, 0.02);
                        let d_knob3 = length(lp - knob3_pos);

                        let knob4_x = -0.5 + (slider4_val - 0.5) * 1.0;
                        let knob4_pos = vec3<f32>(knob4_x, -0.3, 0.02);
                        let d_knob4 = length(lp - knob4_pos);

                        let knob5_x = -0.5 + (slider5_val - 0.5) * 1.0;
                        let knob5_pos = vec3<f32>(knob5_x, -0.6, 0.02);
                        let d_knob5 = length(lp - knob5_pos);

                        if (d_knob1 < 0.05) {
                            base_col = vec3<f32>(1.0, 0.5, 0.0);
                            edge = 1.0;
                        } else if (d_knob2 < 0.05) {
                            base_col = vec3<f32>(0.0, 1.0, 0.5);
                            edge = 1.0;
                        } else if (d_knob3 < 0.05) {
                            base_col = vec3<f32>(1.0, 0.2, 0.6);
                            edge = 1.0;
                        } else if (d_knob4 < 0.05) {
                            base_col = vec3<f32>(0.0, 0.7, 1.0);
                            edge = 1.0;
                        } else if (d_knob5 < 0.05) {
                            base_col = vec3<f32>(0.9, 0.9, 0.1);
                            edge = 1.0;
                        } else {
                            let slider1_track_pos = vec3<f32>(-0.5, 0.6, 0.0);
                            let d_track1 = sdBox(lp - slider1_track_pos, vec3<f32>(0.5, 0.02, 0.015));
                            let slider2_track_pos = vec3<f32>(-0.5, 0.3, 0.0);
                            let d_track2 = sdBox(lp - slider2_track_pos, vec3<f32>(0.5, 0.02, 0.015));
                            let slider3_track_pos = vec3<f32>(-0.5, 0.0, 0.0);
                            let d_track3 = sdBox(lp - slider3_track_pos, vec3<f32>(0.5, 0.02, 0.015));
                            let slider4_track_pos = vec3<f32>(-0.5, -0.3, 0.0);
                            let d_track4 = sdBox(lp - slider4_track_pos, vec3<f32>(0.5, 0.02, 0.015));
                            let slider5_track_pos = vec3<f32>(-0.5, -0.6, 0.0);
                            let d_track5 = sdBox(lp - slider5_track_pos, vec3<f32>(0.5, 0.02, 0.015));

                            if (d_track1 < 0.005 || d_track2 < 0.005 || d_track3 < 0.005 || d_track4 < 0.005 || d_track5 < 0.005) {
                                base_col = vec3<f32>(0.01, 0.02, 0.05);
                                edge = 0.0;
                            } else {
                                let edge_dist = max(abs(lp.x) - width * 0.5, abs(lp.y) - height * 0.5);
                                if (abs(edge_dist) < 0.03) {
                                    base_col = vec3<f32>(0.0, 0.8, 1.0);
                                    edge = 1.0;
                                } else {
                                    base_col = panel_color;
                                    edge = 0.3;
                                }
                            }
                        }
                    } else if (s_data.light_fields.x != 0.0) {
                        let temp_factor = clamp(abs(s_data.light_fields.x) / 120.0, 0.0, 1.0);
                        let scroll_col = vec3<f32>(0.0);
                        let base_noise = evaluateFbm(lp * 4.0 - scroll_col);
                        let detail_noise = evaluateFbm(lp * 12.0 - scroll_col * 1.5);
                        let n_col = clamp(base_noise * 0.7 + detail_noise * 0.3, 0.0, 1.0);
                        
                        var fire_core = s_data.color_csg.rgb;
                        if (s_data.light_fields.x < 0.0) {
                            // Cold cyan-blue implosion core
                            let implosion_glow = min(fire_core * 1.8 + vec3<f32>(0.0, 0.3, 0.5), vec3<f32>(1.0, 1.0, 1.0));
                            let energy = mix(fire_core, implosion_glow, n_col);
                            let void_ash = vec3<f32>(0.01, 0.02, 0.04);
                            base_col = mix(void_ash, energy, temp_factor * (0.3 + 0.7 * n_col));
                        } else {
                            // Hot thermal fire core
                            let fire_glow = min(fire_core * 1.5 + vec3<f32>(0.2, 0.2, 0.2), vec3<f32>(1.0, 1.0, 1.0));
                            let fire = mix(fire_core, fire_glow, n_col);
                            let ash = vec3<f32>(0.05, 0.05, 0.05);
                            base_col = mix(ash, fire, temp_factor * (0.2 + 0.8 * n_col));
                        }
                        is_exp = true;
                        exp_temp_factor = temp_factor;
                        exp_n_col = n_col;
                    } else {
                        let inst_type = i32(round(s_data.shape_info.y));
                        if (inst_type == 1) {
                            let dist_to_sing = length(p - s_data.pos_scale.xyz);
                            if (dist_to_sing < s_data.pos_scale.w + 0.15) {
                                base_col = vec3<f32>(0.0);
                            } else {
                                base_col = s_data.color_csg.rgb * 4.5;
                                is_exp = true;
                                exp_temp_factor = 1.0;
                                exp_n_col = 0.5;
                            }
                        } else if (inst_type == 7) { // Mandelbox Fractal
                            let trap_val = clamp(sqrt(fractal_trap) * 0.15, 0.0, 1.0);
                            let col1 = vec3<f32>(0.02, 0.08, 0.35); // Deep space blue
                            let col2 = vec3<f32>(0.0, 0.85, 0.95);  // Neon Cyan
                            let col3 = vec3<f32>(1.0, 0.0, 0.5);    // Hot Magenta
                            let col4 = vec3<f32>(1.0, 0.95, 0.4);   // Electric Gold
                            
                            var f_col = col1;
                            if (trap_val < 0.33) {
                                f_col = mix(col1, col2, trap_val / 0.33);
                            } else if (trap_val < 0.66) {
                                f_col = mix(col2, col3, (trap_val - 0.33) / 0.33);
                            } else {
                                f_col = mix(col3, col4, (trap_val - 0.66) / 0.34);
                            }
                            base_col = f_col;
                        } else {
                            base_col = s_data.color_csg.rgb;
                            let csg_root_idx = i32(round(s_data.shape_info.z));
                            if (csg_root_idx < 0) {
                                let shape_type = u32(round(s_data.shape_info.x));
                                edge = get_wireframe_edge(lp, shape_type, s_data.pos_scale.w, 0.08);
                            }
                        }
                    }
                } else {
                    base_col = terr_col;
                }

                // Apply structural fatigue cracks visually (Jagged black crystalline cracks)
                let interaction = sampleInteractionGrid(p - normal * 0.4);
                let fatigue = interaction.w;
                if (fatigue > 0.01) {
                    // Crystalline cell-like fragmentation noise
                    let scale1 = 4.0;
                    let n1 = noise3d(p.x * scale1, p.y * scale1, p.z * scale1) * 2.0 - 1.0;
                    
                    let scale2 = 12.0;
                    let n2 = noise3d(p.x * scale2, p.y * scale2, p.z * scale2) * 2.0 - 1.0;
                    
                    // Combine frequencies and take absolute value for sharp cusps/ridges
                    let combined = n1 * 0.7 + n2 * 0.3;
                    let sharp_ridges = 1.0 - abs(combined);
                    
                    // High-contrast threshold to form thin, jagged fissures
                    let crack_pattern = smoothstep(0.85, 0.95, sharp_ridges);
                    let crack_intensity = crack_pattern * fatigue;
                    
                    // Darken the crack fissures to black
                    base_col = mix(base_col, vec3<f32>(0.0, 0.0, 0.0), crack_intensity);
                }

                color = base_col * lighting * ao + vec3<f32>(specular * custom_specular_mult);
                color += custom_glow;

               if (is_exp) {
                   let glow = mix(vec3<f32>(1.0, 0.15, 0.0), vec3<f32>(1.0, 0.9, 0.25), exp_n_col);
                   color = mix(color, base_col + glow * 2.0, exp_temp_factor * (0.3 + 0.7 * exp_n_col));
               }
               
               if (edge > 0.0) {
                   let glow_col = base_col * 2.5 + vec3<f32>(0.25);
                   color = mix(color, glow_col, edge);
               }
            }

            // 3. Volumetric Raymarched Cloud Layer
            let cloud_min_y = 60.0;
            let cloud_max_y = 90.0;
            
            var t_entry = 0.0;
            var t_exit = 0.0;
            
            if (abs(rd.y) > 0.0001) {
                let t1 = (cloud_min_y - ro.y) / rd.y;
                let t2 = (cloud_max_y - ro.y) / rd.y;
                t_entry = max(min(t1, t2), 0.0);
                t_exit = min(max(t1, t2), t);
            } else {
                if (ro.y >= cloud_min_y && ro.y <= cloud_max_y) {
                    t_entry = 0.0;
                    t_exit = t;
                } else {
                    t_entry = 9999.0;
                    t_exit = -9999.0;
                }
            }
            
            if (t_entry < t_exit) {
                var cloud_color_accum = vec3<f32>(0.0);
                var cloud_transmittance = 1.0;
                
                let steps = 40;
                let step_size = (t_exit - t_entry) / f32(steps);
                
                var curr_t = t_entry + step_size * dither_threshold;
                
                let num_suns = u32(round(u.misc_params.x));
                
                // Track maximum sun altitude for clouds ambient lighting
                var alt = -1.0;
                for (var i = 0u; i < num_suns; i = i + 1u) {
                    let sun_dir = normalize(u.suns[i].dir.xyz);
                    if (sun_dir.y > alt) {
                        alt = sun_dir.y;
                    }
                }
                
                var ambient_col = vec3<f32>(0.15, 0.25, 0.35);
                if (alt > 0.0) {
                    let t_day = clamp(alt * 4.0, 0.0, 1.0);
                    ambient_col = mix(vec3<f32>(0.15, 0.08, 0.22), ambient_col, t_day);
                } else {
                    let t_night = clamp(-alt * 4.0, 0.0, 1.0);
                    ambient_col = mix(vec3<f32>(0.15, 0.08, 0.22), vec3<f32>(0.005, 0.006, 0.015), t_night);
                }
                
                for (var i = 0; i < steps; i = i + 1) {
                    let p = ro + rd * curr_t;
                    
                    let wind_offset = vec3<f32>(u.time * 0.4 * u.cloud_params1.y, 0.0, u.time * 0.1 * u.cloud_params1.y);
                    let sample_p = (p + wind_offset) * (u.cloud_params2.w * 3.75);
                    
                    let noise_val = evaluateFbm(sample_p);
                    
                    let height_fraction = (p.y - cloud_min_y) / (cloud_max_y - cloud_min_y);
                    let height_fade = 4.0 * height_fraction * (1.0 - height_fraction);
                    
                    let density_offset = 0.6 - u.cloud_params1.x;
                    let density_scale = u.cloud_params1.x * 0.4;
                    let density = max(0.0, noise_val + density_offset) * height_fade * density_scale;
                    
                    if (density > 0.0) {
                        var sun_light_accum = vec3<f32>(0.0);
                        
                        // Accumulate lighting and self-shadowing from all active suns
                        for (var s = 0u; s < num_suns; s = s + 1u) {
                            let sun_dir = normalize(u.suns[s].dir.xyz);
                            let sun_col = u.suns[s].color.rgb;
                            let intensity = u.suns[s].dir.w;
                            
                            if (sun_dir.y > 0.0) {
                                let t_day = clamp(sun_dir.y * 4.0, 0.0, 1.0);
                                let final_sun_color = mix(vec3<f32>(1.0, 0.4, 0.1), sun_col, t_day);
                                
                                var shadow_density = 0.0;
                                let shadow_step = 5.0;
                                for (var j = 1; j <= 3; j = j + 1) {
                                    let sp = p + sun_dir * (f32(j) * shadow_step);
                                    let s_noise = evaluateFbm((sp + wind_offset) * (u.cloud_params2.w * 3.75));
                                    let s_fraction = (sp.y - cloud_min_y) / (cloud_max_y - cloud_min_y);
                                    let s_fade = clamp(4.0 * s_fraction * (1.0 - s_fraction), 0.0, 1.0);
                                    shadow_density += max(0.0, s_noise + 0.15) * s_fade;
                                }
                                
                                let light_transmission = exp(-shadow_density * 0.35);
                                sun_light_accum += final_sun_color * (0.2 + 0.8 * light_transmission) * intensity;
                            }
                        }
                        
                        let cloud_base_color = mix(u.cloud_params2.xyz, vec3<f32>(1.0, 0.95, 0.98), rd.y * 0.5 + 0.5);
                        let scattering_color = (ambient_col + sun_light_accum) * cloud_base_color;
                        
                        let alpha = 1.0 - exp(-density * step_size);
                        cloud_color_accum += cloud_transmittance * scattering_color * alpha;
                        cloud_transmittance *= (1.0 - alpha);
                        
                        if (cloud_transmittance < 0.01) {
                            cloud_transmittance = 0.0;
                            break;
                        }
                    }
                    curr_t += step_size;
                }
                color = color * cloud_transmittance + cloud_color_accum;
            }

            let transmittance = exp(-fog_optical_depth);
            if (fog_optical_depth > 0.0001) {
                color = color * transmittance + (fog_color_accum / fog_optical_depth) * (1.0 - transmittance);
            } else {
                color = color * transmittance;
            }
            if (max_lava_sampled > 0.001) {
                let lava_col = mix(vec3<f32>(0.9, 0.12, 0.0), vec3<f32>(1.5, 0.55, 0.0), clamp(max_lava_sampled, 0.0, 1.0));
                color = mix(color, lava_col, clamp(max_lava_sampled * 3.0, 0.0, 0.95));
            }
            if (max_acid_sampled > 0.001) {
                let acid_col = mix(vec3<f32>(0.08, 0.55, 0.02), vec3<f32>(0.35, 0.95, 0.1), clamp(max_acid_sampled, 0.0, 1.0));
                color = mix(color, acid_col, clamp(max_acid_sampled * 2.5, 0.0, 0.88));
            }
            if (max_oil_sampled > 0.001) {
                let oil_col = mix(vec3<f32>(0.03, 0.025, 0.02), vec3<f32>(0.12, 0.10, 0.08), clamp(max_oil_sampled, 0.0, 1.0));
                color = mix(color, oil_col, clamp(max_oil_sampled * 2.8, 0.0, 0.96));
            }
            if (max_water_sampled > 0.001) {
                let water_col = mix(vec3<f32>(0.01, 0.20, 0.50), vec3<f32>(0.05, 0.60, 0.85), clamp(pow(max_water_sampled, 0.4), 0.0, 1.0));
                color = mix(color, water_col, clamp(pow(max_water_sampled, 0.5) * 1.8, 0.0, 0.85));
            }
            let dither_noise = fract(sin(dot(frag_in.uv + vec2<f32>(u.time), vec2<f32>(12.9898, 78.233))) * 43758.5453) - 0.5;
            color += vec3<f32>(dither_noise) * (1.0 / 255.0);

          if (u.bg_color.w > 0.5) {
              let dx = abs(frag_in.uv.x) * u.width * 0.5;
              let dy = abs(frag_in.uv.y) * u.height * 0.5;
              if ((dx < 8.0 && dy < 1.0 && dx > 2.0) || (dy < 8.0 && dx < 1.0 && dy > 2.0)) {
                  color = vec3<f32>(0.0, 1.0, 0.0);
              }
          }
          return vec4<f32>(color, 1.0) + vec4<f32>(f32((textureDimensions(light_texture) +
                                                         textureDimensions(interaction_texture) +
                                                         textureDimensions(water_texture) +
                                                         textureDimensions(gas_texture) +
                                                         textureDimensions(em_texture) +
                                                         textureDimensions(voxel_baked_values_texture)).x) * 0.0f);
      }
    