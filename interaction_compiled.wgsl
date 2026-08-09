struct MaterialProperties {
    density: f32,
    strength: f32,       // crumbling/crushing limit
    erosion_rate: f32,   // base water erosion rate
    melt_temp: f32,      // melting point (for lava rules)
    melt_speed: f32,     // speed of melting
    acid_resist: f32,    // 0.0 = melts instantly, 1.0 = immune
}

fn get_material_properties(mat_id: f32) -> MaterialProperties {
    var props: MaterialProperties;
    
    // Default values (e.g. for grass/dirt/unrecognized)
    props.density = 1.0;
    props.strength = 14.0;
    props.erosion_rate = 0.25;
    props.melt_temp = 9999.0; // immune to melting
    props.melt_speed = 0.0;
    props.acid_resist = 0.3; // moderately vulnerable
    
    let m = i32(round(abs(mat_id)));
    
    if (m == 2) { // Natural Biome Green (Dirt/Grass)
        props.density = 1.0;
        props.strength = 14.0;
        props.erosion_rate = 0.25;
        props.melt_temp = 200.0; // organic burns easily
        props.melt_speed = 3.0;
        props.acid_resist = 0.1; // easily eaten
    } else if (m == 3) { // Stone Grey
        props.density = 2.0; // heavy
        props.strength = 24.0; // strong
        props.erosion_rate = 0.06; // hard to erode
        props.melt_temp = 1200.0; // melts at high temp
        props.melt_speed = 2.0;
        props.acid_resist = 0.7; // resistant
    } else if (m == 5) { // Sand Beige
        props.density = 1.2;
        props.strength = 4.0; // very weak structure
        props.erosion_rate = 0.8; // erodes very quickly
        props.melt_temp = 1400.0; // turns to glass at extremely high temp
        props.melt_speed = 1.0;
        props.acid_resist = 0.4;
    } else if (m == 6) { // Snow / Ice
        props.density = 0.5; // lightweight
        props.strength = 8.0;
        props.erosion_rate = 0.5; // melts/erodes in water
        props.melt_temp = 0.0; // melts at 0 degrees!
        props.melt_speed = 10.0; // melts extremely fast
        props.acid_resist = 0.8;
    } else if (m == 7 || m == 14) { // Volcanic Obsidian
        props.density = 2.5; // very dense
        props.strength = 36.0; // extremely strong
        props.erosion_rate = 0.005; // almost immune to water erosion
        props.melt_temp = 1600.0; // very high melting point
        props.melt_speed = 0.5;
        props.acid_resist = 1.0; // completely immune to acid!
    } else if (m == 8) { // Deep Cave Moss
        props.density = 0.8;
        props.strength = 6.0;
        props.erosion_rate = 0.40;
        props.melt_temp = 80.0; // organic burns easily
        props.melt_speed = 6.0;
        props.acid_resist = 0.1;
    } else if (m == 9) { // Amethyst Purple Crystal
        props.density = 2.2;
        props.strength = 28.0;
        props.erosion_rate = 0.02;
        props.melt_temp = 1400.0;
        props.melt_speed = 0.8;
        props.acid_resist = 0.9;
    } else if (m == 10) { // Clay Brown
        props.density = 1.5;
        props.strength = 12.0;
        props.erosion_rate = 0.15;
        props.melt_temp = 1000.0;
        props.melt_speed = 1.0;
        props.acid_resist = 0.5;
    } else if (m == 11) { // Glowing Neon Cyan
        props.density = 1.0;
        props.strength = 15.0;
        props.erosion_rate = 0.10;
        props.melt_temp = 800.0;
        props.melt_speed = 2.0;
        props.acid_resist = 0.5;
    } else if (m == 12) { // Shiny Gold / Brass
        props.density = 4.5; // extremely heavy payloads!
        props.strength = 30.0;
        props.erosion_rate = 0.01; // metal does not erode in water
        props.melt_temp = 900.0; // melts into lava
        props.melt_speed = 4.0;
        props.acid_resist = 0.6; // metals dissolve in acid
    } else if (m == 13) { // Pulsating Lava Crimson
        props.density = 2.0;
        props.strength = 10.0;
        props.erosion_rate = 0.10;
        props.melt_temp = -100.0; // always molten
        props.melt_speed = 0.0;
        props.acid_resist = 0.9;
    }
    
    return props;
}
            struct PointInstance {
                pos_scale: vec4<f32>,
                rot: vec4<f32>,
                color_csg: vec4<f32>,
                light_fields: vec4<f32>,
                interaction_fields: vec4<f32>,
                em_fields: vec4<f32>,
                shape_info: vec4<f32>,
                gravity_field: vec4<f32>,
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

            struct ChunkLookup {
                origin: vec4<i32>,
                slots: array<vec4<i32>, 8192>,
                skip_grid: array<vec4<i32>, 128>,
            }

            struct ChunkInfo {
                origin_slot: vec4<f32>,
            }

            @group(0) @binding(0) var<storage, read> input_fields: array<vec4<f32>>;
            @group(0) @binding(1) var<storage, read_write> output_fields: array<vec4<f32>>;
            @group(0) @binding(2) var<uniform> u: Uniforms;
            @group(0) @binding(3) var<storage, read> chunk_info: ChunkInfo;
            @group(0) @binding(4) var<storage, read> chunk_lookup: ChunkLookup;
            @group(0) @binding(5) var voxel_texture: texture_3d<f32>;
            @group(0) @binding(10) var<storage, read> instances: array<PointInstance>;
            const GRID_RES: i32 = 32i;
            @group(0) @binding(6) var water_texture: texture_3d<f32>;
            @group(0) @binding(7) var gas_texture: texture_3d<f32>;
            @group(0) @binding(8) var em_texture: texture_3d<f32>;
            @group(0) @binding(9) var gravity_texture: texture_3d<f32>;
            @group(0) @binding(11) var voxel_baked_values_texture: texture_3d<f32>;

            fn get_baked_values(x: i32, y: i32, z: i32) -> vec4<f32> {
                let world_v = chunk_info.origin_slot.xyz + vec3<f32>(f32(x), f32(y), f32(z));
                let q = vec3<i32>(floor(world_v / f32(GRID_RES)));
                let l = vec3<i32>(world_v - vec3<f32>(q) * f32(GRID_RES));
                let lx = l.x;
                let ly = l.y;
                let lz = l.z;
                let local_q = q - chunk_lookup.origin.xyz;
                if (any(local_q < vec3<i32>(0)) || any(local_q >= vec3<i32>(32))) {
                    return vec4<f32>(0.0);
                }
                let idx = local_q.x + local_q.y * 32 + local_q.z * 1024;
                let slot = chunk_lookup.slots[u32(idx) >> 2u][idx & 3];
                if (slot < 0) {
                    return vec4<f32>(0.0);
                }
                let slot_x = slot % 12i;
                let slot_y = (slot / 12i) % 12i;
                let slot_z = slot / 144i;
                let atlas_coord = vec3<i32>((slot_x * GRID_RES) + lx, (slot_y * GRID_RES) + ly, (slot_z * GRID_RES) + lz);
                return textureLoad(voxel_baked_values_texture, atlas_coord, 0);
            }

            fn get_water(x: i32, y: i32, z: i32) -> vec4<f32> {
                let world_v = chunk_info.origin_slot.xyz + vec3<f32>(f32(x), f32(y), f32(z));
                let res_f = f32(GRID_RES);
                let q = vec3<i32>(floor(world_v / res_f));
                let l = vec3<i32>(world_v - vec3<f32>(q) * res_f);
                let lx = l.x;
                let ly = l.y;
                let lz = l.z;
                
                let local_q = q - chunk_lookup.origin.xyz;
                if (any(local_q < vec3<i32>(0)) || any(local_q >= vec3<i32>(32))) {
                    return vec4<f32>(0.0);
                }
                
                let mx = u32(local_q.x) >> 2u;
                let my = u32(local_q.y) >> 2u;
                let mz = u32(local_q.z) >> 2u;
                let skip_idx = mx + (my << 3u) + (mz << 6u);
                let skip_val = chunk_lookup.skip_grid[skip_idx >> 2u][skip_idx & 3];
                if (skip_val == 0) {
                    return vec4<f32>(0.0);
                }
                
                let idx = local_q.x + local_q.y * 32 + local_q.z * 1024;
                let slot = chunk_lookup.slots[u32(idx) >> 2u][idx & 3];
                if (slot < 0) {
                    return vec4<f32>(0.0);
                }
                
                let slot_x = slot % 12i;
                let slot_y = (slot / 12i) % 12i;
                let slot_z = slot / 144i;
                
                let atlas_coord = vec3<i32>((slot_x * 32i) + lx, (slot_y * 32i) + ly, (slot_z * 32i) + lz);
                return textureLoad(water_texture, atlas_coord, 0);
            }

            fn get_gas(x: i32, y: i32, z: i32) -> vec4<f32> {
                let world_v = chunk_info.origin_slot.xyz + vec3<f32>(f32(x), f32(y), f32(z));
                let res_f = f32(GRID_RES);
                let q = vec3<i32>(floor(world_v / res_f));
                let l = vec3<i32>(world_v - vec3<f32>(q) * res_f);
                let lx = l.x;
                let ly = l.y;
                let lz = l.z;
                
                let local_q = q - chunk_lookup.origin.xyz;
                if (any(local_q < vec3<i32>(0)) || any(local_q >= vec3<i32>(32))) {
                    return vec4<f32>(0.0);
                }
                
                let mx = u32(local_q.x) >> 2u;
                let my = u32(local_q.y) >> 2u;
                let mz = u32(local_q.z) >> 2u;
                let skip_idx = mx + (my << 3u) + (mz << 6u);
                let skip_val = chunk_lookup.skip_grid[skip_idx >> 2u][skip_idx & 3];
                if (skip_val == 0) {
                    return vec4<f32>(0.0);
                }
                
                let idx = local_q.x + local_q.y * 32 + local_q.z * 1024;
                let slot = chunk_lookup.slots[u32(idx) >> 2u][idx & 3];
                if (slot < 0) {
                    return vec4<f32>(0.0);
                }
                
                let slot_x = slot % 12i;
                let slot_y = (slot / 12i) % 12i;
                let slot_z = slot / 144i;
                
                let atlas_coord = vec3<i32>((slot_x * 32i) + lx, (slot_y * 32i) + ly, (slot_z * 32i) + lz);
                return textureLoad(gas_texture, atlas_coord, 0);
            }

            fn get_em(x: i32, y: i32, z: i32) -> vec4<f32> {
                let world_v = chunk_info.origin_slot.xyz + vec3<f32>(f32(x), f32(y), f32(z));
                let res_f = f32(GRID_RES);
                let q = vec3<i32>(floor(world_v / res_f));
                let l = vec3<i32>(world_v - vec3<f32>(q) * res_f);
                let lx = l.x;
                let ly = l.y;
                let lz = l.z;
                
                let local_q = q - chunk_lookup.origin.xyz;
                if (any(local_q < vec3<i32>(0)) || any(local_q >= vec3<i32>(32))) {
                    return vec4<f32>(0.0);
                }
                
                let mx = u32(local_q.x) >> 2u;
                let my = u32(local_q.y) >> 2u;
                let mz = u32(local_q.z) >> 2u;
                let skip_idx = mx + (my << 3u) + (mz << 6u);
                let skip_val = chunk_lookup.skip_grid[skip_idx >> 2u][skip_idx & 3];
                if (skip_val == 0) {
                    return vec4<f32>(0.0);
                }
                
                let idx = local_q.x + local_q.y * 32 + local_q.z * 1024;
                let slot = chunk_lookup.slots[u32(idx) >> 2u][idx & 3];
                if (slot < 0) {
                    return vec4<f32>(0.0);
                }
                
                let slot_x = slot % 12i;
                let slot_y = (slot / 12i) % 12i;
                let slot_z = slot / 144i;
                
                let atlas_coord = vec3<i32>((slot_x * 32i) + lx, (slot_y * 32i) + ly, (slot_z * 32i) + lz);
                return textureLoad(em_texture, atlas_coord, 0);
            }

            fn get_gravity(x: i32, y: i32, z: i32) -> vec4<f32> {
                let world_v = chunk_info.origin_slot.xyz + vec3<f32>(f32(x), f32(y), f32(z));
                let cell_size = u.cell_size;
                let pos = world_v * cell_size;
                
                var sum_grav = vec3<f32>(0.0);
                var sum_td = 0.0;
                var sum_W = 0.0;
                let epsilon = 0.01;
                
                let max_instances = u32(round(u.suns[0].params.y));
                for (var i = 0u; i < max_instances; i = i + 1u) {
                    let inst = instances[i];
                    let rad = inst.pos_scale.w;
                    if (rad > 0.0) {
                        let inst_pos = inst.pos_scale.xyz;
                        let to_pos = pos - inst_pos;
                        let dist = length(to_pos);
                        let d = dist - rad;
                        let w_denom = d * d + epsilon;
                        let w = 1.0 / w_denom;
                        
                        let grav = inst.gravity_field.xyz;
                        let td = inst.gravity_field.w;
                        
                        sum_grav = sum_grav + grav * w;
                        sum_td = sum_td + td * w;
                        sum_W = sum_W + w;
                    }
                }
                
                if (sum_W > 0.00001) {
                    return vec4<f32>(sum_grav / sum_W, sum_td / sum_W);
                } else {
                    return vec4<f32>(0.0, -9.81, 0.0, 1.0);
                }
            }

            fn get_fluid(x: i32, y: i32, z: i32) -> vec4<f32> {
                if (x >= 0 && x < 32i && y >= 0 && y < 32i && z >= 0 && z < 32i) {
                    let idx = x + y * 32i + z * 1024i;
                    return input_fields[idx];
                } else {
                    return get_water(x, y, z);
                }
            }


             fn get_voxel(x: i32, y: i32, z: i32) -> vec4<f32> {
                 let world_v = chunk_info.origin_slot.xyz + vec3<f32>(f32(x), f32(y), f32(z));
                 let res_f = f32(GRID_RES);
                 let q = vec3<i32>(floor(world_v / res_f));
                 let l = vec3<i32>(world_v - vec3<f32>(q) * res_f);
                 let lx = l.x;
                 let ly = l.y;
                 let lz = l.z;
                 
                 let local_q = q - chunk_lookup.origin.xyz;
                 if (any(local_q < vec3<i32>(0)) || any(local_q >= vec3<i32>(32))) {
                     return vec4<f32>(1.0, 1.5, 1.0, 1.0);
                 }
                 
                 let mx = u32(local_q.x) >> 2u;
                 let my = u32(local_q.y) >> 2u;
                 let mz = u32(local_q.z) >> 2u;
                 let skip_idx = mx + (my << 3u) + (mz << 6u);
                 let skip_val = chunk_lookup.skip_grid[skip_idx >> 2u][skip_idx & 3];
                 if (skip_val == 0) {
                     return vec4<f32>(1.0, 1.5, 1.0, 1.0);
                 }
                 
                 let idx = local_q.x + local_q.y * 32 + local_q.z * 1024;
                 let slot = chunk_lookup.slots[u32(idx) >> 2u][idx & 3];
                 if (slot < 0) {
                     return vec4<f32>(1.0, 1.5, 1.0, 1.0);
                 }
                 
                 let slot_x = slot % 12i;
                 let slot_y = (slot / 12i) % 12i;
                 let slot_z = slot / 144i;
                 
                 let atlas_coord = vec3<i32>((slot_x * 32i) + lx, (slot_y * 32i) + ly, (slot_z * 32i) + lz);
                 return textureLoad(voxel_texture, atlas_coord, 0);
             }

            @compute @workgroup_size(64)
            fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
                let idx = global_id.x;
                if (idx >= 32768u) { return; }
                
                let local_x = i32(idx % 32u);
                let local_y = i32((idx / 32u) % 32u);
                let local_z = i32(idx / 1024u);
                
                var fields = input_fields[idx];
                let voxel_pos = chunk_info.origin_slot.xyz + vec3<f32>(f32(local_x), f32(local_y), f32(local_z)) * 1;
                 let dt = 0.00833 * get_gravity(local_x, local_y, local_z).w;
                 let dummy_use = u.time * 0.0;
                 fields.x += dummy_use;
                 // --- DYNAMIC INJECTIONS LOOP ---
{
// === Injected from interaction_rule.wgsl ===
// interaction_rule.wgsl - Native GPU-Resident JIT Voxel-Interaction Simulation Loop
//
// Input/Output variable is:
//   var fields: vec4<f32>; // (x: Temp, y: Density, z: Stress, w: Material ID)
//
// You also have access to:
//   - `voxel_pos` (vec3<f32> representing the voxel's world space position)
//   - `dt` (f32 time step, e.g., 0.00833)
//   - `get_voxel(x, y, z)`: helper to sample voxel SDF/Materials at absolute chunk coordinates.
//     Returns a vec4<f32> where:
//       - x: SDF distance (negative inside material, positive outside)
//       - y: Material ID of that neighbor
//

let voxel_self = get_voxel(local_x, local_y, local_z);

if (voxel_self.y >= 0.0) {
    // Air has no stress or shear/fatigue
    fields.y = 0.0;
    fields.z = 0.0;
    fields.w = 0.0;
} else {
    // Solid terrain
    let mat_id = round(abs(voxel_self.x));
    let props = get_material_properties(mat_id);
    let ix = local_x;
    let iy = local_y;
    let iz = local_z;
    
    // 1. CA-Based Compressive Stress Propagation (Gravity)
    var stress = props.density;
    
    // Get load from directly above
    let above_y = iy + 1;
    if (above_y < 32) {
        let above_idx = u32(ix + above_y * 32 + iz * 1024);
        let above_voxel = get_voxel(ix, above_y, iz);
        if (above_voxel.y < 0.0) {
            stress = stress + input_fields[above_idx].z;
        }
    }
    
    // Gather redistributed load from neighboring overhangs
    var redistributed_load = 0.0;
    let horiz_dirs = array<vec3<i32>, 4>(
        vec3<i32>(-1, 0, 0), vec3<i32>(1, 0, 0),
        vec3<i32>(0, 0, -1), vec3<i32>(0, 0, 1)
    );
    
    for (var i = 0; i < 4; i = i + 1) {
        let nx = ix + horiz_dirs[i].x;
        let nz = iz + horiz_dirs[i].z;
        if (nx >= 0 && nx < 32 && nz >= 0 && nz < 32) {
            let n_voxel = get_voxel(nx, iy, nz);
            if (n_voxel.y < 0.0) {
                let n_below_voxel = get_voxel(nx, iy - 1, nz);
                if (n_below_voxel.y >= 0.0) {
                    var solid_count = 0.0;
                    for (var j = 0; j < 4; j = j + 1) {
                        let nnx = nx + horiz_dirs[j].x;
                        let nnz = nz + horiz_dirs[j].z;
                        if (nnx >= 0 && nnx < 32 && nnz >= 0 && nnz < 32) {
                            let nn_voxel = get_voxel(nnx, iy, nnz);
                            if (nn_voxel.y < 0.0) {
                                solid_count = solid_count + 1.0;
                            }
                        }
                    }
                    if (solid_count > 0.0) {
                        let n_idx = u32(nx + iy * 32 + nz * 1024);
                        var neighbor_load = get_material_properties(round(abs(n_voxel.x))).density;
                        if (above_y < 32) {
                            let n_above_idx = u32(nx + above_y * 32 + nz * 1024);
                            let n_above_voxel = get_voxel(nx, above_y, nz);
                            if (n_above_voxel.y < 0.0) {
                                neighbor_load = neighbor_load + input_fields[n_above_idx].z;
                            }
                        }
                        redistributed_load = redistributed_load + (neighbor_load / solid_count);
                    }
                }
            }
        }
    }
    stress = stress + redistributed_load;
    
    // 2. CA-Based Shear Stress Propagation (Bending Moment)
    var shear_stress = 0.0;
    let below_voxel = get_voxel(ix, iy - 1, iz);
    if (below_voxel.y >= 0.0) {
        var max_neighbor_shear = 0.0;
        for (var i = 0; i < 4; i = i + 1) {
            let nx = ix + horiz_dirs[i].x;
            let nz = iz + horiz_dirs[i].z;
            if (nx >= 0 && nx < 32 && nz >= 0 && nz < 32) {
                let n_voxel = get_voxel(nx, iy, nz);
                if (n_voxel.y < 0.0) {
                    let n_idx = u32(nx + iy * 32 + nz * 1024);
                    max_neighbor_shear = max(max_neighbor_shear, input_fields[n_idx].y);
                }
            }
        }
        shear_stress = 2.0 + max_neighbor_shear;
    } else {
        shear_stress = max(0.0, fields.y - 5.0 * dt);
    }
    
    fields.z = min(stress, 15.0);
    fields.y = min(shear_stress, 15.0);
    
    // 3. Accumulate Structural Fatigue / Damage (with Thermal Shock & Weakening)
    var fatigue = fields.w;
    let limit = props.strength;
    
    var temp_grad = 0.0;
    var temp_count = 0.0;
    for (var i = 0; i < 4; i = i + 1) {
        let nx = ix + horiz_dirs[i].x;
        let nz = iz + horiz_dirs[i].z;
        if (nx >= 0 && nx < 32 && nz >= 0 && nz < 32) {
            let n_voxel = get_voxel(nx, iy, nz);
            if (n_voxel.y < 0.0) {
                let n_idx = u32(nx + iy * 32 + nz * 1024);
                temp_grad = temp_grad + abs(input_fields[n_idx].x - fields.x);
                temp_count = temp_count + 1.0;
            }
        }
    }
    var thermal_stress = 0.0;
    if (temp_count > 0.0) {
        thermal_stress = (temp_grad / temp_count) * 0.4;
    }
    
    var effective_limit = limit;
    if (props.melt_temp < 9000.0) {
        let temp_ratio = clamp(fields.x / props.melt_temp, 0.0, 1.0);
        effective_limit = limit * (1.0 - temp_ratio * 0.85);
    }
    
    let total_stress = (fields.z - 1.0) * 0.5 + fields.y * 3.0 + thermal_stress;
    let fatigue_threshold = effective_limit * 0.65;
    if (total_stress >= fatigue_threshold) {
        let excess = total_stress - fatigue_threshold;
        fatigue = fatigue + (0.3 + excess * 0.2) * dt;
    } else {
        fatigue = fatigue - 0.05 * dt;
    }
    fields.w = clamp(fatigue, 0.0, 1.0);

    // Material thermal conductivity influence (Snow/Ice cools, Lava heats)
    if (mat_id == 6.0) { // Snow / Ice
        fields.x = max(-50.0, fields.x - 35.0 * dt);
    } else if (mat_id == 13.0) { // Lava / Burning embers
        fields.x = min(150.0, fields.x + 90.0 * dt);
    }
}

// 3. Fluid Heat Interaction (Water cools, Lava heats, Steam warms)
let water_here = get_water(local_x, local_y, local_z);
let gas_here = get_gas(local_x, local_y, local_z);

let w_water = water_here.x;
let w_lava = water_here.y;
let g_steam = gas_here.x;

if (w_lava > 0.05) {
    fields.x = min(150.0, fields.x + w_lava * 120.0 * dt);
} else if (w_water > 0.05) {
    fields.x = max(15.0, fields.x - w_water * 50.0 * dt);
} else if (g_steam > 0.05) {
    fields.x = min(90.0, fields.x + g_steam * 25.0 * dt);
}

// 4. Thermal Diffusion & Ambient Decay (executed for all voxels)
var temp_sum = 0.0;
var count = 0.0;

let directions = array<vec3<i32>, 6>(
    vec3<i32>(-1, 0, 0), vec3<i32>(1, 0, 0),
    vec3<i32>(0, -1, 0), vec3<i32>(0, 1, 0),
    vec3<i32>(0, 0, -1), vec3<i32>(0, 0, 1)
);

for (var i = 0; i < 6; i = i + 1) {
    let nx = local_x + directions[i].x;
    let ny = local_y + directions[i].y;
    let nz = local_z + directions[i].z;
    
    if (nx >= 0 && nx < 32 && ny >= 0 && ny < 32 && nz >= 0 && nz < 32) {
        let n_idx = u32(nx + ny * 32 + nz * 1024);
        temp_sum = temp_sum + input_fields[n_idx].x;
        count = count + 1.0;
    } else {
        // Adiabatic boundary (insulated chunk edges)
        temp_sum = temp_sum + fields.x;
        count = count + 1.0;
    }
}

let avg_neighbor_temp = temp_sum / count;

// Heat diffusion (conduction) rate (1.5)
fields.x = fields.x + (avg_neighbor_temp - fields.x) * 1.5 * dt;

// Slow decay towards ambient temperature (20.0 C)
fields.x = fields.x + (20.0 - fields.x) * 0.05 * dt;

}

                output_fields[idx] = fields + vec4<f32>(f32((textureDimensions(voxel_texture) + textureDimensions(water_texture) + textureDimensions(gas_texture) + textureDimensions(em_texture) + textureDimensions(gravity_texture) + textureDimensions(voxel_baked_values_texture)).x) * 0.0f);
            }