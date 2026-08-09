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
                     return vec4<f32>(1.5, 1.0, 1.0, 1.0);
                 }
                 
                 let mx = u32(local_q.x) >> 2u;
                 let my = u32(local_q.y) >> 2u;
                 let mz = u32(local_q.z) >> 2u;
                 let skip_idx = mx + (my << 3u) + (mz << 6u);
                 let skip_val = chunk_lookup.skip_grid[skip_idx >> 2u][skip_idx & 3];
                 if (skip_val == 0) {
                     return vec4<f32>(1.5, 1.0, 1.0, 1.0);
                 }
                 
                 let idx = local_q.x + local_q.y * 32 + local_q.z * 1024;
                 let slot = chunk_lookup.slots[u32(idx) >> 2u][idx & 3];
                 if (slot < 0) {
                     return vec4<f32>(1.5, 1.0, 1.0, 1.0);
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
                
                var water = input_fields[idx];
                let voxel_pos = chunk_info.origin_slot.xyz + vec3<f32>(f32(local_x), f32(local_y), f32(local_z)) * 1;
                 let dt = 0.00833 * get_gravity(local_x, local_y, local_z).w;
                 let dummy_use = u.time * 0.0;
                 water.x += dummy_use;
                 // --- DYNAMIC INJECTIONS LOOP ---
{
// === Injected from water_rule.wgsl ===
// water_rule.wgsl - Native GPU-Resident JIT Water cellular automata & fluid loop.
// Layout: water is vec4<f32>(Liquid_ID, Volume, Age, Sleep)

let solid_thresh = u.terrain_params3.z;
let self_voxel = get_voxel(local_x, local_y, local_z);

// If the voxel is solid (SDF <= threshold), it cannot contain liquid
if (self_voxel.y <= solid_thresh) {
    water = vec4<f32>(0.0);
} else {
    // Early-out Sleep state check
    let self_sleep = water.w;
    var neighbors_all_sleeping = true;
    if (self_sleep > 0.9) {
        let active_neighbor = 
            get_fluid(local_x - 1, local_y, local_z).w < 0.9 ||
            get_fluid(local_x + 1, local_y, local_z).w < 0.9 ||
            get_fluid(local_x, local_y - 1, local_z).w < 0.9 ||
            get_fluid(local_x, local_y + 1, local_z).w < 0.9 ||
            get_fluid(local_x, local_y, local_z - 1).w < 0.9 ||
            get_fluid(local_x, local_y, local_z + 1).w < 0.9;
        
        if (!active_neighbor) {
            return;
        }
    }

    let baked_vals = get_baked_values(local_x, local_y, local_z);
    let slope = vec2<f32>(baked_vals.z, baked_vals.w) * 2.0 - 1.0;
    let slope_bias_x = -slope.x * 0.15;
    let slope_bias_z = -slope.y * 0.15;

    // Check voxel solidity for neighbors (SDF <= threshold is solid)
    let sol_below  = get_voxel(local_x, local_y - 1, local_z).y <= solid_thresh;
    let sol_above  = get_voxel(local_x, local_y + 1, local_z).y <= solid_thresh;
    let sol_left   = get_voxel(local_x - 1, local_y, local_z).y <= solid_thresh;
    let sol_right  = get_voxel(local_x + 1, local_y, local_z).y <= solid_thresh;
    let sol_back   = get_voxel(local_x, local_y, local_z - 1).y <= solid_thresh;
    let sol_front  = get_voxel(local_x, local_y, local_z + 1).y <= solid_thresh;

    // Fetch neighbor liquids
    let w_below_v = get_fluid(local_x, local_y - 1, local_z);
    let w_above_v = get_fluid(local_x, local_y + 1, local_z);
    let w_left_v  = get_fluid(local_x - 1, local_y, local_z);
    let w_right_v = get_fluid(local_x + 1, local_y, local_z);
    let w_back_v  = get_fluid(local_x, local_y, local_z - 1);
    let w_front_v = get_fluid(local_x, local_y, local_z + 1);

    var self_id = round(water.x);
    var self_vol = water.y;
    var self_age = water.z;

    var next_id = self_id;
    var next_vol = self_vol;
    var next_age = self_age;

    // Resolve flow speed and weight properties for self
    var self_flow_speed = 0.0;
    var self_weight = 0.0;
    var self_evap_rate = 0.0;
    if (self_id == 1.0) { // Water
        self_flow_speed = 1.0;
        self_weight = 1.0;
        self_evap_rate = 0.02;
    } else if (self_id == 2.0) { // Lava
        self_flow_speed = 0.08;
        self_weight = 2.0;
        self_evap_rate = 0.0;
    } else if (self_id == 3.0) { // Acid
        self_flow_speed = 0.65;
        self_weight = 1.2;
        self_evap_rate = 0.01;
    } else if (self_id == 4.0) { // Oil
        self_flow_speed = 0.35;
        self_weight = 0.8;
        self_evap_rate = 0.015;
    }

    let global_flow_speed = u.misc_params.y * dt;

    // --- 1. Downward Advection Flow ---
    if (self_id > 0.0 && self_vol > 0.005) {
        if (!sol_below) {
            let below_id = round(w_below_v.x);
            let below_vol = w_below_v.y;
            if (below_id == 0.0 || below_id == self_id) {
                let flow_down = min(next_vol, (1.0 - below_vol) * global_flow_speed * self_flow_speed);
                next_vol -= flow_down;
            }
        }
    } else {
        // We are empty, check if above is falling into us
        let above_id = round(w_above_v.x);
        if (above_id > 0.0 && w_above_v.y > 0.005 && !sol_above) {
            var above_flow_speed = 1.0;
            if (above_id == 2.0) { above_flow_speed = 0.08; }
            else if (above_id == 3.0) { above_flow_speed = 0.65; }
            else if (above_id == 4.0) { above_flow_speed = 0.35; }
            
            let flow_in = min(w_above_v.y, (1.0 - next_vol) * global_flow_speed * above_flow_speed);
            next_vol += flow_in;
            next_id = above_id;
            next_age = w_above_v.z;
        }
    }

    // --- 2. Displacement Swap ---
    // If the fluid above is heavier than us, swap places
    if (next_id > 0.0 && next_vol > 0.01) {
        let above_id = round(w_above_v.x);
        var above_weight = 0.0;
        if (above_id == 1.0) { above_weight = 1.0; }
        else if (above_id == 2.0) { above_weight = 2.0; }
        else if (above_id == 3.0) { above_weight = 1.2; }
        else if (above_id == 4.0) { above_weight = 0.8; }
        
        if (above_id > 0.0 && w_above_v.y > 0.01 && above_weight > self_weight) {
            next_id = above_id;
            next_vol = w_above_v.y;
            next_age = w_above_v.z;
        } else {
            // Swap with below if below is lighter
            let below_id = round(w_below_v.x);
            var below_weight = 0.0;
            if (below_id == 1.0) { below_weight = 1.0; }
            else if (below_id == 2.0) { below_weight = 2.0; }
            else if (below_id == 3.0) { below_weight = 1.2; }
            else if (below_id == 4.0) { below_weight = 0.8; }
            
            if (below_id > 0.0 && w_below_v.y > 0.01 && below_weight < self_weight) {
                next_id = below_id;
                next_vol = w_below_v.y;
                next_age = w_below_v.z;
            }
        }
    }

    // --- 3. Lateral Spreading Flow ---
    if (next_id > 0.0 && next_vol > 0.005) {
        let spread_rate = 0.15 * global_flow_speed * self_flow_speed;
        
        // Spread Left
        if (!sol_left) {
            let left_id = round(w_left_v.x);
            let left_vol = w_left_v.y;
            if (left_id == 0.0 || left_id == next_id) {
                let flow_lat = max(0.0, (next_vol - left_vol) * spread_rate + slope_bias_x * next_vol);
                next_vol -= flow_lat;
            }
        }
        // Spread Right
        if (!sol_right) {
            let right_id = round(w_right_v.x);
            let right_vol = w_right_v.y;
            if (right_id == 0.0 || right_id == next_id) {
                let flow_lat = max(0.0, (next_vol - right_vol) * spread_rate - slope_bias_x * next_vol);
                next_vol -= flow_lat;
            }
        }
        // Spread Back
        if (!sol_back) {
            let back_id = round(w_back_v.x);
            let back_vol = w_back_v.y;
            if (back_id == 0.0 || back_id == next_id) {
                let flow_lat = max(0.0, (next_vol - back_vol) * spread_rate + slope_bias_z * next_vol);
                next_vol -= flow_lat;
            }
        }
        // Spread Front
        if (!sol_front) {
            let front_id = round(w_front_v.x);
            let front_vol = w_front_v.y;
            if (front_id == 0.0 || front_id == next_id) {
                let flow_lat = max(0.0, (next_vol - front_vol) * spread_rate - slope_bias_z * next_vol);
                next_vol -= flow_lat;
            }
        }
    } else {
        // We are empty, check if neighbors are spreading into us
        let spread_rate = 0.15 * global_flow_speed;
        
        var max_incoming = 0.0;
        var incoming_id = 0.0;
        var incoming_age = 0.0;
        
        // Left
        let left_id = round(w_left_v.x);
        if (left_id > 0.0 && w_left_v.y > max_incoming && !sol_left) {
            max_incoming = w_left_v.y;
            incoming_id = left_id;
            incoming_age = w_left_v.z;
        }
        // Right
        let right_id = round(w_right_v.x);
        if (right_id > 0.0 && w_right_v.y > max_incoming && !sol_right) {
            max_incoming = w_right_v.y;
            incoming_id = right_id;
            incoming_age = w_right_v.z;
        }
        // Back
        let back_id = round(w_back_v.x);
        if (back_id > 0.0 && w_back_v.y > max_incoming && !sol_back) {
            max_incoming = w_back_v.y;
            incoming_id = back_id;
            incoming_age = w_back_v.z;
        }
        // Front
        let front_id = round(w_front_v.x);
        if (front_id > 0.0 && w_front_v.y > max_incoming && !sol_front) {
            max_incoming = w_front_v.y;
            incoming_id = front_id;
            incoming_age = w_front_v.z;
        }
        
        if (max_incoming > 0.01) {
            let flow_in = max_incoming * spread_rate;
            next_vol += flow_in;
            next_id = incoming_id;
            next_age = incoming_age;
        }
    }

    // --- 4. Evaporation & Local Heat Reactions ---
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

    let evap_mult = select(0.002, 1.0 + (local_temp - 20.0) * 0.18, local_temp > 20.0);
    let final_evap = u.misc_params.w * evap_mult * 3.5;

    // Apply Evaporation based on ID
    if (next_id > 0.0 && next_vol > 0.005) {
        var local_evap_rate = self_evap_rate;
        if (next_id == 4.0 && local_temp > 60.0) { local_evap_rate = local_evap_rate * 5.0; }
        
        let evap_scale = select(1.0, 0.02, !sol_below);
        let evaporated = min(next_vol, final_evap * dt * 50.0 * local_evap_rate * evap_scale);
        next_vol -= evaporated;
    }

    // --- 5. Contact Reactions ---
    // 1. Water vs Lava contact at boundaries
    if (next_id == 1.0) { // Water
        let touches_lava = 
            round(w_below_v.x) == 2.0 || round(w_above_v.x) == 2.0 ||
            round(w_left_v.x) == 2.0 || round(w_right_v.x) == 2.0 ||
            round(w_back_v.x) == 2.0 || round(w_front_v.x) == 2.0;
        if (touches_lava) {
            next_vol = max(0.0, next_vol - 0.85 * dt);
        }
    }
    if (next_id == 2.0) { // Lava
        let touches_water = 
            round(w_below_v.x) == 1.0 || round(w_above_v.x) == 1.0 ||
            round(w_left_v.x) == 1.0 || round(w_right_v.x) == 1.0 ||
            round(w_back_v.x) == 1.0 || round(w_front_v.x) == 1.0;
        if (touches_water) {
            next_vol = max(0.0, next_vol - 0.85 * dt);
        }
    }
    // 2. Oil vs fire/lava combustion
    if (next_id == 4.0) { // Oil
        let combusts = 
            round(w_below_v.x) == 2.0 || round(w_above_v.x) == 2.0 ||
            round(w_left_v.x) == 2.0 || round(w_right_v.x) == 2.0 ||
            round(w_back_v.x) == 2.0 || round(w_front_v.x) == 2.0 ||
            local_temp > 120.0;
        if (combusts) {
            next_vol = max(0.0, next_vol - 0.10 * dt);
        }
    }
    // 3. Acid eating solid walls
    if (next_id == 3.0) { // Acid
        let adjacent_to_solid = sol_left || sol_right || sol_back || sol_front || sol_below;
        if (adjacent_to_solid) {
            next_vol = max(0.0, next_vol - 2.20 * dt);
        }
    }

    // --- 6. Ceiling Condensation & mid-air rain ---
    // Gas phase condensation adds to water/acid
    let gas_here = get_gas(local_x, local_y, local_z);
    let gas_id = round(gas_here.x);
    let gas_vol = gas_here.y;
    
    let steam_here = select(0.0, gas_vol, gas_id == 1.0);
    let acid_fog_here = select(0.0, gas_vol, gas_id == 3.0);
    
    var near_ceiling = false;
    var cold_ceiling = false;
    for (var dy = 1; dy <= 7; dy = dy + 1) {
        let ceiling_v = get_voxel(local_x, local_y + dy, local_z);
        if (ceiling_v.y <= solid_thresh) {
            near_ceiling = true;
            let ceil_mat = round(abs(ceiling_v.x));
            if (ceil_mat == 6.0) {
                cold_ceiling = true;
            }
            break;
        }
    }
    
    let is_cold = cold_ceiling || (local_temp < 10.0);
    var total_condensed = 0.0;
    
    if (near_ceiling && steam_here >= 0.02) {
        let rate_mult = select(1.0, 2.5, is_cold);
        let ceiling_condensation_rate = 0.10 * u.shadow_ao_quality.w * dt * rate_mult;
        total_condensed = total_condensed + min(steam_here, ceiling_condensation_rate);
    }
    
    let rain_threshold = u.grid_dims.w;
    var rain_condensed = 0.0;
    if (steam_here > rain_threshold) {
        let rain_rate = 3.0 * (1.5 * u.shadow_ao_quality.w + 20.0) * dt * (steam_here - rain_threshold);
        rain_condensed = min(steam_here, rain_rate);
    }
    
    let combined_condensed = total_condensed + rain_condensed;
    if (combined_condensed > 0.0) {
        if (next_id == 0.0 || next_id == 1.0) {
            next_id = 1.0;
            next_vol = next_vol + combined_condensed * 1.5;
        }
    }
    
    if (near_ceiling && acid_fog_here >= 0.02) {
        let rate_mult = select(1.0, 2.5, is_cold);
        let acid_condensation_rate = 0.008 * u.shadow_ao_quality.w * dt * rate_mult;
        let acid_condensed = min(acid_fog_here, acid_condensation_rate);
        if (acid_condensed > 0.0) {
            if (next_id == 0.0 || next_id == 3.0) {
                next_id = 3.0;
                next_vol = next_vol + acid_condensed * 0.40;
            }
        }
    }

    if (next_vol <= 0.005) {
        next_id = 0.0;
        next_vol = 0.0;
        next_age = 0.0;
    }

    // Tick Age
    if (next_id > 0.0) {
        next_age = next_age + dt;
    }

    // Resolve sleep state (if volume change is microscopic, put to sleep!)
    var next_sleep = 0.0;
    if (abs(next_vol - self_vol) < 0.0001) {
        next_sleep = 1.0;
    }

    water = vec4<f32>(next_id, clamp(next_vol, 0.0, 1.0), next_age, next_sleep);
}

}

                output_fields[idx] = water + vec4<f32>(f32((textureDimensions(voxel_texture) + textureDimensions(water_texture) + textureDimensions(gas_texture) + textureDimensions(em_texture) + textureDimensions(gravity_texture) + textureDimensions(voxel_baked_values_texture)).x) * 0.0f);
            }