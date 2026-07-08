const MAX_RAY_STEPS: i32 = {{RAY_STEPS}};
const SHADOW_STEPS: i32 = {{SHADOW_STEPS}};
struct PointInstance {
          pos_scale: vec4<f32>,
          rot: vec4<f32>,
          color_csg: vec4<f32>,
          sph_fields: vec4<f32>,
      }
      struct Cell {
          header: vec4<f32>,
          ids: array<f32, {{MAX_IDS}}>,
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
          instances: array<PointInstance, {{LIMIT}}>
      }
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
      @group(0) @binding(8) var fields_texture: texture_3d<f32>;

      fn positive_mod(n: i32, m: i32) -> i32 {
          let r = n % m;
          if (r < 0) {
              return r + m;
          }
          return r;
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

      fn get_terrain_height(x: f32, z: f32) -> f32 {
          let b_val = noise2d(x * 0.003, z * 0.003);
          let w1 = clamp(1.0 - abs(b_val - 0.2) / 0.35, 0.0, 1.0);
          let w2 = clamp(1.0 - abs(b_val - 0.5) / 0.35, 0.0, 1.0);
          let w3 = clamp(1.0 - abs(b_val - 0.8) / 0.35, 0.0, 1.0);
          let sum = w1 + w2 + w3;
          let sum_safe = select(sum, 0.0001, sum < 0.0001);
          let W1 = w1 / sum_safe;
          let W2 = w2 / sum_safe;
          let W3 = w3 / sum_safe;
          
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
          
          return W1 * h_plains + W2 * h_canyons + W3 * h_mountains;
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

      fn getVoxelAt(gx: i32, gy: i32, gz: i32, only_dist: bool) -> vec4<f32> {
          let qx = gx >> {{LOG_RES}}u;
          let qy = gy >> {{LOG_RES}}u;
          let qz = gz >> {{LOG_RES}}u;
          
          let lx = i32(u32(gx) & {{VOXEL_RES_SUB_1}}u);
          let ly = i32(u32(gy) & {{VOXEL_RES_SUB_1}}u);
          let lz = i32(u32(gz) & {{VOXEL_RES_SUB_1}}u);
          
          let local_q = vec3<i32>(qx, qy, qz) - chunk_lookup.origin.xyz;
          var is_loaded = false;
          var slot = -1;
          
          if (!(any(local_q < vec3<i32>(0)) || any(local_q >= vec3<i32>(32)))) {
              let mx = u32(local_q.x) >> 2u;
              let my = u32(local_q.y) >> 2u;
              let mz = u32(local_q.z) >> 2u;
              let skip_idx = mx + (my << 3u) + (mz << 6u);
              let skip_val = chunk_lookup.skip_grid[skip_idx >> 2u][skip_idx & 3];
              if (skip_val != 0) {
                  let idx = local_q.x + local_q.y * 32 + local_q.z * 1024;
                  slot = i32(chunk_lookup.slots[u32(idx) >> 2u][idx & 3]);
                  if (slot >= 0) {
                      is_loaded = true;
                  }
              }
          }
          
          if (is_loaded) {
              let slot_x = slot % {{SLOTS_PER_DIM}};
              let slot_y = (slot / {{SLOTS_PER_DIM}}) % {{SLOTS_PER_DIM}};
              let slot_z = slot / {{SLOTS_PER_DIM_SQ}};
              
              let atlas_coord = vec3<i32>((slot_x * {{VOXEL_RES}}i) + lx, (slot_y * {{VOXEL_RES}}i) + ly, (slot_z * {{VOXEL_RES}}i) + lz);
              return textureLoad(voxel_texture, atlas_coord, 0);
          } else {
              let px = (f32(gx) + 0.5) * u.cell_size;
              let py = (f32(gy) + 0.5) * u.cell_size;
              let pz = (f32(gz) + 0.5) * u.cell_size;
              let final_h = get_terrain_height(px, pz);
              
              let dist_xz = length(vec2<f32>(px, pz) - u.cam_pos.xz);
              let detail_fade = clamp((dist_xz - 256.0) / 128.0, 0.0, 1.0);
              let detail_h = fbm2d(px * 0.005, pz * 0.005) * 1.5 * detail_fade;
              
              let base_terrain_d = py - final_h;
              let terrain_d = (base_terrain_d - detail_h) * 0.55;
              
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
              
              let light_dir = normalize(vec3<f32>(0.5, 1.0, 0.3));
              let shadow_factor = dot(terrain_normal, light_dir);
              let fallback_shadow = clamp(0.2 + 0.8 * smoothstep(-0.2, 0.2, shadow_factor), 0.2, 1.0);
              let fallback_ao = clamp(0.3 + 0.7 * terrain_normal.y, 0.1, 1.0);
              
              return vec4<f32>(voxel_d, mat_id, fallback_shadow, fallback_ao);
          }
      }

        fn sampleVoxelGrid(p: vec3<f32>, only_dist: bool) -> vec4<f32> {
            let chunk_q = vec3<i32>(floor(p / 32.0)) - chunk_lookup.origin.xyz;
            var chunk_is_loaded = false;
            var slot = -1;
            if (all(chunk_q >= vec3<i32>(0)) && all(chunk_q < vec3<i32>(32))) {
                let mx = u32(chunk_q.x) >> 2u;
                let my = u32(chunk_q.y) >> 2u;
                let mz = u32(chunk_q.z) >> 2u;
                let skip_idx = mx + (my << 3u) + (mz << 6u);
                let skip_val = chunk_lookup.skip_grid[skip_idx >> 2u][skip_idx & 3];
                if (skip_val != 0) {
                    let idx = chunk_q.x + chunk_q.y * 32 + chunk_q.z * 1024;
                    slot = i32(chunk_lookup.slots[u32(idx) >> 2u][idx & 3]);
                    if (slot >= 0) {
                        chunk_is_loaded = true;
                    }
                }
            }
            
            if (!chunk_is_loaded) {
                let final_h = get_terrain_height(p.x, p.z);
                
                let dist_xz = length(p.xz - u.cam_pos.xz);
                let detail_fade = clamp((dist_xz - 256.0) / 128.0, 0.0, 1.0);
                let detail_h = fbm2d(p.x * 0.005, p.z * 0.005) * 4.5 * detail_fade;
                
                let terrain_d = (p.y - (final_h + detail_h)) * 0.55;
                let mat_id = 1.0;
                return vec4<f32>(terrain_d, mat_id, 1.0, 1.0);
            }
            
            let tx = p / {{VOXEL_CELL_SIZE}} - vec3<f32>(0.5);
            let c0 = vec3<i32>(floor(tx));
            let f = fract(tx);
            
            let lx = i32(u32(c0.x) & {{VOXEL_RES_SUB_1}}u);
            let ly = i32(u32(c0.y) & {{VOXEL_RES_SUB_1}}u);
            let lz = i32(u32(c0.z) & {{VOXEL_RES_SUB_1}}u);
            
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
                best_mat = round(tex_val.g);
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

       fn getFieldsAt(gx: i32, gy: i32, gz: i32) -> vec4<f32> {
          let qx = gx >> {{LOG_RES}}u;
          let qy = gy >> {{LOG_RES}}u;
          let qz = gz >> {{LOG_RES}}u;
          
          let lx = i32(u32(gx) & {{VOXEL_RES_SUB_1}}u);
          let ly = i32(u32(gy) & {{VOXEL_RES_SUB_1}}u);
          let lz = i32(u32(gz) & {{VOXEL_RES_SUB_1}}u);
          
          let local_q = vec3<i32>(qx, qy, qz) - chunk_lookup.origin.xyz;
          var is_loaded = false;
          var slot = -1;
          
          if (!(any(local_q < vec3<i32>(0)) || any(local_q >= vec3<i32>(32)))) {
              let mx = u32(local_q.x) >> 2u;
              let my = u32(local_q.y) >> 2u;
              let mz = u32(local_q.z) >> 2u;
              let skip_idx = mx + (my << 3u) + (mz << 6u);
              let skip_val = chunk_lookup.skip_grid[skip_idx >> 2u][skip_idx & 3];
              if (skip_val != 0) {
                  let idx = local_q.x + local_q.y * 32 + local_q.z * 1024;
                  slot = i32(chunk_lookup.slots[u32(idx) >> 2u][idx & 3]);
                  if (slot >= 0) {
                      is_loaded = true;
                  }
              }
          }
          
          if (is_loaded) {
              let slot_x = slot % {{SLOTS_PER_DIM}};
              let slot_y = (slot / {{SLOTS_PER_DIM}}) % {{SLOTS_PER_DIM}};
              let slot_z = slot / {{SLOTS_PER_DIM_SQ}};
              let atlas_coord = vec3<i32>((slot_x * {{VOXEL_RES}}i) + lx, (slot_y * {{VOXEL_RES}}i) + ly, (slot_z * {{VOXEL_RES}}i) + lz);
              return textureLoad(fields_texture, atlas_coord, 0);
          } else {
              return vec4<f32>(0.0);
          }
      }

       fn sampleFieldsGrid(p: vec3<f32>) -> vec4<f32> {
          let tx = p / {{VOXEL_CELL_SIZE}} - vec3<f32>(0.5);
          let c0 = vec3<i32>(floor(tx));
          let f = fract(tx);
          
          let lx = i32(u32(c0.x) & {{VOXEL_RES_SUB_1}}u);
          let ly = i32(u32(c0.y) & {{VOXEL_RES_SUB_1}}u);
          let lz = i32(u32(c0.z) & {{VOXEL_RES_SUB_1}}u);
          
          let qx = c0.x >> {{LOG_RES}}u;
          let qy = c0.y >> {{LOG_RES}}u;
          let qz = c0.z >> {{LOG_RES}}u;
          let local_q = vec3<i32>(qx, qy, qz) - chunk_lookup.origin.xyz;
          var chunk_is_loaded = false;
          var slot = -1;
          if (all(local_q >= vec3<i32>(0)) && all(local_q < vec3<i32>(32))) {
              let mx = u32(local_q.x) >> 2u;
              let my = u32(local_q.y) >> 2u;
              let mz = u32(local_q.z) >> 2u;
              let skip_idx = mx + (my << 3u) + (mz << 6u);
              let skip_val = chunk_lookup.skip_grid[skip_idx >> 2u][skip_idx & 3];
              if (skip_val != 0) {
                  let idx = local_q.x + local_q.y * 32 + local_q.z * 1024;
                  slot = i32(chunk_lookup.slots[u32(idx) >> 2u][idx & 3]);
                  if (slot >= 0) {
                      chunk_is_loaded = true;
                  }
              }
          }
          
          if (!chunk_is_loaded) {
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
              tex_val = textureSampleLevel(fields_texture, voxel_sampler, sample_coords, 0.0);
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

        fn sampleVoxelGridPoint(p: vec3<f32>, only_dist: bool) -> vec2<f32> {
            let chunk_q = vec3<i32>(floor(p / 32.0)) - chunk_lookup.origin.xyz;
            var is_loaded = false;
            var slot = -1;
            if (all(chunk_q >= vec3<i32>(0)) && all(chunk_q < vec3<i32>(32))) {
                let mx = u32(chunk_q.x) >> 2u;
                let my = u32(chunk_q.y) >> 2u;
                let mz = u32(chunk_q.z) >> 2u;
                let skip_idx = mx + (my << 3u) + (mz << 6u);
                let skip_val = chunk_lookup.skip_grid[skip_idx >> 2u][skip_idx & 3];
                if (skip_val != 0) {
                    let idx = chunk_q.x + chunk_q.y * 32 + chunk_q.z * 1024;
                    slot = i32(chunk_lookup.slots[u32(idx) >> 2u][idx & 3]);
                    if (slot >= 0) {
                        is_loaded = true;
                    }
                }
            }
            
            if (is_loaded) {
                let tx = p / {{VOXEL_CELL_SIZE}};
                let c0 = vec3<i32>(floor(tx));
                let val = getVoxelAt(c0.x, c0.y, c0.z, only_dist);
                return vec2<f32>(val.x, val.y);
            } else {
                let final_h = get_terrain_height(p.x, p.z);
                let dist_xz = length(p.xz - u.cam_pos.xz);
                let detail_fade = clamp((dist_xz - 256.0) / 128.0, 0.0, 1.0);
                let detail_h = fbm2d(p.x * 0.005, p.z * 0.005) * 1.5 * detail_fade;
                let terrain_d = (p.y - (final_h + detail_h)) * 0.55;
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

       struct InterpolatedData {
            fields: vec4<f32>,
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
            if (gx >= 0 && gx < i32(u.grid_dims.x) && gy >= 0 && gy < i32(u.grid_dims.y) && gz >= 0 && gz < i32(u.grid_dims.z)) {
                let idx = gx + i32(u.grid_dims.x) * (gy + i32(u.grid_dims.y) * gz);
                let cell = grid[idx];
                let count = min(i32(round(cell.header.x)), 64);
                for(var i = 0; i < count; i = i + 1) {
                    let s_idx = i32(round(cell.ids[i]));
                    if (s_idx >= 0 && s_idx < 1024) {
                      let s_data = u.instances[s_idx];
                      let raw_w = s_data.pos_scale.w;
                      if (raw_w != 0.0) {
                        let csg_root_idx = i32(round(s_data.color_csg.w));
                        var s = 1.0;
                        if (csg_root_idx <= -99) {
                            s = f32(-99 - csg_root_idx) / 100.0;
                            if (s < 0.05) { s = 0.6; }
                        }
                        let local_p = rotateVector(p - s_data.pos_scale.xyz, q_inv(s_data.rot));
                        let squashed_p = vec3<f32>(local_p.x, local_p.y / s, local_p.z);
                        let d = (length(squashed_p) - raw_w) * min(1.0, s);
                        let w_color = 1.0 / (d * d + 0.01);
                        var w_fields = w_color;
                        
                        var instance_fields = s_data.sph_fields;
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
            if (sum_color_w > 0.0) {
                out.color = sum_color / sum_color_w;
            } else {
                out.color = vec3<f32>(0.0);
            }
            out.emissive = sum_emissive;
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
                      let s_data = u.instances[s_idx];
                      let raw_w = s_data.pos_scale.w;
                      if (raw_w != 0.0) {
                        if (s_data.sph_fields.x > 0.0) { continue; } // Ignore explosion colors in default fog/fluid
                        let csg_root_idx = i32(round(s_data.color_csg.w));
                        var s = 1.0;
                        if (csg_root_idx <= -99) {
                            s = f32(-99 - csg_root_idx) / 100.0;
                            if (s < 0.05) { s = 0.6; }
                        }
                        let to_entity = p - s_data.pos_scale.xyz;
                        let local_p = rotateVector(to_entity, q_inv(s_data.rot));
                        let squashed_p = vec3<f32>(local_p.x, local_p.y / s, local_p.z);
                        let d = (length(squashed_p) - raw_w) * min(1.0, s);
                        
                        let energy = length(s_data.sph_fields.xyz);
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

        fn getFieldDensity(fields: vec4<f32>, view_mode: f32) -> f32 {
            var d = 0.0;
            if (view_mode == 1.0) {
                // Temperature View
                d = clamp(abs(fields.x) / 120.0, 0.0, 1.0) * 0.6;
            } else if (view_mode == 2.0) {
                // Age View
                d = clamp(fields.y / 12.0, 0.0, 1.0) * 0.6;
            } else if (view_mode == 3.0) {
                // Humidity View
                d = clamp(fields.z / 100.0, 0.0, 1.0) * 0.6;
            } else if (view_mode == 4.0) {
                // Pressure View
                d = clamp(abs(fields.w) / 30.0, 0.0, 1.0) * 0.6;
            } else {
                // Default Normal View (Water Volume / SPH fluid)
                // Include temperature influence so hot/cold explosions/implosions generate fog density
                d = (fields.z / 100.0) * 0.3 + (fields.w / 30.0) * 0.15 + clamp(abs(fields.x) / 120.0, 0.0, 1.0) * 0.55;
            }
            return d;
        }

        fn getFieldColor(fields: vec4<f32>, view_mode: f32, default_color: vec3<f32>) -> vec3<f32> {
            if (view_mode == 1.0) {
                let norm_t = clamp(abs(fields.x) / 120.0, 0.0, 1.0);
                return mix(vec3<f32>(0.0, 0.1, 0.5), vec3<f32>(1.0, 0.1, 0.0), norm_t);
            } else if (view_mode == 2.0) {
                let norm_age = clamp(fields.y / 12.0, 0.0, 1.0);
                return mix(vec3<f32>(0.1, 0.9, 0.1), vec3<f32>(0.9, 0.1, 0.9), norm_age);
            } else if (view_mode == 3.0) {
                let norm_hum = clamp(fields.z / 100.0, 0.0, 1.0);
                return mix(vec3<f32>(0.4, 0.3, 0.1), vec3<f32>(0.0, 0.9, 0.9), norm_hum);
            } else if (view_mode == 4.0) {
                let norm_pres = clamp((abs(fields.w) - 1.0) / 30.0, 0.0, 1.0);
                return mix(vec3<f32>(0.1, 0.05, 0.3), vec3<f32>(0.2, 0.8, 1.0), norm_pres);
            }
            return default_color;
        }

        fn getFieldColorWeight(fields: vec4<f32>, view_mode: f32) -> f32 {
            if (view_mode == 1.0) {
                return clamp(abs(fields.x) / 5.0, 0.0, 1.0);
            } else if (view_mode == 2.0) {
                return clamp(fields.y / 0.5, 0.0, 1.0);
            } else if (view_mode == 3.0) {
                return clamp(fields.z / 5.0, 0.0, 1.0);
            } else if (view_mode == 4.0) {
                return clamp(abs(fields.w) / 5.0, 0.0, 1.0);
            }
            return clamp(abs(fields.x) / 5.0, 0.0, 1.0);
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
           }
           return vec3<f32>(0.4, 0.4, 0.5);
       }

      fn getMetaballDist(p: vec3<f32>) -> f32 {
          let p_local = p - u.grid_origin.xyz;
          let gx = i32(floor(p_local.x / u.cell_size));
          let gy = i32(floor(p_local.y / u.cell_size));
          let gz = i32(floor(p_local.z / u.cell_size));
          var metaball_d = 10000.0;
          if (gx >= 0 && gx < i32(u.grid_dims.x) && gy >= 0 && gy < i32(u.grid_dims.y) && gz >= 0 && gz < i32(u.grid_dims.z)) {
              let idx = gx + i32(u.grid_dims.x) * (gy + i32(u.grid_dims.y) * gz);
              let cell = grid[idx];
              let count = min(i32(round(cell.header.x)), {{MAX_IDS}});
              for(var i = 0; i < count; i = i + 1) {
                  let s_idx = i32(round(cell.ids[i]));
                  if (s_idx >= 0 && s_idx < 1024) {
                    let s_data = u.instances[s_idx];
                    let raw_w = s_data.pos_scale.w;
                    if (raw_w != 0.0) {
                      let csg_root_idx = i32(round(s_data.color_csg.w));
                      if (csg_root_idx <= -99) {
                          var s = f32(-99 - csg_root_idx) / 100.0;
                          if (s < 0.05) { s = 0.6; }
                          let local_p = rotateVector(p - s_data.pos_scale.xyz, q_inv(s_data.rot));
                          let wave_phase = (local_p.x + local_p.z) * 8.0 - u.time * 12.0;
                          let wave = 0.05 * sin(wave_phase) * exp(-length(local_p) * 0.15);
                          let wavy_p = vec3<f32>(local_p.x, local_p.y + wave, local_p.z);
                          let squashed_p = vec3<f32>(wavy_p.x, wavy_p.y / s, wavy_p.z);
                          let local_dist = (length(squashed_p) - raw_w) * min(1.0, s) * 0.85;
                          metaball_d = smin(metaball_d, local_dist, u.grid_dims.w);
                      }
                    }
                  }
              }
          }
          return metaball_d;
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

      fn evaluateCsgPrimitive(p: vec3<f32>, shape_type: u32, pos: vec3<f32>, scale: f32, rot: vec4<f32>, params: vec4<f32>) -> f32 {
          let local_p = rotateVector(p - pos, q_inv(rot));
          var d = 10000.0;
          if (shape_type == 1u) {
              d = sdSphere(local_p, params.x * scale);
          } else if (shape_type == 2u) {
              d = sdBox(local_p, params.xyz * scale);
          } else if (shape_type == 3u) {
              d = sdCylinder(local_p, params.x * scale, params.y * scale);
          } else if (shape_type == 4u) {
              d = sdCapsule(local_p, params.x * scale, params.y * scale);
          } else if (shape_type == 5u) {
              d = sdTorus(local_p, params.xy * scale);
          } else if (shape_type == 6u) {
              d = sdOctahedron(local_p, params.x * scale);
          }
          return d;
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
           let s_data = u.instances[s_idx];
           let raw_w = s_data.pos_scale.w;
           let local_p = rotateVector(p - s_data.pos_scale.xyz, q_inv(s_data.rot));
           let csg_root_idx = i32(round(s_data.color_csg.w));
           if (csg_root_idx >= 0) {
               return evaluateCsgTree(local_p, csg_root_idx);
           } else {
               if (raw_w > 0.0 && raw_w < 500.0) {
                   return sdSphere(local_p, raw_w);
               } else if (raw_w < 0.0 && raw_w > -1000.0) {
                   let size = -raw_w;
                   return sdBox(local_p, vec3<f32>(size));
               } else if (raw_w <= -1000.0 && raw_w > -2000.0) {
                   let size = -raw_w - 1000.0;
                   return sdCapsule(local_p, size, size);
               } else if (raw_w >= 1000.0 && raw_w < 2000.0) {
                   let size = raw_w - 1000.0;
                   return sdCylinder(local_p, size, size);
               } else if (raw_w >= 2000.0) {
                   let size = raw_w - 2000.0;
                   return sdTorus(local_p, vec2<f32>(size, 0.25 * size));
               } else {
                   let size = -raw_w - 2000.0;
                   return sdOctahedron(local_p, size);
               }
           }
       }

       fn get_wireframe_edge(lp: vec3<f32>, raw_w: f32, thickness: f32) -> f32 {
          if (raw_w > 0.0 && raw_w < 500.0) {
              let rx = smoothstep(thickness, thickness - 0.01, abs(lp.x));
              let ry = smoothstep(thickness, thickness - 0.01, abs(lp.y));
              let rz = smoothstep(thickness, thickness - 0.01, abs(lp.z));
              return max(rx, max(ry, rz));
          } else if (raw_w < 0.0 && raw_w > -1000.0) {
              let size = -raw_w;
              let q = abs(lp) - vec3<f32>(size);
              let second_max = max(min(q.x, q.y), max(min(q.x, q.z), min(q.y, q.z)));
              return smoothstep(-thickness, -thickness + 0.01, second_max);
          } else if (raw_w <= -1000.0 && raw_w > -2000.0) {
              let size = -raw_w - 1000.0;
              let r = size;
              let h = size;
              let angle = atan2(lp.z, lp.x);
              let long_line = smoothstep(0.95, 0.98, abs(sin(angle * 4.0)));
              let ring_y = smoothstep(thickness, thickness - 0.01, abs(lp.y));
              let ring_cap = smoothstep(thickness, thickness - 0.01, abs(abs(lp.y) - h));
              return max(long_line, max(ring_y, ring_cap));
          } else if (raw_w >= 1000.0 && raw_w < 2000.0) {
              let size = raw_w - 1000.0;
              let r = size;
              let h = size;
              let rad = length(lp.xz);
              let rim = smoothstep(-thickness, -thickness + 0.01, min(rad - r, abs(lp.y) - h));
              let angle = atan2(lp.z, lp.x);
              let vertical_line = smoothstep(0.95, 0.98, abs(sin(angle * 6.0))) * step(abs(lp.y), h);
              return max(rim, vertical_line);
          } else if (raw_w >= 2000.0) {
              let size = raw_w - 2000.0;
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
                        let s_data = u.instances[s_idx];
                        let raw_w = s_data.pos_scale.w;
                        if (raw_w != 0.0 && s_data.sph_fields.w != 0.0) {
                          let dist_to_center = length(p - s_data.pos_scale.xyz);
                          let d_front = dist_to_center - raw_w;
                          if (dist_to_center < 16.0 && abs(d_front) < 4.0) {
                            let wave_phase = d_front * 3.0;
                            let envelope = exp(-pow(d_front / 2.0, 2.0));
                            let amp = sin(wave_phase) * envelope * 0.35 * (s_data.sph_fields.w / 30.0);
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
                        let s_data = u.instances[s_idx];
                        let raw_w = s_data.pos_scale.w;
                        if (raw_w != 0.0) {
                          var local_dist = 10000.0;
                          let local_p = rotateVector(p - s_data.pos_scale.xyz, q_inv(s_data.rot));
                          let csg_root_idx = i32(round(s_data.color_csg.w));
                          if (csg_root_idx == -5) {
                               let width = s_data.sph_fields.x;
                               let height = s_data.sph_fields.y;
                               let slider1_val = s_data.sph_fields.z;
                               let slider2_val = s_data.sph_fields.w;

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

                               local_dist = final_d;

                               if (local_dist < metaball_d) {
                                   metaball_d = local_dist;
                                   has_metaballs = true;
                                   metaball_idx = f32(s_idx);
                               }
                               continue;
                          }
                          if (csg_root_idx <= -99) {
                              if (!eval_metaballs) { continue; }
                              var s = f32(-99 - csg_root_idx) / 100.0;
                              if (s < 0.05) { s = 0.6; }
                              let wave_phase = (local_p.x + local_p.z) * 8.0 - u.time * 12.0;
                              let wave = 0.05 * sin(wave_phase) * exp(-length(local_p) * 0.15);
                              let wavy_p = vec3<f32>(local_p.x, local_p.y + wave, local_p.z);
                              let squashed_p = vec3<f32>(wavy_p.x, wavy_p.y / s, wavy_p.z);
                              local_dist = (length(squashed_p) - raw_w) * min(1.0, s) * 0.85;
                              metaball_d = smin(metaball_d, local_dist, u.grid_dims.w);
                              has_metaballs = true;
                              metaball_idx = f32(s_idx);
                          } else {
                              if (csg_root_idx >= 0) {
                                  local_dist = evaluateCsgTree(local_p, csg_root_idx);
                              } else {
                                  if (raw_w > 0.0 && raw_w < 500.0) {
                                    if (s_data.sph_fields.x != 0.0) {
                                        continue;
                                    }
                                    local_dist = sdSphere(local_p, raw_w);
                                  } else if (raw_w < 0.0 && raw_w > -1000.0) {
                                    let size = -raw_w;
                                    local_dist = sdBox(local_p, vec3<f32>(size));
                                  } else if (raw_w <= -1000.0 && raw_w > -2000.0) {
                                    let size = -raw_w - 1000.0;
                                    local_dist = sdCapsule(local_p, size, size);
                                  } else if (raw_w >= 1000.0 && raw_w < 2000.0) {
                                    let size = raw_w - 1000.0;
                                    local_dist = sdCylinder(local_p, size, size);
                                  } else if (raw_w >= 2000.0) {
                                    let size = raw_w - 2000.0;
                                    local_dist = sdTorus(local_p, vec2<f32>(size, 0.25 * size));
                                  } else {
                                    let size = -raw_w - 2000.0;
                                    local_dist = sdOctahedron(local_p, size);
                                  }
                              }
                              if (local_dist < d.x) { d = vec2<f32>(local_dist, f32(s_idx)); }
                          }
                        }
                      }
                  }

                  if (has_metaballs && eval_metaballs) {
                      let blended_d = smin(d.x, metaball_d, u.grid_dims.w);
                      var idx = d.y;
                      if (metaball_d < d.x) {
                          idx = metaball_idx;
                      }
                      d = vec2<f32>(blended_d, idx);
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
                  return vec4<f32>(h_step, d.x, d.y, metaball_d);
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
            let zenith_color = vec3<f32>(0.15, 0.02, 0.22);
            let horizon_color = vec3<f32>(0.9, 0.1, 0.35);
            let h_factor = max(0.0, rd.y);
            var color = mix(horizon_color, zenith_color, pow(h_factor, 0.6));
            if (rd.y < 0.0) {
                let ground_color = vec3<f32>(0.1, 0.04, 0.12);
                color = mix(horizon_color, ground_color, clamp(-rd.y * 3.0, 0.0, 1.0));
            }
            
            if (rd.y > 0.01) {
                let H = 150.0;
                let t = H / rd.y;
                let cloud_pos = u.cam_pos.xz + rd.xz * t;
                
                let plains_scale = u.terrain_params1.x;
                let plains_offset = u.terrain_params1.y;
                let canyons_scale = u.terrain_params1.z;
                let canyons_offset = u.terrain_params1.w;
                let mountains_scale = u.terrain_params2.x;
                let mountains_offset = u.terrain_params2.y;
                let seed_offset = u.terrain_params2.z;
                let global_frequency = u.terrain_params2.w;
                let lacunarity = u.terrain_params3.x;
                let gain = u.terrain_params3.y;

                let sx = cloud_pos.x + seed_offset + u.time * 2.0;
                let sz = cloud_pos.y + seed_offset;
                
                let cloud_val = fbm2d(sx * 0.004 * global_frequency, sz * 0.004 * global_frequency);
                let cloud_density = clamp((cloud_val - 0.45) * 4.0, 0.0, 1.0);
                let cloud_color = mix(vec3<f32>(0.9, 0.4, 0.45), vec3<f32>(1.0, 0.95, 0.98), rd.y);
                color = mix(color, cloud_color, cloud_density * 0.65);
            }
            let light_dir = normalize(vec3<f32>(0.5, 1.0, 0.3));
            let sun_dot = max(dot(rd, light_dir), 0.0);
            let sun_disk = pow(sun_dot, 600.0);
            let sun_glow = pow(sun_dot, 12.0);
            color += sun_disk * vec3<f32>(0.15, 0.55, 1.5) * 3.0;
            color += sun_glow * vec3<f32>(0.6, 0.05, 1.0) * 1.2;
            return color;
        }

       @fragment
        fn fs_main(frag_in: VertexOutput) -> @location(0) vec4<f32> {
            let dummy_fields = textureSampleLevel(fields_texture, voxel_sampler, vec3<f32>(0.0), 0.0);
            if (dummy_fields.w > 9999.0) { return vec4<f32>(dummy_fields.xyz, 1.0); }
            let aspect = u.width / u.height;
            let uv = frag_in.uv * vec2<f32>(aspect, 1.0);
            let ro = u.cam_pos.xyz;
            let rd = normalize(uv.x * u.cam_right.xyz + uv.y * u.cam_up.xyz + u.cam_dir.xyz * 1.7320508);
            let dither_threshold = getDitherThreshold(frag_in.position.xy);
            let cam_sky_visibility = getShadow(u.cam_pos.xyz, vec3<f32>(0.0, 1.0, 0.0), 0.05, 120.0, 4.0, dither_threshold, SHADOW_STEPS);
           
           var t = 0.0;
            var hitId = -1.0;
            var final_metaball_d = 10000.0;
            var fog_optical_depth = 0.0;
            var fog_color_accum = vec3<f32>(0.0);
            let is_volumetric = u.shadow_ao_quality.z > 0.5;

            if (!is_volumetric) {
                // Fast non-volumetric raymarching path
                for(var i = 0; i < MAX_RAY_STEPS; i = i + 1) {
                    let p = ro + rd * t;
                    let res = worldSDF(p, rd, dither_threshold, true);
                    hitId = res.z;
                    final_metaball_d = res.w;
                    if (res.y < 0.001) { break; }
                    t += res.y * 0.95;
                    if (t > 800.0) { break; }
                }
                if (t <= 800.0) {
                    for (var j = 0; j < 2; j = j + 1) {
                        let p = ro + rd * t;
                        let res = worldSDF(p, rd, dither_threshold, true);
                        hitId = res.z;
                        final_metaball_d = res.w;
                        t += res.y * 0.5;
                    }
                }
                fog_optical_depth = 0.0035 * t;
            } else {
                // Volumetric raymarching path
                // Jitter starting distance to break up wood-grain banding artifacts
                t = dither_threshold * 0.35;
                for(var i = 0; i < MAX_RAY_STEPS; i = i + 1) {
                    let p = ro + rd * t;
                    let res = worldSDF(p, rd, dither_threshold, true);
                    hitId = res.z;
                    final_metaball_d = res.w;
                    if (res.y < 0.001) { break; }
                    
                    let view_mode = u.grid_origin.w;
                    var sdf_density = 0.0;
                    if (view_mode == 0.0) {
                         if (res.y < 0.0) {
                             sdf_density = clamp(-res.y * 0.5, 0.0, 1.0) * 0.4;
                         } else {
                             sdf_density = clamp(1.0 - res.y / 8.0, 0.0, 1.0) * 0.08;
                         }
                    }
                    
                    let interp_data = getInterpolatedFieldsAndColor(p);
                    let fields = interp_data.fields;
                    let density = 0.0035 + getFieldDensity(fields, view_mode) + sdf_density;
                    
                    let base_sky = getSkyColor(rd);
                    var local_fog_col = base_sky;
                    if (sdf_density > 0.0) {
                         let height_factor = clamp((p.y - 5.0) / 15.0, 0.0, 1.0);
                         let terr_col = mix(vec3<f32>(0.18, 0.38, 0.12), vec3<f32>(0.42, 0.42, 0.45), height_factor);
                         let glow_factor = clamp(-res.y / 4.0, 0.0, 1.0);
                         let sdf_col = mix(terr_col * 0.6, vec3<f32>(0.1, 0.3, 0.6), glow_factor);
                         local_fog_col = mix(local_fog_col, sdf_col, sdf_density / (density + 0.0001));
                    }
                    
                    let color_weight = getFieldColorWeight(fields, view_mode);
                    if (color_weight > 0.0) {
                         let inst_col = getFieldColor(fields, view_mode, interp_data.color);
                         local_fog_col = mix(local_fog_col, inst_col, color_weight);
                    }
                    local_fog_col += interp_data.emissive * 0.12;
                    
                    var dt = res.x;
                    if (res.y < 1.0) {
                        dt = 0.4;
                    } else {
                        dt = min(min(res.x, res.y * 0.5), 1.2);
                        let density_factor = clamp(1.0 - density * 20.0, 0.0, 1.0);
                        let step_scale = 1.0 + clamp((t - 15.0) * 0.08, 0.0, 6.0) * density_factor;
                        dt *= step_scale;
                    }
                    
                    fog_color_accum += local_fog_col * density * dt;
                    fog_optical_depth += density * dt;
                    
                    t += dt;
                    if (t > 800.0) { break; }
                    if (fog_optical_depth > 5.3) { break; }
                }
            }
              var color = getSkyColor(rd);
             if (t <= 800.0 && !is_volumetric) {
                let p = ro + rd * t;
                let light_dir = normalize(vec3<f32>(0.5, 1.0, 0.3));
                var normal = vec3<f32>(0.0, 1.0, 0.0);
                var is_sphere = false;
                var is_metaball = false;
                var is_exp = false;
                var exp_temp_factor = 0.0;
                var exp_n_col = 0.0;
                if (hitId != -1.0) {
                    let s_idx = i32(hitId);
                    let s_data = u.instances[s_idx];
                    let raw_w = s_data.pos_scale.w;
                    if (raw_w > 0.0 && raw_w < 500.0 && s_data.color_csg.w < 0.0 && s_data.color_csg.w > -99.0 && s_data.sph_fields.x == 0.0) {
                        is_sphere = true;
                    }
                    if (s_data.color_csg.w <= -99.0) {
                        is_metaball = true;
                    }
                }

                if (is_sphere) {
                     let s_idx = i32(hitId);
                     let s_data = u.instances[s_idx];
                     normal = normalize(p - s_data.pos_scale.xyz);
                 } else if (hitId != -1.0 && !is_metaball) {
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
                 } else if (is_metaball) {
                    let eps = 0.01;
                    let d1 = getMetaballDist(p + vec3<f32>( eps, -eps, -eps));
                    let d2 = getMetaballDist(p + vec3<f32>(-eps, -eps,  eps));
                    let d3 = getMetaballDist(p + vec3<f32>(-eps,  eps, -eps));
                    let d4 = getMetaballDist(p + vec3<f32>( eps,  eps,  eps));
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
                let metaball_d = final_metaball_d;
                let solid_surface_d = select(0.0, voxel_d, hitId == -1.0);
                let is_wet = is_metaball || (metaball_d < solid_surface_d + u.grid_dims.w);

                if (is_wet) {
                    let fields = getInterpolatedFields(p);
                    let temp_factor = clamp(fields.x / 100.0, 0.0, 1.0);
                    let w_speed = u.time * (2.5 + temp_factor * 5.0);
                    let rx = sin(p.x * 10.0 + p.z * 6.0 + w_speed) * cos(p.z * 12.0 - p.x * 4.0 + w_speed) * (0.12 + temp_factor * 0.15);
                    let ry = sin(p.y * 15.0 - w_speed) * (0.06 + temp_factor * 0.08);
                    let rz = cos(p.x * 8.0 - p.z * 6.0 - w_speed) * sin(p.z * 12.0 + p.x * 4.0 + w_speed) * (0.12 + temp_factor * 0.15);
                    let h = clamp(0.5 + 0.5 * (solid_surface_d - metaball_d) / u.grid_dims.w, 0.0, 1.0);
                    
                    let ripples = getWaterRipples(p);
                    normal = normalize(normal + (vec3<f32>(rx, ry, rz) + ripples) * h);
                }

                let diffuse = max(dot(normal, light_dir), 0.0);

                var shadow = 1.0;
                var sky_visibility = 1.0;
                var ao = 1.0;

                let dist_to_cam = length(p - u.cam_pos.xyz);
                let blend_factor = smoothstep(32.0, 48.0, dist_to_cam);

                if (blend_factor < 1.0) {
                    var rt_shadow = 1.0;
                    var rt_ao = 1.0;
                    var rt_sky_vis = 1.0;
                    if (u.shadow_ao_quality.x > 0.0 && !(is_wet && u.shadow_ao_quality.x < 2.0)) {
                        if (diffuse <= 0.0) {
                            rt_shadow = 0.0;
                        } else {
                            let max_steps = select(SHADOW_STEPS, SHADOW_STEPS * 3 / 5, u.shadow_ao_quality.x == 1.0);
                            let shadow_dist = select(120.0, 250.0, t > 200.0);
                            rt_shadow = getShadow(p + normal * 0.02, light_dir, 0.02, shadow_dist, 16.0, dither_threshold, max_steps);
                        }
                    }
                    if (u.shadow_ao_quality.y > 0.0 && !(is_wet && u.shadow_ao_quality.y < 2.0)) {
                        if (hitId == -1.0) {
                            rt_ao = voxel_val.w;
                        } else {
                            rt_ao = getAO(p, normal, dither_threshold);
                        }
                    }
                    if (u.shadow_ao_quality.x > 0.0 && !(is_wet && u.shadow_ao_quality.x < 2.0)) {
                        rt_sky_vis = rt_ao;
                    }
                    
                    shadow = mix(rt_shadow, voxel_val.z, blend_factor);
                    ao = mix(rt_ao, voxel_val.w, blend_factor);
                    sky_visibility = mix(rt_sky_vis, voxel_val.z, blend_factor);
                } else {
                    shadow = voxel_val.z;
                    sky_visibility = voxel_val.z;
                    ao = voxel_val.w;
                }

                // Hemispherical ambient skylight (cool blueish sky, warm dark grey ground bounce)
                let sky_color = vec3<f32>(0.15, 0.35, 0.25);
                let ground_color = vec3<f32>(0.06, 0.05, 0.05);
                let ambient = mix(ground_color, sky_color, normal.y * 0.5 + 0.5) * sky_visibility;

                let view_dir = normalize(u.cam_pos.xyz - p);
                let half_dir = normalize(light_dir + view_dir);

                // Clay/wax subsurface scattering (SSS) for translucent organic look
                var sss = 0.0;
                if (!is_wet) {
                    let sss_steps = 4;
                    var sss_thickness = 0.0;
                    let sss_step_size = 0.15;
                    for (var s_i = 1; s_i <= sss_steps; s_i = s_i + 1) {
                        let sample_p = p - normal * (f32(s_i) * sss_step_size);
                        let s_res = worldSDF(sample_p, rd, dither_threshold, false);
                        sss_thickness += max(0.0, -s_res.y);
                    }
                    let sss_dot = pow(max(dot(view_dir, -light_dir), 0.0), 2.0);
                    sss = exp(-sss_thickness * 2.0) * sss_dot * 0.4;
                }

                // Combine direct diffuse lighting, hemispherical ambient, and SSS scatter bloom
                var lighting = shadow * diffuse * vec3<f32>(1.0) + ambient + sss * vec3<f32>(0.85, 0.38, 0.22);

                var specular = 0.0;
                if (is_wet) {
                    let h = clamp(0.5 + 0.5 * (voxel_d - metaball_d) / u.grid_dims.w, 0.0, 1.0);
                    let fresnel = pow(1.0 - max(dot(normal, view_dir), 0.0), 5.0) * 0.85 + 0.15;
                    specular = pow(max(dot(normal, half_dir), 0.0), 120.0) * 2.0 * fresnel * shadow * h;
                } else {
                    // Subtle, broad specular highlight for dry terrain/blocks to add surface texture definition
                    specular = pow(max(dot(normal, half_dir), 0.0), 16.0) * 0.08 * shadow;
                }

                // Determine the base terrain color at p using dynamic biome blending
                let mat_id = i32(round(voxel_val.y));
                var terr_col = vec3<f32>(0.4, 0.4, 0.5);
                if (mat_id == 1 || mat_id == 2 || hitId == -1.0) {
                    let b_val = noise2d(p.x * 0.003, p.z * 0.003);
                    let w1 = clamp(1.0 - abs(b_val - 0.2) / 0.35, 0.0, 1.0);
                    let w2 = clamp(1.0 - abs(b_val - 0.5) / 0.35, 0.0, 1.0);
                    let w3 = clamp(1.0 - abs(b_val - 0.8) / 0.35, 0.0, 1.0);
                    let sum = w1 + w2 + w3;
                    let sum_safe = select(sum, 0.0001, sum < 0.0001);
                    let W1 = w1 / sum_safe;
                    let W2 = w2 / sum_safe;
                    let W3 = w3 / sum_safe;
                    
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
                    
                    terr_col = W1 * col_plains + W2 * col_canyons + W3 * col_mountains;
                }

                 var base_col = terr_col;
                 var edge = 0.0;

                if (hitId != -1.0 && !is_metaball) {
                    let s_idx = i32(hitId);
                    let s_data = u.instances[s_idx];
                    let lp = rotateVector(p - s_data.pos_scale.xyz, q_inv(s_data.rot));
                    if (s_data.color_csg.w == -5.0) {
                        let width = s_data.sph_fields.x;
                        let height = s_data.sph_fields.y;
                        let slider1_val = s_data.sph_fields.z;
                        let slider2_val = s_data.sph_fields.w;
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
                    } else if (s_data.sph_fields.x != 0.0) {
                        let temp_factor = clamp(abs(s_data.sph_fields.x) / 120.0, 0.0, 1.0);
                        let scroll_col = vec3<f32>(0.0);
                        let base_noise = evaluateFbm(lp * 4.0 - scroll_col);
                        let detail_noise = evaluateFbm(lp * 12.0 - scroll_col * 1.5);
                        let n_col = clamp(base_noise * 0.7 + detail_noise * 0.3, 0.0, 1.0);
                        
                        var fire_core = s_data.color_csg.rgb;
                        if (s_data.sph_fields.x < 0.0) {
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
                        base_col = s_data.color_csg.rgb;
                        if (s_data.color_csg.w < 0.0) {
                            edge = get_wireframe_edge(lp, s_data.pos_scale.w, 0.08);
                        }
                    }
                } else {
                    let fields = getInterpolatedFields(p);
                    let view_mode = u.grid_origin.w;

                    // Calculate water color at p (using world coordinates for waves layout)
                    let temp_factor = clamp(fields.x / 100.0, 0.0, 1.0);
                    let w_speed1 = u.time * (2.2 + temp_factor * 4.0);
                    let w_speed2 = u.time * (-1.5 - temp_factor * 3.0);
                    let wave_val1 = sin(p.x * 3.0 + p.z * 2.0 + w_speed1) * cos(p.x * -1.0 + p.z * 2.5 + w_speed1) * 0.5 + 0.5;
                    let wave_val2 = sin(p.x * 7.5 - p.z * 5.0 + w_speed2) * sin(p.x * 3.0 + p.z * 8.0 - w_speed2) * 0.5 + 0.5;
                    let wave_val = mix(wave_val1, wave_val2, 0.4);

                    var water_base = vec3<f32>(0.02, 0.25, 0.75);
                    var water_tip = vec3<f32>(0.15, 0.65, 0.95);

                    if (view_mode == 1.0) {
                        // Temperature
                        let norm_t = clamp(fields.x / 120.0, 0.0, 1.0);
                        water_base = mix(vec3<f32>(0.0, 0.1, 0.5), vec3<f32>(0.5, 0.5, 0.0), norm_t);
                        water_tip = mix(vec3<f32>(0.0, 0.8, 0.8), vec3<f32>(1.0, 0.1, 0.0), norm_t);
                    } else if (view_mode == 2.0) {
                        // Age / Time
                        let norm_age = clamp(fields.y / 12.0, 0.0, 1.0);
                        water_base = mix(vec3<f32>(0.1, 0.9, 0.1), vec3<f32>(0.1, 0.2, 0.9), norm_age);
                        water_tip = mix(vec3<f32>(0.8, 1.0, 0.2), vec3<f32>(0.9, 0.1, 0.9), norm_age);
                    } else if (view_mode == 3.0) {
                        // Humidity
                        let norm_hum = clamp(fields.z / 100.0, 0.0, 1.0);
                        water_base = mix(vec3<f32>(0.4, 0.3, 0.1), vec3<f32>(0.0, 0.4, 0.6), norm_hum);
                        water_tip = mix(vec3<f32>(0.6, 0.5, 0.2), vec3<f32>(0.0, 0.9, 0.9), norm_hum);
                    } else if (view_mode == 4.0) {
                        // Pressure
                        let norm_pres = clamp((fields.w - 1.0) / 30.0, 0.0, 1.0);
                        water_base = mix(vec3<f32>(0.1, 0.05, 0.3), vec3<f32>(0.0, 0.4, 0.8), norm_pres);
                        water_tip = mix(vec3<f32>(0.2, 0.1, 0.6), vec3<f32>(0.2, 0.8, 1.0), norm_pres);
                    }

                    let water_col = mix(water_base, water_tip, wave_val);

                    // Blend terrain color and water color smoothly (pow-based shallow transparency)
                    let h = clamp(0.5 + 0.5 * (voxel_d - metaball_d) / u.grid_dims.w, 0.0, 1.0);
                    let blend_h = pow(h, 1.8);
                    base_col = mix(terr_col, water_col, blend_h);

                    // Add animated foam froth at the shoreline intersections
                    let foam_edge = 1.0 - abs(h - 0.5) * 2.0;
                    var foam_intensity = 0.3;
                    if (view_mode == 4.0) {
                        foam_intensity = 0.3 + 0.5 * clamp((fields.w - 1.0) / 30.0, 0.0, 1.0);
                    }
                    let foam = pow(max(0.0, foam_edge), 8.0) * foam_intensity * (sin(p.x * 15.0 + p.z * 10.0 + u.time * 6.0) * sin(p.z * 18.0 - p.x * 8.0 - u.time * 4.0) * 0.5 + 0.5);
                    base_col += vec3<f32>(foam);

                    // Add glossy sky reflections
                    let view_dir = normalize(u.cam_pos.xyz - p);
                    let fresnel = pow(1.0 - max(dot(normal, view_dir), 0.0), 5.0) * 0.85 + 0.15;
                    let ref_dir = reflect(-view_dir, normal);
                    let sky_ref = getSkyColor(ref_dir) * sky_visibility;
                    base_col = mix(base_col, sky_ref, 0.25 * fresnel * h);
               }

                color = base_col * lighting * ao + vec3<f32>(specular);

               if (is_exp) {
                   let glow = mix(vec3<f32>(1.0, 0.15, 0.0), vec3<f32>(1.0, 0.9, 0.25), exp_n_col);
                   color = mix(color, base_col + glow * 2.0, exp_temp_factor * (0.3 + 0.7 * exp_n_col));
               }

                if (edge > 0.0) {
                   let glow_col = base_col * 2.5 + vec3<f32>(0.25);
                   color = mix(color, glow_col, edge);
               }
           }

           let transmittance = exp(-fog_optical_depth);
           color = color * transmittance + fog_color_accum * (1.0 - transmittance) / max(fog_optical_depth, 0.0001);
           let dither_noise = fract(sin(dot(frag_in.uv + vec2<f32>(u.time), vec2<f32>(12.9898, 78.233))) * 43758.5453) - 0.5;
           color += vec3<f32>(dither_noise) * (1.0 / 255.0);

          if (u.bg_color.w > 0.5) {
              let dx = abs(frag_in.uv.x) * u.width * 0.5;
              let dy = abs(frag_in.uv.y) * u.height * 0.5;
              if ((dx < 8.0 && dy < 1.0 && dx > 2.0) || (dy < 8.0 && dx < 1.0 && dy > 2.0)) {
                  color = vec3<f32>(0.0, 1.0, 0.0);
              }
          }
          return vec4<f32>(color, 1.0);
      }
    