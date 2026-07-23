// water_rule.wgsl - Native GPU-Resident JIT Water cellular automata & fluid loop.
//
// Input/Output variable is:
//   var water: vec4<f32>; // (x: Volume fraction [0..1], y,z,w: Velocity vector)
//
// Injected code here executes per-voxel. Use `water` to modify fluid simulation state.
//

let self_voxel = get_voxel(local_x, local_y, local_z);

// If the voxel is solid (SDF <= threshold), it cannot contain water
let solid_thresh = u.terrain_params3.z;
if (self_voxel.x <= solid_thresh) {
    water = vec4<f32>(0.0);
} else {
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

    let w_below  = w_below_v.x;
    let w_below2 = w_below2_v.x;
    let w_above  = w_above_v.x;
    let w_left   = w_left_v.x;
    let w_right  = w_right_v.x;
    let w_back   = w_back_v.x;
    let w_front  = w_front_v.x;

    // Check voxel solidity for neighbors (SDF <= threshold is solid)
    let sol_below  = get_voxel(local_x, local_y - 1, local_z).x <= solid_thresh;
    let sol_below2 = get_voxel(local_x, local_y - 2, local_z).x <= solid_thresh;
    let sol_above  = get_voxel(local_x, local_y + 1, local_z).x <= solid_thresh;
    let sol_left  = get_voxel(local_x - 1, local_y, local_z).x <= solid_thresh;
    let sol_right = get_voxel(local_x + 1, local_y, local_z).x <= solid_thresh;
    let sol_back  = get_voxel(local_x, local_y, local_z - 1).x <= solid_thresh;
    let sol_front = get_voxel(local_x, local_y, local_z + 1).x <= solid_thresh;
    
    var new_volume = water.x;
    
    let flow_speed = u.misc_params.y;
    
    // --- 1. Downward flow (Gravity with look-ahead) ---
    var flow_down_below = 0.0;
    if (!sol_below && !sol_below2) {
        flow_down_below = min(w_below, 1.0 - w_below2) * flow_speed;
    }
    
    var flow_down = 0.0;
    if (!sol_below) {
        flow_down = min(new_volume, 1.0 - w_below + flow_down_below) * flow_speed;
    }
    
    var flow_from_above = 0.0;
    if (!sol_above) {
        var flow_self_below = 0.0;
        if (!sol_below) {
            flow_self_below = min(new_volume, 1.0 - w_below) * flow_speed;
        }
        flow_from_above = min(w_above, 1.0 - new_volume + flow_self_below) * flow_speed;
    }
    
    new_volume = new_volume - flow_down + flow_from_above;

    // --- 2. Horizontal spreading (Height Equalization) ---
    var flow_left  = 0.0;
    var flow_right = 0.0;
    var flow_back  = 0.0;
    var flow_front = 0.0;
    
    let spread_factor = 0.15 * flow_speed;
    if (!sol_left)  { flow_left  = (water.x - w_left)  * spread_factor; }
    if (!sol_right) { flow_right = (water.x - w_right) * spread_factor; }
    if (!sol_back)  { flow_back  = (water.x - w_back)  * spread_factor; }
    if (!sol_front) { flow_front = (water.x - w_front) * spread_factor; }
    
    new_volume -= (flow_left + flow_right + flow_back + flow_front);

    // --- Lava Flow Logic (Viscous, heavy) ---
    var new_lava = water.z;
    let lava_flow_speed = flow_speed * 0.12; // slow viscous flow
    
    var lava_down = 0.0;
    if (!sol_below) {
        lava_down = min(new_lava, 1.0 - w_below_v.z) * lava_flow_speed;
    }
    var lava_from_above = 0.0;
    if (!sol_above) {
        lava_from_above = min(w_above_v.z, 1.0 - new_lava) * lava_flow_speed;
    }
    new_lava = new_lava - lava_down + lava_from_above;

    var l_flow_left  = 0.0;
    var l_flow_right = 0.0;
    var l_flow_back  = 0.0;
    var l_flow_front = 0.0;
    let lava_spread_factor = 0.06 * lava_flow_speed;
    if (!sol_left)  { l_flow_left  = (water.z - w_left_v.z)  * lava_spread_factor; }
    if (!sol_right) { l_flow_right = (water.z - w_right_v.z) * lava_spread_factor; }
    if (!sol_back)  { l_flow_back  = (water.z - w_back_v.z)  * lava_spread_factor; }
    if (!sol_front) { l_flow_front = (water.z - w_front_v.z) * lava_spread_factor; }
    new_lava -= (l_flow_left + l_flow_right + l_flow_back + l_flow_front);
    if (new_lava < 0.001) { new_lava = 0.0; }
    water.z = clamp(new_lava, 0.0, 1.0);

    // --- Acid Flow Logic (Fast, corrosive) ---
    var new_acid = water.w;
    let acid_flow_speed = flow_speed * 0.65; // flows reasonably fast
    
    var acid_down = 0.0;
    if (!sol_below) {
        acid_down = min(new_acid, 1.0 - w_below_v.w) * acid_flow_speed;
    }
    var acid_from_above = 0.0;
    if (!sol_above) {
        acid_from_above = min(w_above_v.w, 1.0 - new_acid) * acid_flow_speed;
    }
    new_acid = new_acid - acid_down + acid_from_above;

    var a_flow_left  = 0.0;
    var a_flow_right = 0.0;
    var a_flow_back  = 0.0;
    var a_flow_front = 0.0;
    let acid_spread_factor = 0.15 * acid_flow_speed;
    if (!sol_left)  { a_flow_left  = (water.w - w_left_v.w)  * acid_spread_factor; }
    if (!sol_right) { a_flow_right = (water.w - w_right_v.w) * acid_spread_factor; }
    if (!sol_back)  { a_flow_back  = (water.w - w_back_v.w)  * acid_spread_factor; }
    if (!sol_front) { a_flow_front = (water.w - w_front_v.w) * acid_spread_factor; }
    new_acid -= (a_flow_left + a_flow_right + a_flow_back + a_flow_front);
    if (new_acid < 0.001) { new_acid = 0.0; }
    water.w = clamp(new_acid, 0.0, 1.0);


    // --- Evaporation modulated by local heat (Inlined loop for WGSL function scope rules) ---
    var local_temp = 0.0;
    var total_weight = 0.0;
    let max_instances = u32(round(u.suns[0].params.y));
    for (var i = 0u; i < max_instances; i = i + 1u) {
        let inst = u.instances[i];
        let radius = inst.pos_scale.w;
        if (radius <= 0.0) { continue; }
        
        let dist = length(voxel_pos - inst.pos_scale.xyz);
        if (dist < radius) {
            let weight = 1.0 - (dist / radius);
            local_temp = local_temp + inst.interaction_fields.x * weight;
            total_weight = total_weight + weight;
        }
    }
    if (total_weight > 0.0) {
        local_temp = local_temp / total_weight;
    }

    // Default evaporation rate is scaled up for high vapor visual feedback
    let evap_mult = 1.0 + max(0.0, local_temp - 20.0) * 0.18;
    let final_evap = u.misc_params.w * evap_mult * 3.5;
    
    // Evaporate liquid water volume into humidity gas (water.y)
    let evaporated_volume = min(new_volume, final_evap * dt * 50.0);
    new_volume = new_volume - evaporated_volume;
    
    // Convert evaporated water to humidity in water.y (volume expands as vapor)
    var my_humidity = water.y + evaporated_volume * u.terrain_params3.w;

    // --- Liquid Reactions (Water vs. Lava steam reaction, Water vs. Acid dilution) ---
    if (new_volume > 0.005 && water.z > 0.005) {
        let react = min(new_volume, water.z) * 0.85;
        new_volume = max(0.0, new_volume - react);
        water.z = max(0.0, water.z - react);
        my_humidity = clamp(my_humidity + react * u.terrain_params3.w * 2.0, 0.0, 1.0);
    }
    if (new_volume > 0.005 && water.w > 0.005) {
        let react = min(new_volume, water.w) * 0.20;
        new_volume = max(0.0, new_volume - react);
        water.w = max(0.0, water.w - react);
    }

    // --- 3. Humidity Rising (Thermal Convection Updrafts) ---
    // Upward flow speed scales with local temperature (base 0.15, up to 0.70 near intense heat)
    let flow_up_speed = (0.15 + min(0.55, max(0.0, local_temp - 20.0) * 0.007)) * flow_speed;
    var flow_up = 0.0;
    if (!sol_above) {
        flow_up = my_humidity * flow_up_speed;
        my_humidity = my_humidity - flow_up;
    }
    
    var flow_from_below = 0.0;
    if (!sol_below) {
        var below_vec = vec4<f32>(0.0);
        if (local_y > 0) {
            below_vec = input_fields[self_idx - 32u];
        } else {
            below_vec = get_fluid(local_x, local_y - 1, local_z);
        }
        flow_from_below = below_vec.y * flow_up_speed;
        my_humidity = my_humidity + flow_from_below;
    }

    // --- 4. Humidity Horizontal Diffusion (Cloud Spreading) ---
    let diffuse_rate = 0.06 * flow_speed;
    var h_left = 0.0;
    var h_right = 0.0;
    var h_front = 0.0;
    var h_back = 0.0;
    if (local_x > 0 && local_x < 31 && local_z > 0 && local_z < 31) {
        h_left  = input_fields[self_idx - 1u].y;
        h_right = input_fields[self_idx + 1u].y;
        h_front = input_fields[self_idx + 1024u].y;
        h_back  = input_fields[self_idx - 1024u].y;
    } else {
        h_left  = get_fluid(local_x - 1, local_y, local_z).y;
        h_right = get_fluid(local_x + 1, local_y, local_z).y;
        h_front = get_fluid(local_x, local_y, local_z + 1).y;
        h_back  = get_fluid(local_x, local_y, local_z - 1).y;
    }
    
    let hum_flow_left = (water.y - h_left) * diffuse_rate;
    let hum_flow_right = (water.y - h_right) * diffuse_rate;
    let hum_flow_front = (water.y - h_front) * diffuse_rate;
    let hum_flow_back = (water.y - h_back) * diffuse_rate;
    
    my_humidity = my_humidity - (hum_flow_left + hum_flow_right + hum_flow_front + hum_flow_back);

    // --- 5. Dynamic Wind Advection (Global Sideways Drift) ---
    // Global wind direction shifts slowly over time based on u.time
    let wind_x = sin(u.time * 0.12) * 0.04 * flow_speed;
    let wind_z = cos(u.time * 0.09) * 0.04 * flow_speed;

    let wind_drift_x = select(wind_x * (h_right - my_humidity), wind_x * (my_humidity - h_left), wind_x > 0.0);
    let wind_drift_z = select(wind_z * (h_front - my_humidity), wind_z * (my_humidity - h_back), wind_z > 0.0);
    my_humidity = my_humidity - (wind_drift_x + wind_drift_z);

    // --- 6. Cold Surface & Cavern Ceiling Condensation ---
    // Proximity check: scan up to 7 voxels above to see if we are near the top of the air column (ceiling)
    // Also check if the ceiling block itself is a cold material (Snow/Ice = Material 6)
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

    let is_cold = cold_ceiling || (local_temp < 10.0);

    // Condense only if we are near the top of the air column and humidity passes the threshold
    // Cold zones drop the Rain Threshold to 15% (from 45%) and accelerate the condensation speed by 2.5x
    let threshold_mult = select(0.45, 0.15, is_cold);
    let condensation_threshold = u.grid_dims.w * threshold_mult;
    if (near_ceiling && my_humidity >= condensation_threshold) {
        let rate_mult = select(1.0, 2.5, is_cold);
        let condensation_rate = 0.75 * dt * u.shadow_ao_quality.w * rate_mult;
        let condensed = min(my_humidity, condensation_rate);
        
        // Perfect Closed-Loop Mass Conservation:
        // Conversion back to liquid volume is exactly the mathematical inverse of the Vapor Expansion slider.
        let condensation_conversion_factor = 1.0 / max(1.0, u.terrain_params3.w);
        new_volume = new_volume + condensed * condensation_conversion_factor;
        my_humidity = my_humidity - condensed;
    }

    // Dispersal/decay over time (Ceiling moisture clings to cold rock and decays 12x slower)
    let decay_rate = select(0.012 * dt, 0.001 * dt, near_ceiling);
    my_humidity = max(0.0, my_humidity - decay_rate);

    // Keep volume bounded and clear tiny values to allow evaporation/drying
    if (new_volume < 0.001) {
        new_volume = 0.0;
    }
    
    // Acid consumption/neutralization when contacting solid surfaces
    let adjacent_to_solid = sol_left || sol_right || sol_back || sol_front || sol_below || sol_above;
    if (adjacent_to_solid) {
        water.w = max(0.0, water.w - 0.20 * dt);
    }

    water.x = clamp(new_volume, 0.0, 1.0);
    water.y = clamp(my_humidity, 0.0, 1.0);
}
