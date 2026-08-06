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
//
// Input/Output variable is:
//   var water: vec4<f32>; // (x: Water, y: Lava, z: Acid, w: Crude Oil)
//
// Injected code here executes per-voxel. Use `water` to modify fluid simulation state.
//

let self_voxel = get_voxel(local_x, local_y, local_z);

// If the voxel is solid (SDF <= threshold), it cannot contain liquid
let solid_thresh = u.terrain_params3.z;
if (self_voxel.x <= solid_thresh) {
    water = vec4<f32>(0.0);
} else {
    let baked_vals = get_baked_values(local_x, local_y, local_z);
    let slope = vec2<f32>(baked_vals.z, baked_vals.w) * 2.0 - 1.0;
    let slope_bias_x = -slope.x * 0.15;
    let slope_bias_z = -slope.y * 0.15;

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
        
        water.x = mix(water.x, upstream_fluid.x, push_speed);
        water.y = mix(water.y, upstream_fluid.y, push_speed);
        water.z = mix(water.z, upstream_fluid.z, push_speed);
        water.w = mix(water.w, upstream_fluid.w, push_speed);
    }

    // --- Gravity Field Advection Push ---
    let grav_vector = get_gravity(local_x, local_y, local_z);
    let local_time_dilation = grav_vector.w;
    let g_len = length(grav_vector.xyz);
    if (g_len > 0.1) {
        let g_dir = grav_vector.xyz / g_len;
        let is_custom_g = g_dir.y > -0.9 || g_len < 5.0 || g_len > 15.0;
        if (is_custom_g) {
            let dx = g_dir.x;
            let dy = g_dir.y;
            let dz = g_dir.z;
            
            let sx = local_x - i32(round(dx));
            let sy = local_y - i32(round(dy));
            let sz = local_z - i32(round(dz));
            
            let push_speed = clamp(g_len * 0.15 * dt * local_time_dilation, 0.0, 0.95);
            let upstream_fluid = get_fluid(sx, sy, sz);
            
            water.x = mix(water.x, upstream_fluid.x, push_speed);
            water.y = mix(water.y, upstream_fluid.y, push_speed);
            water.z = mix(water.z, upstream_fluid.z, push_speed);
            water.w = mix(water.w, upstream_fluid.w, push_speed);
        }
    }

    var near_ceiling = false;
    var cold_ceiling = false;
    let gas_here = get_gas(local_x, local_y, local_z);
    let steam_here = gas_here.x;

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

    var w_below_v  = vec4<f32>(0.0);
    var w_below2_v = vec4<f32>(0.0);
    var w_above_v  = vec4<f32>(0.0);
    var w_left_v   = vec4<f32>(0.0);
    var w_right_v  = vec4<f32>(0.0);
    var w_back_v   = vec4<f32>(0.0);
    var w_front_v  = vec4<f32>(0.0);

    let self_idx = u32(local_x + local_y * 32 + local_z * 1024);
    if (local_x > 0 && local_x < 31 && local_y > 1 && local_y < 31 && local_z > 0 && local_z < 31) {
        w_below_v  = input_fields[self_idx - 32u];
        w_below2_v = input_fields[self_idx - 64u];
        w_above_v  = input_fields[self_idx + 32u];
        w_left_v   = input_fields[self_idx - 1u];
        w_right_v  = input_fields[self_idx + 1u];
        w_back_v   = input_fields[self_idx - 1024u];
        w_front_v  = input_fields[self_idx + 1024u];
    } else {
        w_below_v  = get_fluid(local_x, local_y - 1, local_z);
        w_below2_v = get_fluid(local_x, local_y - 2, local_z);
        w_above_v  = get_fluid(local_x, local_y + 1, local_z);
        w_left_v   = get_fluid(local_x - 1, local_y, local_z);
        w_right_v  = get_fluid(local_x + 1, local_y, local_z);
        w_back_v   = get_fluid(local_x, local_y, local_z - 1);
        w_front_v  = get_fluid(local_x, local_y, local_z + 1);
    }

    // Check voxel solidity for neighbors (SDF <= threshold is solid)
    let sol_below  = get_voxel(local_x, local_y - 1, local_z).x <= solid_thresh;
    let sol_below2 = get_voxel(local_x, local_y - 2, local_z).x <= solid_thresh;
    let sol_above  = get_voxel(local_x, local_y + 1, local_z).x <= solid_thresh;
    let sol_left  = get_voxel(local_x - 1, local_y, local_z).x <= solid_thresh;
    let sol_right = get_voxel(local_x + 1, local_y, local_z).x <= solid_thresh;
    let sol_back  = get_voxel(local_x, local_y, local_z - 1).x <= solid_thresh;
    let sol_front = get_voxel(local_x, local_y, local_z + 1).x <= solid_thresh;
    
    let flow_speed = u.misc_params.y * local_time_dilation;
    var g_dir: vec3<f32> = vec3<f32>(0.0, -1.0, 0.0);
    if (g_len > 0.01) {
        g_dir = grav_vector.xyz / g_len;
    }
    let g_pull_below = clamp(-g_dir.y, 0.0, 1.0);

    // --- 1. Water Flow Loop (gravity & spreading) ---
    var new_water = water.x;
    var w_flow_down_below = 0.0;
    if (!sol_below && !sol_below2) {
        w_flow_down_below = min(w_below_v.x, (1.0 - w_below2_v.x) * flow_speed * g_pull_below);
    }
    var w_flow_down = 0.0;
    if (!sol_below) {
        w_flow_down = min(new_water, (1.0 - w_below_v.x + w_flow_down_below) * flow_speed * g_pull_below);
    }
    var w_flow_from_above = 0.0;
    if (!sol_above) {
        var w_flow_self_below = 0.0;
        if (!sol_below) {
            w_flow_self_below = min(new_water, (1.0 - w_below_v.x) * flow_speed * g_pull_below);
        }
        w_flow_from_above = min(w_above_v.x, (1.0 - new_water + w_flow_self_below) * flow_speed);
    }
    new_water = new_water - w_flow_down + w_flow_from_above;

    var w_flow_left  = 0.0;
    var w_flow_right = 0.0;
    var w_flow_back  = 0.0;
    var w_flow_front = 0.0;
    let w_spread_factor = min(0.20, 0.15 * flow_speed);
    if (!sol_left) {
        let sol_left_below = get_voxel(local_x - 1, local_y - 1, local_z).x <= solid_thresh;
        if (sol_below && !sol_left_below) {
            w_flow_left = min(water.x, (1.0 - w_left_v.x) * flow_speed * 0.85);
        } else if (!sol_below && sol_left_below) {
            w_flow_left = -min(w_left_v.x, (1.0 - water.x) * flow_speed * 0.85);
        } else if (sol_below) {
            w_flow_left = (water.x - w_left_v.x) * w_spread_factor + slope_bias_x * water.x;
        }
    }
    if (!sol_right) {
        let sol_right_below = get_voxel(local_x + 1, local_y - 1, local_z).x <= solid_thresh;
        if (sol_below && !sol_right_below) {
            w_flow_right = min(water.x, (1.0 - w_right_v.x) * flow_speed * 0.85);
        } else if (!sol_below && sol_right_below) {
            w_flow_right = -min(w_right_v.x, (1.0 - water.x) * flow_speed * 0.85);
        } else if (sol_below) {
            w_flow_right = (water.x - w_right_v.x) * w_spread_factor - slope_bias_x * water.x;
        }
    }
    if (!sol_back) {
        let sol_back_below = get_voxel(local_x, local_y - 1, local_z - 1).x <= solid_thresh;
        if (sol_below && !sol_back_below) {
            w_flow_back = min(water.x, (1.0 - w_back_v.x) * flow_speed * 0.85);
        } else if (!sol_below && sol_back_below) {
            w_flow_back = -min(w_back_v.x, (1.0 - water.x) * flow_speed * 0.85);
        } else if (sol_below) {
            w_flow_back = (water.x - w_back_v.x) * w_spread_factor + slope_bias_z * water.x;
        }
    }
    if (!sol_front) {
        let sol_front_below = get_voxel(local_x, local_y - 1, local_z + 1).x <= solid_thresh;
        if (sol_below && !sol_front_below) {
            w_flow_front = min(water.x, (1.0 - w_front_v.x) * flow_speed * 0.85);
        } else if (!sol_below && sol_front_below) {
            w_flow_front = -min(w_front_v.x, (1.0 - water.x) * flow_speed * 0.85);
        } else if (sol_below) {
            w_flow_front = (water.x - w_front_v.x) * w_spread_factor - slope_bias_z * water.x;
        }
    }
    new_water -= (w_flow_left + w_flow_right + w_flow_back + w_flow_front);
    if (new_water < 0.001 && !near_ceiling && sol_below) { new_water = 0.0; }

    // --- 2. Lava Flow Loop (highly viscous, slow gravity & spreading) ---
    var new_lava = water.y;
    let lava_flow_speed = flow_speed * select(0.08, 0.015, select(false, get_voxel(local_x, local_y - 1, local_z).y == 13.0, local_y > 0)); // slow viscous flow, unless sitting on hot lava rock
    var l_flow_down = 0.0;
    if (!sol_below) {
        l_flow_down = min(new_lava, (1.0 - w_below_v.y) * lava_flow_speed * g_pull_below);
    }
    var l_flow_from_above = 0.0;
    if (!sol_above) {
        l_flow_from_above = min(w_above_v.y, (1.0 - new_lava) * lava_flow_speed);
    }
    new_lava = new_lava - l_flow_down + l_flow_from_above;

    var l_flow_left  = 0.0;
    var l_flow_right = 0.0;
    var l_flow_back  = 0.0;
    var l_flow_front = 0.0;
    let l_spread_factor = 0.06 * lava_flow_speed;
    if (!sol_left) {
        let sol_left_below = get_voxel(local_x - 1, local_y - 1, local_z).x <= solid_thresh;
        if (sol_below && !sol_left_below) {
            l_flow_left = min(new_lava, (1.0 - w_left_v.y) * lava_flow_speed * 0.85);
        } else if (!sol_below && sol_left_below) {
            l_flow_left = -min(w_left_v.y, (1.0 - new_lava) * lava_flow_speed * 0.85);
        } else if (sol_below) {
            l_flow_left = (water.y - w_left_v.y) * l_spread_factor;
        }
    }
    if (!sol_right) {
        let sol_right_below = get_voxel(local_x + 1, local_y - 1, local_z).x <= solid_thresh;
        if (sol_below && !sol_right_below) {
            l_flow_right = min(new_lava, (1.0 - w_right_v.y) * lava_flow_speed * 0.85);
        } else if (!sol_below && sol_right_below) {
            l_flow_right = -min(w_right_v.y, (1.0 - new_lava) * lava_flow_speed * 0.85);
        } else if (sol_below) {
            l_flow_right = (water.y - w_right_v.y) * l_spread_factor;
        }
    }
    if (!sol_back) {
        let sol_back_below = get_voxel(local_x, local_y - 1, local_z - 1).x <= solid_thresh;
        if (sol_below && !sol_back_below) {
            l_flow_back = min(new_lava, (1.0 - w_back_v.y) * lava_flow_speed * 0.85);
        } else if (!sol_below && sol_back_below) {
            l_flow_back = -min(w_back_v.y, (1.0 - new_lava) * lava_flow_speed * 0.85);
        } else if (sol_below) {
            l_flow_back = (water.y - w_back_v.y) * l_spread_factor;
        }
    }
    if (!sol_front) {
        let sol_front_below = get_voxel(local_x, local_y - 1, local_z + 1).x <= solid_thresh;
        if (sol_below && !sol_front_below) {
            l_flow_front = min(new_lava, (1.0 - w_front_v.y) * lava_flow_speed * 0.85);
        } else if (!sol_below && sol_front_below) {
            l_flow_front = -min(w_front_v.y, (1.0 - new_lava) * lava_flow_speed * 0.85);
        } else if (sol_below) {
            l_flow_front = (water.y - w_front_v.y) * l_spread_factor;
        }
    }
    new_lava -= (l_flow_left + l_flow_right + l_flow_back + l_flow_front);
    if (new_lava < 0.001) { new_lava = 0.0; }

    // --- 3. Acid Flow Loop (fast, highly corrosive) ---
    var new_acid = water.z;
    let acid_flow_speed = flow_speed * 0.65;
    var a_flow_down = 0.0;
    if (!sol_below) {
        a_flow_down = min(new_acid, (1.0 - w_below_v.z) * acid_flow_speed * g_pull_below);
    }
    var a_flow_from_above = 0.0;
    if (!sol_above) {
        a_flow_from_above = min(w_above_v.z, (1.0 - new_acid) * acid_flow_speed);
    }
    new_acid = new_acid - a_flow_down + a_flow_from_above;

    var a_flow_left  = 0.0;
    var a_flow_right = 0.0;
    var a_flow_back  = 0.0;
    var a_flow_front = 0.0;
    let a_spread_factor = 0.15 * acid_flow_speed;
    if (!sol_left) {
        let sol_left_below = get_voxel(local_x - 1, local_y - 1, local_z).x <= solid_thresh;
        if (sol_below && !sol_left_below) {
            a_flow_left = min(new_acid, (1.0 - w_left_v.z) * acid_flow_speed * 0.85);
        } else if (!sol_below && sol_left_below) {
            a_flow_left = -min(w_left_v.z, (1.0 - new_acid) * acid_flow_speed * 0.85);
        } else if (sol_below) {
            a_flow_left = (water.z - w_left_v.z) * a_spread_factor;
        }
    }
    if (!sol_right) {
        let sol_right_below = get_voxel(local_x + 1, local_y - 1, local_z).x <= solid_thresh;
        if (sol_below && !sol_right_below) {
            a_flow_right = min(new_acid, (1.0 - w_right_v.z) * acid_flow_speed * 0.85);
        } else if (!sol_below && sol_right_below) {
            a_flow_right = -min(w_right_v.z, (1.0 - new_acid) * acid_flow_speed * 0.85);
        } else if (sol_below) {
            a_flow_right = (water.z - w_right_v.z) * a_spread_factor;
        }
    }
    if (!sol_back) {
        let sol_back_below = get_voxel(local_x, local_y - 1, local_z - 1).x <= solid_thresh;
        if (sol_below && !sol_back_below) {
            a_flow_back = min(new_acid, (1.0 - w_back_v.z) * acid_flow_speed * 0.85);
        } else if (!sol_below && sol_back_below) {
            a_flow_back = -min(w_back_v.z, (1.0 - new_acid) * acid_flow_speed * 0.85);
        } else if (sol_below) {
            a_flow_back = (water.z - w_back_v.z) * a_spread_factor;
        }
    }
    if (!sol_front) {
        let sol_front_below = get_voxel(local_x, local_y - 1, local_z + 1).x <= solid_thresh;
        if (sol_below && !sol_front_below) {
            a_flow_front = min(new_acid, (1.0 - w_front_v.z) * acid_flow_speed * 0.85);
        } else if (!sol_below && sol_front_below) {
            a_flow_front = -min(w_front_v.z, (1.0 - new_acid) * acid_flow_speed * 0.85);
        } else if (sol_below) {
            a_flow_front = (water.z - w_front_v.z) * a_spread_factor;
        }
    }
    new_acid -= (a_flow_left + a_flow_right + a_flow_back + a_flow_front);
    if (new_acid < 0.001) { new_acid = 0.0; }

    // --- 4. Crude Oil Flow Loop (viscous, highly flammable fuel) ---
    var new_oil = water.w;
    let oil_flow_speed = flow_speed * 0.35;
    var o_flow_down = 0.0;
    if (!sol_below) {
        o_flow_down = min(new_oil, (1.0 - w_below_v.w) * oil_flow_speed * g_pull_below);
    }
    var o_flow_from_above = 0.0;
    if (!sol_above) {
        o_flow_from_above = min(w_above_v.w, (1.0 - new_oil) * oil_flow_speed);
    }
    new_oil = new_oil - o_flow_down + o_flow_from_above;

    var o_flow_left  = 0.0;
    var o_flow_right = 0.0;
    var o_flow_back  = 0.0;
    var o_flow_front = 0.0;
    let o_spread_factor = 0.10 * oil_flow_speed;
    if (!sol_left) {
        let sol_left_below = get_voxel(local_x - 1, local_y - 1, local_z).x <= solid_thresh;
        if (sol_below && !sol_left_below) {
            o_flow_left = min(new_oil, (1.0 - w_left_v.w) * oil_flow_speed * 0.85);
        } else if (!sol_below && sol_left_below) {
            o_flow_left = -min(w_left_v.w, (1.0 - new_oil) * oil_flow_speed * 0.85);
        } else if (sol_below) {
            o_flow_left = (water.w - w_left_v.w) * o_spread_factor;
        }
    }
    if (!sol_right) {
        let sol_right_below = get_voxel(local_x + 1, local_y - 1, local_z).x <= solid_thresh;
        if (sol_below && !sol_right_below) {
            o_flow_right = min(new_oil, (1.0 - w_right_v.w) * oil_flow_speed * 0.85);
        } else if (!sol_below && sol_right_below) {
            o_flow_right = -min(w_right_v.w, (1.0 - new_oil) * oil_flow_speed * 0.85);
        } else if (sol_below) {
            o_flow_right = (water.w - w_right_v.w) * o_spread_factor;
        }
    }
    if (!sol_back) {
        let sol_back_below = get_voxel(local_x, local_y - 1, local_z - 1).x <= solid_thresh;
        if (sol_below && !sol_back_below) {
            o_flow_back = min(new_oil, (1.0 - w_back_v.w) * oil_flow_speed * 0.85);
        } else if (!sol_below && sol_back_below) {
            o_flow_back = -min(w_back_v.w, (1.0 - new_oil) * oil_flow_speed * 0.85);
        } else if (sol_below) {
            o_flow_back = (water.w - w_back_v.w) * o_spread_factor;
        }
    }
    if (!sol_front) {
        let sol_front_below = get_voxel(local_x, local_y - 1, local_z + 1).x <= solid_thresh;
        if (sol_below && !sol_front_below) {
            o_flow_front = min(new_oil, (1.0 - w_front_v.w) * oil_flow_speed * 0.85);
        } else if (!sol_below && sol_front_below) {
            o_flow_front = -min(w_front_v.w, (1.0 - new_oil) * oil_flow_speed * 0.85);
        } else if (sol_below) {
            o_flow_front = (water.w - w_front_v.w) * o_spread_factor;
        }
    }
    new_oil -= (o_flow_left + o_flow_right + o_flow_back + o_flow_front);
    if (new_oil < 0.001) { new_oil = 0.0; }

    // --- Evaporation modulated by local heat ---
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

    // Water Evaporation (scaled 3.0x, disabled near ceilings, throttled by air dryness, and scaled down by 98% for falling water)
    let dryness = max(0.0, 1.0 - steam_here);
    let evap_scale = select(1.0, 0.02, !sol_below);
    let evaporated_water = select(min(new_water, 3.0 * final_evap * dt * 50.0 * dryness * evap_scale), 0.0, near_ceiling);
    
    // Additional rapid electro-vaporization from lightning zapping water
    let em_val = get_em(local_x, local_y, local_z);
    let potential = em_val.w;
    var zapped_evap = 0.0;
    if (abs(potential) > 0.1) {
        zapped_evap = min(new_water, abs(potential) * 1.5 * dt);
    }
    new_water = new_water - evaporated_water - zapped_evap;

    // Oil Evaporation (evaporates into Methane Gas)
    let evaporated_oil = min(new_oil, final_evap * dt * 15.0 * select(1.0, 5.0, local_temp > 60.0));
    new_oil = new_oil - evaporated_oil;

    // --- Liquid-Liquid Reactions ---
    // 1. Water vs Lava Steam explosion reaction
    if (new_water > 0.005 && new_lava > 0.005) {
        let react = min(new_water, new_lava) * 0.85;
        new_water = max(0.0, new_water - react);
        new_lava = max(0.0, new_lava - react);
    }
    // 2. Water vs Acid dilution
    if (new_water > 0.005 && new_acid > 0.005) {
        let react = min(new_water, new_acid) * 0.20;
        new_water = max(0.0, new_water - react);
        new_acid = max(0.0, new_acid - react);
    }

    // --- Combustion of Crude Oil ---
    // Oil combusts instantly if adjacent to Lava or if local temperature > 120 C
    let has_combustion_source = new_lava > 0.05 || w_below_v.y > 0.05 || w_above_v.y > 0.05 ||
                                 w_left_v.y > 0.05 || w_right_v.y > 0.05 ||
                                 w_back_v.y > 0.05 || w_front_v.y > 0.05 ||
                                 local_temp > 120.0;
    if (has_combustion_source && new_oil > 0.0) {
        // Oil burns steadily and generates smoke/heat
        let burned_oil = min(new_oil, 0.10 * dt);
        new_oil = new_oil - burned_oil;
    }

    // --- Acid contact with solid walls ---
    // Acid eats solid walls, generating fumes (excluding ceiling to allow condensation)
    let adjacent_to_solid = sol_left || sol_right || sol_back || sol_front || sol_below;
    if (adjacent_to_solid && new_acid > 0.0) {
        let consumed_acid = min(new_acid, 2.20 * dt);
        new_acid = new_acid - consumed_acid;
    }

    // --- Ceiling & Pressure Condensation (Vapor -> Liquid) ---
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
    var total_condensed = 0.0;

    // 1. Regular Ceiling Condensation (lowered threshold to 0.02, with a moderate base speed so it pools and lingers)
    if (near_ceiling && steam_here >= 0.02) {
        let rate_mult = select(1.0, 2.5, is_cold);
        let ceiling_condensation_rate = 0.10 * u.shadow_ao_quality.w * dt * rate_mult;
        total_condensed = total_condensed + min(steam_here, ceiling_condensation_rate);
    }

    // 1b. Acid Fog Ceiling Condensation
    var acid_condensed = 0.0;
    let acid_fog_here = gas_here.z;
    if (near_ceiling && acid_fog_here >= 0.02) {
        let rate_mult = select(1.0, 2.5, is_cold);
        let acid_condensation_rate = 0.008 * u.shadow_ao_quality.w * dt * rate_mult;
        acid_condensed = min(acid_fog_here, acid_condensation_rate);
    }

    // 2. Shockwave / Pressure Condensation
    if (local_pressure > 5.0 && steam_here > 0.01) {
        let pressure_condensation_rate = 1.5 * dt * local_pressure;
        total_condensed = total_condensed + min(steam_here - total_condensed, pressure_condensation_rate);
    }

    // 3. Mid-air rain condensation (saturation-triggered downpour, with a high base speed to guarantee downpours)
    let rain_threshold = u.grid_dims.w;
    var rain_condensed = 0.0;
    if (steam_here > rain_threshold) {
        let rain_rate = 3.0 * (1.5 * u.shadow_ao_quality.w + 20.0) * dt * (steam_here - rain_threshold);
        rain_condensed = min(steam_here, rain_rate);
    }

    let combined_condensed = total_condensed + rain_condensed;
    if (combined_condensed > 0.0) {
        new_water = new_water + combined_condensed * 1.5; // boosted conversion factor for thick visible drops
    }
    if (acid_condensed > 0.0) {
        new_acid = new_acid + acid_condensed * 0.40;
    }

    water.x = clamp(new_water, 0.0, 1.0);
    water.y = clamp(new_lava, 0.0, 1.0);
    water.z = clamp(new_acid, 0.0, 1.0);
    water.w = clamp(new_oil, 0.0, 1.0);
}

}

                output_fields[idx] = water + vec4<f32>(f32((textureDimensions(voxel_texture) + textureDimensions(water_texture) + textureDimensions(gas_texture) + textureDimensions(em_texture) + textureDimensions(gravity_texture) + textureDimensions(voxel_baked_values_texture)).x) * 0.0f);
            }