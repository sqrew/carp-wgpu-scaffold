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
                
                var gas = input_fields[idx];
                let voxel_pos = chunk_info.origin_slot.xyz + vec3<f32>(f32(local_x), f32(local_y), f32(local_z)) * 1;
                 let dt = 0.00833 * get_gravity(local_x, local_y, local_z).w;
                 let dummy_use = u.time * 0.0;
                 gas.x += dummy_use;
                 // --- DYNAMIC INJECTIONS LOOP ---
{
// === Injected from gas_rule.wgsl ===
// gas_rule.wgsl - Native GPU-Resident JIT Gas cellular automata & atmospheric loop.
//
// Input/Output variable is:
//   var gas: vec4<f32>; // (x: Steam, y: Volcanic Smoke, z: Acid Fog, w: Methane)
//
// Injected code here executes per-voxel. Use `gas` to modify gas simulation state.
//

let self_voxel = get_voxel(local_x, local_y, local_z);

// If the voxel is solid (SDF <= threshold), it cannot contain gas
let solid_thresh = u.terrain_params3.z;
if (self_voxel.x <= solid_thresh) {
    gas = vec4<f32>(0.0);
} else {
    let baked_vals = get_baked_values(local_x, local_y, local_z);
    let slope = baked_vals.zw;
    let gas_bias_x = -slope.x * 0.15;
    let gas_bias_z = -slope.y * 0.15;

    // --- Lightning Potential Shockwave Push ---
    let pot_self  = abs(get_em(local_x, local_y, local_z).w);
    let pot_left  = abs(get_em(local_x - 1, local_y, local_z).w);
    let pot_right = abs(get_em(local_x + 1, local_y, local_z).w);
    let pot_below = abs(get_em(local_x, local_y - 1, local_z).w);
    let pot_above = abs(get_em(local_x, local_y + 1, local_z).w);
    let pot_front = abs(get_em(local_x, local_y, local_z - 1).w);
    let pot_back  = abs(get_em(local_x, local_y, local_z + 1).w);
    
    let fx = pot_left - pot_right;
    let fy = pot_below - pot_above;
    let fz = pot_front - pot_back;
    
    let force_mag = sqrt(fx*fx + fy*fy + fz*fz);
    if (force_mag > 0.05) {
        let dx = fx / force_mag;
        let dy = fy / force_mag;
        let dz = fz / force_mag;
        
        let sx = local_x - i32(round(dx));
        let sy = local_y - i32(round(dy));
        let sz = local_z - i32(round(dz));
        
        let push_speed = clamp(force_mag * 18.0 * dt, 0.0, 0.95);
        let upstream_fluid = get_fluid(sx, sy, sz);
        
        gas.x = mix(gas.x, upstream_fluid.x, push_speed);
        gas.y = mix(gas.y, upstream_fluid.y, push_speed);
        gas.z = mix(gas.z, upstream_fluid.z, push_speed);
        gas.w = mix(gas.w, upstream_fluid.w, push_speed);
    }

    var near_ceiling = false;
    var cold_ceiling = false;
    for (var dy = 1; dy <= 7; dy = dy + 1) {
        let ceiling_v = get_voxel(local_x, local_y + dy, local_z);
        if (ceiling_v.x <= solid_thresh) {
            near_ceiling = true;
            let ceil_mat = round(abs(ceiling_v.y));
            if (ceil_mat == 6.0) {
                cold_ceiling = true;
            }
            break;
        }
    }

    var g_below_v = vec4<f32>(0.0);
    var g_above_v = vec4<f32>(0.0);
    var g_left_v  = vec4<f32>(0.0);
    var g_right_v = vec4<f32>(0.0);
    var g_back_v  = vec4<f32>(0.0);
    var g_front_v = vec4<f32>(0.0);

    let self_idx = u32(local_x + local_y * 32 + local_z * 1024);
    if (local_x > 0 && local_x < 31 && local_y > 0 && local_y < 31 && local_z > 0 && local_z < 31) {
        g_below_v = input_fields[self_idx - 32u];
        g_above_v = input_fields[self_idx + 32u];
        g_left_v  = input_fields[self_idx - 1u];
        g_right_v = input_fields[self_idx + 1u];
        g_back_v  = input_fields[self_idx - 1024u];
        g_front_v = input_fields[self_idx + 1024u];
    } else {
        g_below_v = get_fluid(local_x, local_y - 1, local_z);
        g_above_v = get_fluid(local_x, local_y + 1, local_z);
        g_left_v  = get_fluid(local_x - 1, local_y, local_z);
        g_right_v = get_fluid(local_x + 1, local_y, local_z);
        g_back_v  = get_fluid(local_x, local_y, local_z - 1);
        g_front_v = get_fluid(local_x, local_y, local_z + 1);
    }

    // Check voxel solidity for neighbors (SDF <= threshold is solid)
    let sol_below = get_voxel(local_x, local_y - 1, local_z).x <= solid_thresh;
    let sol_above = get_voxel(local_x, local_y + 1, local_z).x <= solid_thresh;
    let sol_left  = get_voxel(local_x - 1, local_y, local_z).x <= solid_thresh;
    let sol_right = get_voxel(local_x + 1, local_y, local_z).x <= solid_thresh;
    let sol_back  = get_voxel(local_x, local_y, local_z - 1).x <= solid_thresh;
    let sol_front = get_voxel(local_x, local_y, local_z + 1).x <= solid_thresh;

    let flow_speed = u.misc_params.y;

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

    // --- 1. Steam Rising & Spreading (gas.x) ---
    var new_steam = gas.x;
    // Strongly biased vertical rise speed (baseline increased to 0.65 for concentrated columns)
    let steam_rise_speed = (0.65 + min(0.45, max(0.0, local_temp - 20.0) * 0.007)) * flow_speed;
    var s_flow_up = 0.0;
    if (!sol_above) {
        s_flow_up = min(new_steam, (1.0 - g_above_v.x) * steam_rise_speed);
    }
    var s_flow_from_below = 0.0;
    if (!sol_below) {
        s_flow_from_below = min(g_below_v.x, (1.0 - new_steam) * steam_rise_speed);
    }
    new_steam = new_steam - s_flow_up + s_flow_from_below;

    var s_flow_left  = 0.0;
    var s_flow_right = 0.0;
    var s_flow_back  = 0.0;
    var s_flow_front = 0.0;
    // Extremely low horizontal spreading (reduced to 0.02) to keep the steam column concentrated
    let s_spread = min(0.20, 0.02 * flow_speed);
    if (!sol_left)  { s_flow_left  = (gas.x - g_left_v.x)  * s_spread - gas_bias_x * gas.x; }
    if (!sol_right) { s_flow_right = (gas.x - g_right_v.x) * s_spread + gas_bias_x * gas.x; }
    if (!sol_back)  { s_flow_back  = (gas.x - g_back_v.x)  * s_spread - gas_bias_z * gas.x; }
    if (!sol_front) { s_flow_front = (gas.x - g_front_v.x) * s_spread + gas_bias_z * gas.x; }
    new_steam -= (s_flow_left + s_flow_right + s_flow_back + s_flow_front);
    if (new_steam < 0.001) { new_steam = 0.0; }

    // --- 2. Volcanic Smoke/Ash Rising & Spreading (gas.y) ---
    var new_smoke = gas.y;
    let smoke_rise_speed = 0.15 * flow_speed;
    var sm_flow_up = 0.0;
    if (!sol_above) {
        sm_flow_up = min(new_smoke, (1.0 - g_above_v.y) * smoke_rise_speed);
    }
    var sm_flow_from_below = 0.0;
    if (!sol_below) {
        sm_flow_from_below = min(g_below_v.y, (1.0 - new_smoke) * smoke_rise_speed);
    }
    new_smoke = new_smoke - sm_flow_up + sm_flow_from_below;

    var sm_flow_left  = 0.0;
    var sm_flow_right = 0.0;
    var sm_flow_back  = 0.0;
    var sm_flow_front = 0.0;
    let sm_spread = min(0.20, 0.18 * flow_speed); // smoke spreads wider horizontally
    if (!sol_left)  { sm_flow_left  = (gas.y - g_left_v.y)  * sm_spread - gas_bias_x * gas.y; }
    if (!sol_right) { sm_flow_right = (gas.y - g_right_v.y) * sm_spread + gas_bias_x * gas.y; }
    if (!sol_back)  { sm_flow_back  = (gas.y - g_back_v.y)  * sm_spread - gas_bias_z * gas.y; }
    if (!sol_front) { sm_flow_front = (gas.y - g_front_v.y) * sm_spread + gas_bias_z * gas.y; }
    new_smoke -= (sm_flow_left + sm_flow_right + sm_flow_back + sm_flow_front);
    if (new_smoke < 0.001) { new_smoke = 0.0; }

    // --- 3. Acid Fog Rising & Spreading (gas.z) ---
    var new_fog = gas.z;
    let fog_rise_speed = 0.20 * flow_speed;
    var f_flow_up = 0.0;
    if (!sol_above) {
        f_flow_up = min(new_fog, (1.0 - g_above_v.z) * fog_rise_speed);
    }
    var f_flow_from_below = 0.0;
    if (!sol_below) {
        f_flow_from_below = min(g_below_v.z, (1.0 - new_fog) * fog_rise_speed);
    }
    new_fog = new_fog - f_flow_up + f_flow_from_below;

    var f_flow_left  = 0.0;
    var f_flow_right = 0.0;
    var f_flow_back  = 0.0;
    var f_flow_front = 0.0;
    let f_spread = min(0.20, 0.10 * flow_speed);
    if (!sol_left)  { f_flow_left  = (gas.z - g_left_v.z)  * f_spread - gas_bias_x * gas.z; }
    if (!sol_right) { f_flow_right = (gas.z - g_right_v.z) * f_spread + gas_bias_x * gas.z; }
    if (!sol_back)  { f_flow_back  = (gas.z - g_back_v.z)  * f_spread - gas_bias_z * gas.z; }
    if (!sol_front) { f_flow_front = (gas.z - g_front_v.z) * f_spread + gas_bias_z * gas.z; }
    new_fog -= (f_flow_left + f_flow_right + f_flow_back + f_flow_front);
    if (new_fog < 0.001) { new_fog = 0.0; }

    // --- 4. Methane Gas Rising & Spreading (gas.w) ---
    var new_methane = gas.w;
    let methane_rise_speed = 0.45 * flow_speed; // methane is extremely light, rises very fast
    var m_flow_up = 0.0;
    if (!sol_above) {
        m_flow_up = min(new_methane, (1.0 - g_above_v.w) * methane_rise_speed);
    }
    var m_flow_from_below = 0.0;
    if (!sol_below) {
        m_flow_from_below = min(g_below_v.w, (1.0 - new_methane) * methane_rise_speed);
    }
    new_methane = new_methane - m_flow_up + m_flow_from_below;

    var m_flow_left  = 0.0;
    var m_flow_right = 0.0;
    var m_flow_back  = 0.0;
    var m_flow_front = 0.0;
    let m_spread = min(0.20, 0.15 * flow_speed);
    if (!sol_left)  { m_flow_left  = (gas.w - g_left_v.w)  * m_spread; }
    if (!sol_right) { m_flow_right = (gas.w - g_right_v.w) * m_spread; }
    if (!sol_back)  { m_flow_back  = (gas.w - g_back_v.w)  * m_spread; }
    if (!sol_front) { m_flow_front = (gas.w - g_front_v.w) * m_spread; }
    new_methane -= (m_flow_left + m_flow_right + m_flow_back + m_flow_front);
    if (new_methane < 0.001) { new_methane = 0.0; }


    // --- Mass Transfer from Liquid Phase ---
    let water_here = get_water(local_x, local_y, local_z);
    let evap_mult = select(0.002, 1.0 + (local_temp - 20.0) * 0.18, local_temp > 20.0);
    let final_evap = u.misc_params.w * evap_mult * 3.5;

    // Steam generation from water evaporation (scaled 3.0x, throttled by air dryness and falling water slow-evaporation by 98%)
    let dryness = max(0.0, 1.0 - gas.x);
    let evap_scale = select(1.0, 0.02, !sol_below);
    let evaporated_water = select(min(water_here.x, 3.0 * final_evap * dt * 50.0 * dryness * evap_scale), 0.0, near_ceiling);
    
    // Additional rapid steam generation from lightning strikes zapping water
    let em_val_here = get_em(local_x, local_y, local_z);
    let potential_here = em_val_here.w;
    var zapped_steam = 0.0;
    if (abs(potential_here) > 0.1) {
        zapped_steam = min(water_here.x, abs(potential_here) * 1.5 * dt);
    }
    new_steam = new_steam + (evaporated_water + zapped_steam) * u.terrain_params3.w;

    // Methane generation from Crude Oil evaporation
    let evaporated_oil = min(water_here.w, final_evap * dt * 15.0 * select(1.0, 5.0, local_temp > 60.0));
    new_methane = new_methane + evaporated_oil * 2.0;

    // Steam generation from Water/Lava reaction
    if (water_here.x > 0.005 && water_here.y > 0.005) {
        let react = min(water_here.x, water_here.y) * 0.85;
        new_steam = new_steam + react * u.terrain_params3.w * 2.0;
    }

    // Acid Fog generation from Acid eating solid walls (excluding ceiling to allow condensation)
    let adjacent_to_solid = sol_left || sol_right || sol_back || sol_front || sol_below;
    if (adjacent_to_solid && water_here.z > 0.0) {
        let consumed_acid = min(water_here.z, 2.20 * dt);
        new_fog = new_fog + consumed_acid * 0.15;
    }

    // --- Condensation onto Ceilings & Pressure Waves ---
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
    let threshold_mult = select(0.45, 0.15, is_cold);
    let condensation_threshold = u.grid_dims.w * threshold_mult;

    // 1. Steam ceiling condensation (lowered threshold to 0.02, with a moderate base speed so it pools and lingers)
    var total_condensed = 0.0;
    if (near_ceiling && new_steam >= 0.02) {
        let rate_mult = select(1.0, 2.5, is_cold);
        let condensation_rate = 0.10 * u.shadow_ao_quality.w * dt * rate_mult;
        total_condensed = total_condensed + min(new_steam, condensation_rate);
    }

    // 2. Shockwave / Pressure Condensation
    if (local_pressure > 5.0 && new_steam > 0.01) {
        let pressure_condensation_rate = 1.5 * dt * local_pressure;
        total_condensed = total_condensed + min(new_steam - total_condensed, pressure_condensation_rate);
    }
    new_steam = max(0.0, new_steam - total_condensed);

    // 2b. Mid-air rain condensation (saturation-triggered downpour, with a high base speed to guarantee downpours)
    let rain_threshold = u.grid_dims.w;
    var rain_condensed = 0.0;
    if (new_steam > rain_threshold) {
        let rain_rate = 3.0 * (1.5 * u.shadow_ao_quality.w + 20.0) * dt * (new_steam - rain_threshold);
        rain_condensed = min(new_steam, rain_rate);
        new_steam = new_steam - rain_condensed;
    }

    // 3. Acid Fog ceiling condensation
    var acid_condensed = 0.0;
    if (near_ceiling && gas.z >= 0.02) {
        let rate_mult = select(1.0, 2.5, is_cold);
        let condensation_rate = 0.008 * u.shadow_ao_quality.w * dt * rate_mult;
        acid_condensed = min(gas.z, condensation_rate);
    }
    new_fog = max(0.0, new_fog - acid_condensed);


    // --- Fuel & Atmospheric Combustion ---
    let em_val = get_em(local_x, local_y, local_z);
    let potential = em_val.w;
    let has_combustion_source = water_here.y > 0.05 || local_temp > 120.0 || abs(potential) > 0.15;
    var burned_methane = 0.0;
    if (has_combustion_source && new_methane > 0.0) {
        burned_methane = min(new_methane, 2.5 * dt);
        new_methane = new_methane - burned_methane;
    }

    // Crude Oil burned in liquid pass also generates volcanic smoke/ash
    var burned_oil = 0.0;
    if (has_combustion_source && water_here.w > 0.0) {
        burned_oil = min(water_here.w, 0.10 * dt);
    }

    // Generate Volcanic Ash/Smoke as combustion product
    if (burned_oil > 0.0 || burned_methane > 0.0) {
        new_smoke = new_smoke + burned_oil * 1.1 + burned_methane * 1.3;
    }

    // Dispersal/decay over time
    let decay_rate = select(0.012 * dt, 0.001 * dt, near_ceiling);
    new_steam = max(0.0, new_steam - decay_rate);
    new_smoke = max(0.0, new_smoke - decay_rate * 0.70); // smoke decays moderately
    new_fog = max(0.0, new_fog - decay_rate * 0.50);
    new_methane = max(0.0, new_methane - decay_rate * 0.20);

    // Delete gas if it reaches the unloaded top/boundary of the active world (prevents chunk-edge lag)
    let above_voxel_check = get_voxel(local_x, local_y + 1, local_z);
    if (above_voxel_check.x == 1.5 && above_voxel_check.y == 1.0) {
        new_steam = 0.0;
        new_smoke = 0.0;
        new_fog = 0.0;
        new_methane = 0.0;
    }

    // Prevent compiler optimization of gas_texture binding
    let dummy_gas = get_gas(0, 0, 0);
    gas.x = clamp(new_steam, 0.0, 1.0) + dummy_gas.x * 1e-10;
    gas.y = clamp(new_smoke, 0.0, 1.0);
    gas.z = clamp(new_fog, 0.0, 1.0);
    gas.w = clamp(new_methane, 0.0, 1.0);
}

}

                output_fields[idx] = gas + vec4<f32>(f32((textureDimensions(voxel_texture) + textureDimensions(water_texture) + textureDimensions(gas_texture) + textureDimensions(em_texture) + textureDimensions(gravity_texture) + textureDimensions(voxel_baked_values_texture)).x) * 0.0f);
            }