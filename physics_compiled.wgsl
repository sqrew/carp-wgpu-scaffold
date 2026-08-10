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

            @group(0) @binding(0) var<storage, read> input_grid: array<vec4<f32>>;
            @group(0) @binding(1) var<storage, read_write> output_grid: array<vec4<f32>>;
            @group(0) @binding(2) var<uniform> u: Uniforms;
            @group(0) @binding(3) var<storage, read> chunk_info: ChunkInfo;
            @group(0) @binding(4) var<storage, read> chunk_lookup: ChunkLookup;
            @group(0) @binding(5) var voxel_texture: texture_3d<f32>;
            @group(0) @binding(10) var<storage, read> instances: array<PointInstance>;
            @group(0) @binding(6) var water_texture: texture_3d<f32>;
            @group(0) @binding(7) var gas_texture: texture_3d<f32>;
            @group(0) @binding(8) var em_texture: texture_3d<f32>;
            @group(0) @binding(9) var gravity_texture: texture_3d<f32>;
            @group(0) @binding(11) var voxel_baked_values_texture: texture_3d<f32>;

            fn get_water(x: i32, y: i32, z: i32) -> vec4<f32> {
                let world_v = vec3<f32>(round(chunk_info.origin_slot.xyz * (f32(32i) / 32.0))) + vec3<f32>(f32(x), f32(y), f32(z));
                let res_f = f32(32i);
                let q = vec3<i32>(floor(world_v / res_f));
                let l = vec3<i32>(world_v - vec3<f32>(q) * res_f);
                
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
                
                let atlas_coord = vec3<i32>((slot_x * 32i) + l.x, (slot_y * 32i) + l.y, (slot_z * 32i) + l.z);
                return textureLoad(water_texture, atlas_coord, 0);
            }

            fn get_gravity(x: i32, y: i32, z: i32) -> vec4<f32> {
                let world_v = vec3<f32>(round(chunk_info.origin_slot.xyz * (f32(32i) / 32.0))) + vec3<f32>(f32(x), f32(y), f32(z));
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

            fn get_gas(x: i32, y: i32, z: i32) -> vec4<f32> {
                let world_v = vec3<f32>(round(chunk_info.origin_slot.xyz * (f32(32i) / 32.0))) + vec3<f32>(f32(x), f32(y), f32(z));
                let res_f = f32(32i);
                let q = vec3<i32>(floor(world_v / res_f));
                let l = vec3<i32>(world_v - vec3<f32>(q) * res_f);
                
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
                
                let atlas_coord = vec3<i32>((slot_x * 32i) + l.x, (slot_y * 32i) + l.y, (slot_z * 32i) + l.z);
                return textureLoad(gas_texture, atlas_coord, 0);
            }

            fn get_voxel(x: i32, y: i32, z: i32) -> vec4<f32> {
                if (x >= 0 && x < 32 && y >= 0 && y < 32 && z >= 0 && z < 32) {
                    let idx = u32(x + y * 32 + z * 1024);
                    return input_grid[idx];
                }
                
                let world_v = vec3<i32>(round(chunk_info.origin_slot.xyz * (f32(32i) / 32.0))) + vec3<i32>(x, y, z);
                let qx = world_v.x >> 5u;
                let qy = world_v.y >> 5u;
                let qz = world_v.z >> 5u;
                
                let lx = world_v.x & 31i;
                let ly = world_v.y & 31i;
                let lz = world_v.z & 31i;
                
                let local_q = vec3<i32>(qx, qy, qz) - chunk_lookup.origin.xyz;
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

            fn get_baked_values(x: i32, y: i32, z: i32) -> vec4<f32> {
                let world_v = vec3<i32>(round(chunk_info.origin_slot.xyz * (f32(32i) / 32.0))) + vec3<i32>(x, y, z);
                let qx = world_v.x >> 5u;
                let qy = world_v.y >> 5u;
                let qz = world_v.z >> 5u;
                
                let lx = world_v.x & 31i;
                let ly = world_v.y & 31i;
                let lz = world_v.z & 31i;
                
                let local_q = vec3<i32>(qx, qy, qz) - chunk_lookup.origin.xyz;
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
                
                let atlas_coord = vec3<i32>((slot_x * 32i) + lx, (slot_y * 32i) + ly, (slot_z * 32i) + lz);
                return textureLoad(voxel_baked_values_texture, atlas_coord, 0);
            }

            @compute @workgroup_size(64)
            fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
                let idx = global_id.x;
                if (idx >= 32768u) { return; }
                
                let local_x = i32(idx % 32u);
                let local_y = i32((idx / 32u) % 32u);
                let local_z = i32(idx / 1024u);
                
                var cell = input_grid[idx];
                let voxel_pos = chunk_info.origin_slot.xyz + vec3<f32>(f32(local_x), f32(local_y), f32(local_z)) * 1;
                let dt = 0.00833 * get_gravity(local_x, local_y, local_z).w;
                let dummy_use = u.time * 0.0;
                cell.y += dummy_use;
                var cell_velocity = vec3<f32>(0.0);
                // --- DYNAMIC INJECTIONS LOOP ---
{
// === Injected from physics_rule.wgsl ===
// physics_rule.wgsl - Native GPU-Resident JIT Shader Injection Loop
// Modifying this file live updates the global physical behaviors of the voxel grid.

let solid_thresh = u.terrain_params3.z;

if (cell.y <= solid_thresh) {
    var gravity_load = 1.0;
    for (var dy = 1; dy <= 12; dy = dy + 1) {
        let voxel = get_voxel(local_x, local_y + dy, local_z);
        if (voxel.y <= solid_thresh) { // Solid
            let top_mat = round(abs(voxel.x));
            let top_props = get_material_properties(top_mat);
            gravity_load = gravity_load + top_props.density;
        } else {
            break;
        }
    }

    // 2. Shear stress: scan below to see if unsupported
    let below_voxel = get_voxel(local_x, local_y - 1, local_z);
    var shear_load = 0.0;
    
    // Treat unloaded chunk bounds (returning 1.0, 1.5) as solid support to prevent boundary false-collapses
    let is_below_unloaded = (below_voxel.x == 1.0);
    
    if (below_voxel.y > solid_thresh && !is_below_unloaded) { // Air below us (overhang!)
        var min_dist = 999.0;
        // Scan Left (-X)
        for (var dx = 1; dx <= 6; dx = dx + 1) {
            let voxel_here = get_voxel(local_x - dx, local_y, local_z);
            let here_unloaded = (voxel_here.x == 1.0);
            if (voxel_here.y <= solid_thresh || here_unloaded) {
                let voxel_below = get_voxel(local_x - dx, local_y - 1, local_z);
                let below_unloaded = (voxel_below.x == 1.0);
                if (voxel_below.y <= solid_thresh || below_unloaded) {
                    min_dist = min(min_dist, f32(dx));
                    break;
                }
            } else {
                break;
            }
        }
        // Scan Right (+X)
        for (var dx = 1; dx <= 6; dx = dx + 1) {
            let voxel_here = get_voxel(local_x + dx, local_y, local_z);
            let here_unloaded = (voxel_here.x == 1.0);
            if (voxel_here.y <= solid_thresh || here_unloaded) {
                let voxel_below = get_voxel(local_x + dx, local_y - 1, local_z);
                let below_unloaded = (voxel_below.x == 1.0);
                if (voxel_below.y <= solid_thresh || below_unloaded) {
                    min_dist = min(min_dist, f32(dx));
                    break;
                }
            } else {
                break;
            }
        }
        // Scan Forward (+Z)
        for (var dz = 1; dz <= 6; dz = dz + 1) {
            let voxel_here = get_voxel(local_x, local_y, local_z + dz);
            let here_unloaded = (voxel_here.x == 1.0);
            if (voxel_here.y <= solid_thresh || here_unloaded) {
                let voxel_below = get_voxel(local_x, local_y - 1, local_z + dz);
                let below_unloaded = (voxel_below.x == 1.0);
                if (voxel_below.y <= solid_thresh || below_unloaded) {
                    min_dist = min(min_dist, f32(dz));
                    break;
                }
            } else {
                break;
            }
        }
        // Scan Backward (-Z)
        for (var dz = 1; dz <= 6; dz = dz + 1) {
            let voxel_here = get_voxel(local_x, local_y, local_z - dz);
            let here_unloaded = (voxel_here.x == 1.0);
            if (voxel_here.y <= solid_thresh || here_unloaded) {
                let voxel_below = get_voxel(local_x, local_y - 1, local_z - dz);
                let below_unloaded = (voxel_below.x == 1.0);
                if (voxel_below.y <= solid_thresh || below_unloaded) {
                    min_dist = min(min_dist, f32(dz));
                    break;
                }
            } else {
                break;
            }
        }
        if (min_dist < 999.0) {
            shear_load = min_dist;
        } else {
            shear_load = 6.0;
        }
    }

    // Reduced coefficients (gravity * 0.4, shear * 1.2) to allow natural terrain overhangs
    // and arches to stand stable, while still slumping under heavy structural loads.
    let total_stress = (gravity_load - 1.0) * 0.4 + shear_load * 1.2;
    let mat = round(abs(cell.x));
    let props = get_material_properties(mat);
    let limit = props.strength;

    if (cell.x < 0.0) {
        let below = get_voxel(local_x, local_y - 1, local_z);
        let solid_thresh_check = u.terrain_params3.z;
        if (below.y > solid_thresh_check && below.x != 1.0) {
            // Fall straight down
            cell.x = 0.0; // Air ID
            cell.y = 0.5; // open density
        } else {
            // Try sliding diagonally below in 4 directions
            let below_r = get_voxel(local_x + 1, local_y - 1, local_z);
            let below_l = get_voxel(local_x - 1, local_y - 1, local_z);
            let below_b = get_voxel(local_x, local_y - 1, local_z - 1);
            let below_f = get_voxel(local_x, local_y - 1, local_z + 1);
            
            if (below_r.y > solid_thresh_check && below_r.x != 1.0) {
                cell.x = 0.0;
                cell.y = 0.5;
            } else if (below_l.y > solid_thresh_check && below_l.x != 1.0) {
                cell.x = 0.0;
                cell.y = 0.5;
            } else if (below_b.y > solid_thresh_check && below_b.x != 1.0) {
                cell.x = 0.0;
                cell.y = 0.5;
            } else if (below_f.y > solid_thresh_check && below_f.x != 1.0) {
                cell.x = 0.0;
                cell.y = 0.5;
            } else {
                cell.x = abs(cell.x); // stabilize and land!
            }
        }
    } else {
        if (total_stress >= limit && shear_load > 0.5) {
            cell_velocity += vec3<f32>(
                sin(voxel_pos.x * 20.0) * 1.5,
                -6.0,
                cos(voxel_pos.z * 20.0) * 1.5
            ) * dt * 20.0;
            cell.x = -abs(cell.x); // start crumbling!
        }

        // --- Water Erosion ---
        let w_above_val = get_water(local_x, local_y + 1, local_z);
        let w_left_val  = get_water(local_x - 1, local_y, local_z);
        let w_right_val = get_water(local_x + 1, local_y, local_z);
        let w_front_val = get_water(local_x, local_y, local_z - 1);
        let w_back_val  = get_water(local_x, local_y, local_z + 1);
        
        let w_above = select(0.0, w_above_val.y, round(w_above_val.x) == 1.0);
        let w_left  = select(0.0, w_left_val.y,  round(w_left_val.x) == 1.0);
        let w_right = select(0.0, w_right_val.y, round(w_right_val.x) == 1.0);
        let w_front = select(0.0, w_front_val.y, round(w_front_val.x) == 1.0);
        let w_back  = select(0.0, w_back_val.y,  round(w_back_val.x) == 1.0);
        
        let water_vol = max(w_above, max(w_left, max(w_right, max(w_front, w_back))));
        if (water_vol > 0.05) {
            let erosion_rate = props.erosion_rate;
            let stress_factor = 1.0 + clamp((total_stress - limit) / limit, 0.0, 2.0);
            let actual_erosion = erosion_rate * stress_factor;
            cell.y = cell.y + dt * water_vol * actual_erosion * 2.5 * u.misc_params.z;
            
            if (cell.y > -0.2 && cell.y < 0.0 && mat != 10.0) {
                cell.x = 10.0; // clay
            }
        }
    }
}

// --- Lava Solidification & Falling Material (Runs in air cells) ---
if (cell.y > solid_thresh) {
    let water_here = get_water(local_x, local_y, local_z);
    
    // If we are Lava and contact Water neighbor, or if we are Water and contact Lava neighbor
    let is_lava = round(water_here.x) == 2.0 && water_here.y > 0.08;
    
    var has_water_neighbor = false;
    if (is_lava) {
        has_water_neighbor = 
            round(get_water(local_x - 1, local_y, local_z).x) == 1.0 ||
            round(get_water(local_x + 1, local_y, local_z).x) == 1.0 ||
            round(get_water(local_x, local_y - 1, local_z).x) == 1.0 ||
            round(get_water(local_x, local_y + 1, local_z).x) == 1.0 ||
            round(get_water(local_x, local_y, local_z - 1).x) == 1.0 ||
            round(get_water(local_x, local_y, local_z + 1).x) == 1.0;
    }
    
    if (is_lava && has_water_neighbor) {
        cell.y = -0.6; // turn to solid!
        cell.x = 7.0;  // Volcanic Obsidian
    } else {
        // Receive falling material
        var incoming_cell = vec4<f32>(0.0);
        var has_incoming = false;
        
        // 1. Check directly above
        let above = get_voxel(local_x, local_y + 1, local_z);
        if (above.y <= solid_thresh && above.x < 0.0) {
            incoming_cell = above;
            has_incoming = true;
        } else {
            // 2. Check left-above (slides into us because its directly-below is solid)
            let la = get_voxel(local_x - 1, local_y + 1, local_z);
            let la_below = get_voxel(local_x - 1, local_y, local_z);
            if (la.y <= solid_thresh && la.x < 0.0 && la_below.y <= solid_thresh) {
                incoming_cell = la;
                has_incoming = true;
            } else {
                // 3. Check right-above (slides into us because its directly-below is solid)
                let ra = get_voxel(local_x + 1, local_y + 1, local_z);
                let ra_below = get_voxel(local_x + 1, local_y, local_z);
                if (ra.y <= solid_thresh && ra.x < 0.0 && ra_below.y <= solid_thresh) {
                    incoming_cell = ra;
                    has_incoming = true;
                } else {
                    // 4. Check back-above (slides into us because its directly-below is solid)
                    let ba = get_voxel(local_x, local_y + 1, local_z - 1);
                    let ba_below = get_voxel(local_x, local_y, local_z - 1);
                    if (ba.y <= solid_thresh && ba.x < 0.0 && ba_below.y <= solid_thresh) {
                        incoming_cell = ba;
                        has_incoming = true;
                    } else {
                        // 5. Check front-above (slides into us because its directly-below is solid)
                        let fa = get_voxel(local_x, local_y + 1, local_z + 1);
                        let fa_below = get_voxel(local_x, local_y, local_z + 1);
                        if (fa.y <= solid_thresh && fa.x < 0.0 && fa_below.y <= solid_thresh) {
                            incoming_cell = fa;
                            has_incoming = true;
                        }
                    }
                }
            }
        }
        
        if (has_incoming) {
            let below = get_voxel(local_x, local_y - 1, local_z);
            if (below.y > solid_thresh && below.x != 1.0) {
                // Keep falling down
                cell.x = incoming_cell.x;
                cell.y = incoming_cell.y;
            } else {
                // Land and solidify!
                cell.x = incoming_cell.x;
                cell.y = abs(incoming_cell.y);
            }
        }
    }
}

if (cell.y <= solid_thresh) {
    let mat = round(abs(cell.x));
    let props = get_material_properties(mat);
    
    // Acid eating walls
    let a_above_val = get_water(local_x, local_y + 1, local_z);
    let a_left_val  = get_water(local_x - 1, local_y, local_z);
    let a_right_val = get_water(local_x + 1, local_y, local_z);
    let a_front_val = get_water(local_x, local_y, local_z - 1);
    let a_back_val  = get_water(local_x, local_y, local_z + 1);
    
    let a_above = select(0.0, a_above_val.y, round(a_above_val.x) == 3.0);
    let a_left  = select(0.0, a_left_val.y,  round(a_left_val.x) == 3.0);
    let a_right = select(0.0, a_right_val.y, round(a_right_val.x) == 3.0);
    let a_front = select(0.0, a_front_val.y, round(a_front_val.x) == 3.0);
    let a_back = select(0.0, a_back_val.y,  round(a_back_val.x) == 3.0);
    
    let acid_vol = max(a_above, max(a_left, max(a_right, max(a_front, a_back))));
    if (acid_vol > 0.05) {
        // Acid corrosion speed scaled by material vulnerability
        let corrosion_speed = 15.0 * (1.0 - props.acid_resist);
        cell.y = cell.y + dt * acid_vol * corrosion_speed;
    }

    // Lava melting walls
    let l_above_val = get_water(local_x, local_y + 1, local_z);
    let l_left_val  = get_water(local_x - 1, local_y, local_z);
    let l_right_val = get_water(local_x + 1, local_y, local_z);
    let l_front_val = get_water(local_x, local_y, local_z - 1);
    let l_back_val  = get_water(local_x, local_y, local_z + 1);
    
    let l_above = select(0.0, l_above_val.y, round(l_above_val.x) == 2.0);
    let l_left  = select(0.0, l_left_val.y,  round(l_left_val.x) == 2.0);
    let l_right = select(0.0, l_right_val.y, round(l_right_val.x) == 2.0);
    let l_front = select(0.0, l_front_val.y, round(l_front_val.x) == 2.0);
    let l_back  = select(0.0, l_back_val.y,  round(l_back_val.x) == 2.0);
    
    let lava_vol = max(l_above, max(l_left, max(l_right, max(l_front, l_back))));
    if (lava_vol > 0.05 && props.melt_speed > 0.0) {
        cell.y = cell.y + dt * lava_vol * props.melt_speed;
    }
}

// Prevent compiler optimization of gas_texture binding
let dummy_gas = get_gas(0, 0, 0);
cell.x = cell.x + dummy_gas.x * 1e-10;

}

{
  let instance = instances[1];

      let to_node = instance.pos_scale.xyz - voxel_pos;
      let dist = length(to_node);
      if (dist < instance.pos_scale.w) {
          let force = (1.0 - (dist / instance.pos_scale.w)) * instance.light_fields.x;
          cell_velocity += normalize(to_node) * force * dt;
      }
    
}
{
  let instance = instances[2];

      let to_node = instance.pos_scale.xyz - voxel_pos;
      let dist = length(to_node);
      if (dist < instance.pos_scale.w) {
          let force = (1.0 - (dist / instance.pos_scale.w)) * instance.light_fields.x;
          cell_velocity += normalize(to_node) * force * dt;
      }
    
}
                  // Apply velocity displacement to Signed Distance Field
                  cell.y += length(cell_velocity) * 0.01 + vec4<f32>(f32((textureDimensions(voxel_texture) + textureDimensions(water_texture) + textureDimensions(gas_texture) + textureDimensions(em_texture) + textureDimensions(gravity_texture) + textureDimensions(voxel_baked_values_texture)).x) * 0.0f).x;
                  output_grid[idx] = cell;
              }