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
                    return get_gas(x, y, z);
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
                
                var gas = input_fields[idx];
                let voxel_pos = chunk_info.origin_slot.xyz + vec3<f32>(f32(local_x), f32(local_y), f32(local_z)) * 1;
                 let dt = 0.00833 * get_gravity(local_x, local_y, local_z).w;
                 let dummy_use = u.time * 0.0;
                 gas.x += dummy_use;
                 // --- DYNAMIC INJECTIONS LOOP ---
{
// === Injected from gas_rule.wgsl ===
// gas_rule.wgsl - Native GPU-Resident JIT Gas cellular automata & atmospheric loop.
// Layout: gas is vec4<f32>(Gas_ID, Volume, Age, Sleep)

let self_voxel = get_voxel(local_x, local_y, local_z);

// If the voxel is solid (Material ID >= 0.9), it cannot contain gas
if (self_voxel.x >= 0.9) {
    gas = vec4<f32>(0.0);
} else {
    // Early-out Sleep state check
    let self_sleep = gas.w;
    var should_simulate = true;
    if (self_sleep > 0.9) {
        let active_neighbor = 
            get_fluid(local_x - 1, local_y, local_z).w < 0.9 ||
            get_fluid(local_x + 1, local_y, local_z).w < 0.9 ||
            get_fluid(local_x, local_y - 1, local_z).w < 0.9 ||
            get_fluid(local_x, local_y + 1, local_z).w < 0.9 ||
            get_fluid(local_x, local_y, local_z - 1).w < 0.9 ||
            get_fluid(local_x, local_y, local_z + 1).w < 0.9;
        
        if (!active_neighbor) {
            should_simulate = false;
        }
    }

    let baked_vals = get_baked_values(local_x, local_y, local_z);
    let slope = baked_vals.zw;
    let gas_bias_x = -slope.x * 0.15;
    let gas_bias_z = -slope.y * 0.15;

    // Check voxel solidity for neighbors (Material ID >= 0.9 is solid)
    let sol_below = get_voxel(local_x, local_y - 1, local_z).x >= 0.9;
    let sol_above = get_voxel(local_x, local_y + 1, local_z).x >= 0.9;
    let sol_left  = get_voxel(local_x - 1, local_y, local_z).x >= 0.9;
    let sol_right = get_voxel(local_x + 1, local_y, local_z).x >= 0.9;
    let sol_back  = get_voxel(local_x, local_y, local_z - 1).x >= 0.9;
    let sol_front = get_voxel(local_x, local_y, local_z + 1).x >= 0.9;

    let flow_speed = u.misc_params.y * dt * 45.0;

    // Fetch neighbor gases
    let g_below_v = get_fluid(local_x, local_y - 1, local_z);
    let g_above_v = get_fluid(local_x, local_y + 1, local_z);
    let g_left_v  = get_fluid(local_x - 1, local_y, local_z);
    let g_right_v = get_fluid(local_x + 1, local_y, local_z);
    let g_back_v  = get_fluid(local_x, local_y, local_z - 1);
    let g_front_v = get_fluid(local_x, local_y, local_z + 1);

    var self_id = round(gas.x);
    var self_vol = gas.y;
    var self_age = gas.z;

    var next_id = self_id;
    var next_vol = self_vol;
    var next_age = self_age;
    var next_sleep = self_sleep;

    if (should_simulate) {
        // --- Heat calculations ---
        var local_temp = 0.0;
        var total_weight = 0.0;
        let max_instances = u32(round(u.suns[0].params.y));
        for (var i = 0u; i < max_instances; i = i + 1u) {
            let inst = instances[i];
            let radius = inst.pos_scale.w;
            if (radius <= 0.0) { continue; }
            
            let dist = length(voxel_pos - inst.pos_scale.xyz);
            if (dist < radius) {
                let weight = 1.0 - (dist / radius);
                local_temp = local_temp + select(0.0, inst.interaction_fields.x, inst.interaction_fields.x > -999.0) * weight;
                total_weight = total_weight + weight;
            }
        }
        if (total_weight > 0.0) {
            local_temp = local_temp / total_weight;
        }

        // Resolve flow speed parameters based on ID
        // 1.0 = Steam (high rise, low spread)
        // 2.0 = Smoke (low rise, high spread)
        // 3.0 = Acid Fog (medium rise, medium spread)
        // 4.0 = Methane (very high rise, high spread)
        var self_rise_speed = 0.0;
        var self_spread = 0.0;
        if (self_id == 1.0) {
            self_rise_speed = 0.65 + min(0.45, max(0.0, local_temp - 20.0) * 0.007);
            self_spread = 0.02;
        } else if (self_id == 2.0) {
            self_rise_speed = 0.15;
            self_spread = 0.18;
        } else if (self_id == 3.0) {
            self_rise_speed = 0.20;
            self_spread = 0.10;
        } else if (self_id == 4.0) {
            self_rise_speed = 0.85;
            self_spread = 0.15;
        }

        // --- 1. Gas Rising (Vertical Flow) ---
        if (self_id > 0.0 && self_vol > 0.005) {
            if (!sol_above) {
                let above_id = round(g_above_v.x);
                let above_vol = g_above_v.y;
                if (above_id == 0.0 || above_id == self_id) {
                    let flow_up = min(next_vol, (1.0 - above_vol) * flow_speed * self_rise_speed);
                    next_vol -= flow_up;
                }
            }
        } else {
            // We are empty, check if gas below us wants to rise into us
            let below_id = round(g_below_v.x);
            if (below_id > 0.0 && g_below_v.y > 0.005 && !sol_below) {
                var below_rise = 0.15;
                if (below_id == 1.0) { below_rise = 0.65 + min(0.45, max(0.0, local_temp - 20.0) * 0.007); }
                else if (below_id == 3.0) { below_rise = 0.20; }
                else if (below_id == 4.0) { below_rise = 0.85; }
                
                let flow_in = min(g_below_v.y, (1.0 - next_vol) * flow_speed * below_rise);
                next_vol += flow_in;
                next_id = below_id;
                next_age = g_below_v.z;
            }
        }

        // --- 2. Horizontal Spreading Flow ---
        if (next_id > 0.0 && next_vol > 0.005) {
            let spread_rate = self_spread * flow_speed;
            
            // Left
            if (!sol_left) {
                let left_id = round(g_left_v.x);
                let left_vol = g_left_v.y;
                if (left_id == 0.0 || left_id == next_id) {
                    let flow_lat = max(0.0, (next_vol - left_vol) * spread_rate - gas_bias_x * next_vol);
                    next_vol -= flow_lat;
                }
            }
            // Right
            if (!sol_right) {
                let right_id = round(g_right_v.x);
                let right_vol = g_right_v.y;
                if (right_id == 0.0 || right_id == next_id) {
                    let flow_lat = max(0.0, (next_vol - right_vol) * spread_rate + gas_bias_x * next_vol);
                    next_vol -= flow_lat;
                }
            }
            // Back
            if (!sol_back) {
                let back_id = round(g_back_v.x);
                let back_vol = g_back_v.y;
                if (back_id == 0.0 || back_id == next_id) {
                    let flow_lat = max(0.0, (next_vol - back_vol) * spread_rate - gas_bias_z * next_vol);
                    next_vol -= flow_lat;
                }
            }
            // Front
            if (!sol_front) {
                let front_id = round(g_front_v.x);
                let front_vol = g_front_v.y;
                if (front_id == 0.0 || front_id == next_id) {
                    let flow_lat = max(0.0, (next_vol - front_vol) * spread_rate + gas_bias_z * next_vol);
                    next_vol -= flow_lat;
                }
            }
        } else {
            // We are empty, check if neighbors are spreading into us
            var max_incoming = 0.0;
            var incoming_id = 0.0;
            var incoming_age = 0.0;
            
            // Left
            let left_id = round(g_left_v.x);
            if (left_id > 0.0 && g_left_v.y > max_incoming && !sol_left) {
                max_incoming = g_left_v.y;
                incoming_id = left_id;
                incoming_age = g_left_v.z;
            }
            // Right
            let right_id = round(g_right_v.x);
            if (right_id > 0.0 && g_right_v.y > max_incoming && !sol_right) {
                max_incoming = g_right_v.y;
                incoming_id = right_id;
                incoming_age = g_right_v.z;
            }
            // Back
            let back_id = round(g_back_v.x);
            if (back_id > 0.0 && g_back_v.y > max_incoming && !sol_back) {
                max_incoming = g_back_v.y;
                incoming_id = back_id;
                incoming_age = g_back_v.z;
            }
            // Front
            let front_id = round(g_front_v.x);
            if (front_id > 0.0 && g_front_v.y > max_incoming && !sol_front) {
                max_incoming = g_front_v.y;
                incoming_id = front_id;
                incoming_age = g_front_v.z;
            }
            
            if (max_incoming > 0.01) {
                var incoming_spread = 0.10;
                if (incoming_id == 2.0) { incoming_spread = 0.18; }
                else if (incoming_id == 4.0) { incoming_spread = 0.15; }
                
                let flow_in = max_incoming * incoming_spread * flow_speed;
                next_vol += flow_in;
                next_id = incoming_id;
                next_age = incoming_age;
            }
        }

        // --- 3. Mass Transfer from Liquid Phase ---
        let water_here = get_water(local_x, local_y, local_z);
        let liq_id = round(water_here.x);
        let liq_vol = water_here.y;

        let evap_mult = select(0.002, 1.0 + (local_temp - 20.0) * 0.18, local_temp > 20.0);
        let final_evap = u.misc_params.w * evap_mult * 3.5;

        // Steam generation from water evaporation
        if (liq_id == 1.0 && liq_vol > 0.005) {
            let dryness = max(0.0, 1.0 - select(0.0, next_vol, next_id == 1.0));
            let evap_scale = select(1.0, 0.02, !sol_below);
            let evaporated_water = select(min(liq_vol, 3.0 * final_evap * dt * 50.0 * dryness * evap_scale), 0.0, sol_above); // use sol_above as ceiling check
            
            let em_val_here = get_em(local_x, local_y, local_z);
            let potential_here = em_val_here.w;
            var zapped_steam = 0.0;
            if (abs(potential_here) > 0.1) {
                zapped_steam = min(liq_vol, abs(potential_here) * 1.5 * dt);
            }
            
            let spawned_steam = (evaporated_water + zapped_steam) * u.terrain_params3.w;
            if (spawned_steam > 0.0) {
                if (next_id == 0.0 || next_id == 1.0) {
                    next_id = 1.0;
                    next_vol += spawned_steam;
                }
            }
        }

        // Methane generation from Oil evaporation
        if (liq_id == 4.0 && liq_vol > 0.005) {
            let evaporated_oil = min(liq_vol, final_evap * dt * 15.0 * select(1.0, 5.0, local_temp > 60.0));
            let spawned_methane = evaporated_oil * 2.0;
            if (spawned_methane > 0.0) {
                if (next_id == 0.0 || next_id == 4.0) {
                    next_id = 4.0;
                    next_vol += spawned_methane;
                }
            }
        }

        // Steam generation from Water/Lava reaction
        let touches_water_lava_reaction = 
            (liq_id == 1.0 && (round(get_water(local_x - 1, local_y, local_z).x) == 2.0 || round(get_water(local_x + 1, local_y, local_z).x) == 2.0 || round(get_water(local_x, local_y - 1, local_z).x) == 2.0 || round(get_water(local_x, local_y + 1, local_z).x) == 2.0)) ||
            (liq_id == 2.0 && (round(get_water(local_x - 1, local_y, local_z).x) == 1.0 || round(get_water(local_x + 1, local_y, local_z).x) == 1.0 || round(get_water(local_x, local_y - 1, local_z).x) == 1.0 || round(get_water(local_x, local_y + 1, local_z).x) == 1.0));
        
        if (touches_water_lava_reaction) {
            let react = 0.5 * dt;
            let spawned_steam = react * u.terrain_params3.w * 2.0;
            if (next_id == 0.0 || next_id == 1.0) {
                next_id = 1.0;
                next_vol += spawned_steam;
            }
        }

        // Acid Fog generation from Acid eating solid walls
        let adjacent_to_solid = sol_left || sol_right || sol_back || sol_front || sol_below;
        if (adjacent_to_solid && liq_id == 3.0 && liq_vol > 0.005) {
            let consumed_acid = min(liq_vol, 2.20 * dt);
            let spawned_fog = consumed_acid * 0.15;
            if (next_id == 0.0 || next_id == 3.0) {
                next_id = 3.0;
                next_vol += spawned_fog;
            }
        }

        // --- 4. Ceiling & Rain Condensation (Removes gas) ---
        var near_ceiling = false;
        var cold_ceiling = false;
        for (var dy = 1; dy <= 7; dy = dy + 1) {
            let ceiling_v = get_voxel(local_x, local_y + dy, local_z);
            if (ceiling_v.x >= 0.9) {
                near_ceiling = true;
                let ceil_mat = round(abs(ceiling_v.x));
                if (ceil_mat == 6.0) {
                    cold_ceiling = true;
                }
                break;
            }
        }

        var local_pressure = 0.0;
        {
            let max_inst = u32(round(u.suns[0].params.y));
            for (var i = 0u; i < max_inst; i = i + 1u) {
                let inst = instances[i];
                let radius = inst.pos_scale.w;
                if (radius <= 0.0) { continue; }
                let dist = length(voxel_pos - inst.pos_scale.xyz);
                if (dist < radius) {
                    let weight = 1.0 - (dist / radius);
                    local_pressure = local_pressure + inst.interaction_fields.z * weight;
                }
            }
        }

        let is_cold = cold_ceiling || (local_temp < 10.0);
        
        // Condensation removal for Steam (1)
        if (next_id == 1.0 && next_vol > 0.005) {
            var total_condensed = 0.0;
            if (near_ceiling) {
                let rate_mult = select(1.0, 2.5, is_cold);
                let condensation_rate = 0.10 * u.shadow_ao_quality.w * dt * rate_mult;
                total_condensed += min(next_vol, condensation_rate);
            }
            if (local_pressure > 5.0) {
                let pressure_condensation_rate = 1.5 * dt * local_pressure;
                total_condensed += min(next_vol - total_condensed, pressure_condensation_rate);
            }
            
            let rain_threshold = u.grid_dims.w;
            var rain_condensed = 0.0;
            if (next_vol > rain_threshold) {
                let rain_rate = 3.0 * (1.5 * u.shadow_ao_quality.w + 20.0) * dt * (next_vol - rain_threshold);
                rain_condensed = min(next_vol, rain_rate);
            }
            
            next_vol = max(0.0, next_vol - total_condensed - rain_condensed);
        }
        
        // Condensation removal for Acid Fog (3)
        if (next_id == 3.0 && next_vol > 0.005) {
            var acid_condensed = 0.0;
            if (near_ceiling) {
                let rate_mult = select(1.0, 2.5, is_cold);
                let condensation_rate = 0.008 * u.shadow_ao_quality.w * dt * rate_mult;
                acid_condensed = min(next_vol, condensation_rate);
            }
            next_vol = max(0.0, next_vol - acid_condensed);
        }

        // --- 5. Fuel & Atmospheric Combustion ---
        let em_val = get_em(local_x, local_y, local_z);
        let potential = em_val.w;
        let has_combustion_source = liq_id == 2.0 || local_temp > 120.0 || abs(potential) > 0.15;
        
        // Burning Methane (4.0) turns into Smoke (2.0)
        var burned_methane = 0.0;
        if (next_id == 4.0 && next_vol > 0.0 && has_combustion_source) {
            burned_methane = min(next_vol, 2.5 * dt);
            next_vol -= burned_methane;
            
            // Generate Smoke
            if (next_vol <= 0.005) {
                next_id = 2.0;
                next_vol = burned_methane * 1.3;
            }
        }

        // Oil burning also spawns smoke
        var burned_oil = 0.0;
        if (has_combustion_source && liq_id == 4.0 && liq_vol > 0.0) {
            burned_oil = min(liq_vol, 0.10 * dt);
        }
        if (burned_oil > 0.0) {
            if (next_id == 0.0 || next_id == 2.0) {
                next_id = 2.0;
                next_vol += burned_oil * 1.1;
            }
        }

        // --- 6. Decay/Dispersal & Boundaries ---
        let decay_rate = select(0.012 * dt, 0.001 * dt, near_ceiling);
        if (next_id > 0.0) {
            var factor = 1.0;
            if (next_id == 2.0) { factor = 0.70; }
            else if (next_id == 3.0) { factor = 0.50; }
            else if (next_id == 4.0) { factor = 0.20; }
            next_vol = max(0.0, next_vol - decay_rate * factor);
        }

        // Boundary deletion
        let above_voxel_check = get_voxel(local_x, local_y + 1, local_z);
        if (above_voxel_check.x == 1.0) {
            next_vol = 0.0;
        }

        if (next_vol <= 0.005) {
            next_id = 0.0;
            next_vol = 0.0;
            next_age = 0.0;
        } else {
            next_age = next_age + dt;
        }

        // Sleep state check
        if (abs(next_vol - self_vol) < 0.0001) {
            next_sleep = 1.0;
        } else {
            next_sleep = 0.0;
        }
    }

    // Prevent compiler optimization of gas_texture binding
    let dummy_gas = get_gas(0, 0, 0);
    gas = vec4<f32>(next_id, clamp(next_vol, 0.0, 1.0) + dummy_gas.x * 1e-10, next_age, next_sleep);
}

}

                output_fields[idx] = gas + vec4<f32>(f32((textureDimensions(voxel_texture) + textureDimensions(water_texture) + textureDimensions(gas_texture) + textureDimensions(em_texture) + textureDimensions(gravity_texture) + textureDimensions(voxel_baked_values_texture)).x) * 0.0f);
            }