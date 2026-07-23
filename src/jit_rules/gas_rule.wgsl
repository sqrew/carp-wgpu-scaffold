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
    let sol_below = select(false, get_voxel(local_x, local_y - 1, local_z).x <= solid_thresh, local_y > 0);
    let sol_above = select(false, get_voxel(local_x, local_y + 1, local_z).x <= solid_thresh, local_y < 31);
    let sol_left  = select(false, get_voxel(local_x - 1, local_y, local_z).x <= solid_thresh, local_x > 0);
    let sol_right = select(false, get_voxel(local_x + 1, local_y, local_z).x <= solid_thresh, local_x < 31);
    let sol_back  = select(false, get_voxel(local_x, local_y, local_z - 1).x <= solid_thresh, local_z > 0);
    let sol_front = select(false, get_voxel(local_x, local_y, local_z + 1).x <= solid_thresh, local_z < 31);

    let flow_speed = u.misc_params.y;

    // --- Heat calculations ---
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
            local_temp = local_temp + select(0.0, inst.interaction_fields.x, inst.interaction_fields.x > -999.0) * weight;
            total_weight = total_weight + weight;
        }
    }
    if (total_weight > 0.0) {
        local_temp = local_temp / total_weight;
    }

    // --- 1. Steam Rising & Spreading (gas.x) ---
    var new_steam = gas.x;
    let steam_rise_speed = (0.25 + min(0.45, max(0.0, local_temp - 20.0) * 0.007)) * flow_speed;
    var s_flow_up = 0.0;
    if (!sol_above) {
        s_flow_up = min(new_steam, 1.0 - g_above_v.x) * steam_rise_speed;
    }
    var s_flow_from_below = 0.0;
    if (!sol_below) {
        s_flow_from_below = min(g_below_v.x, 1.0 - new_steam) * steam_rise_speed;
    }
    new_steam = new_steam - s_flow_up + s_flow_from_below;

    var s_flow_left  = 0.0;
    var s_flow_right = 0.0;
    var s_flow_back  = 0.0;
    var s_flow_front = 0.0;
    let s_spread = 0.12 * flow_speed;
    if (!sol_left)  { s_flow_left  = (gas.x - g_left_v.x)  * s_spread; }
    if (!sol_right) { s_flow_right = (gas.x - g_right_v.x) * s_spread; }
    if (!sol_back)  { s_flow_back  = (gas.x - g_back_v.x)  * s_spread; }
    if (!sol_front) { s_flow_front = (gas.x - g_front_v.x) * s_spread; }
    new_steam -= (s_flow_left + s_flow_right + s_flow_back + s_flow_front);
    if (new_steam < 0.001) { new_steam = 0.0; }

    // --- 2. Volcanic Smoke/Ash Rising & Spreading (gas.y) ---
    var new_smoke = gas.y;
    let smoke_rise_speed = 0.15 * flow_speed;
    var sm_flow_up = 0.0;
    if (!sol_above) {
        sm_flow_up = min(new_smoke, 1.0 - g_above_v.y) * smoke_rise_speed;
    }
    var sm_flow_from_below = 0.0;
    if (!sol_below) {
        sm_flow_from_below = min(g_below_v.y, 1.0 - new_smoke) * smoke_rise_speed;
    }
    new_smoke = new_smoke - sm_flow_up + sm_flow_from_below;

    var sm_flow_left  = 0.0;
    var sm_flow_right = 0.0;
    var sm_flow_back  = 0.0;
    var sm_flow_front = 0.0;
    let sm_spread = 0.18 * flow_speed; // smoke spreads wider horizontally
    if (!sol_left)  { sm_flow_left  = (gas.y - g_left_v.y)  * sm_spread; }
    if (!sol_right) { sm_flow_right = (gas.y - g_right_v.y) * sm_spread; }
    if (!sol_back)  { sm_flow_back  = (gas.y - g_back_v.y)  * sm_spread; }
    if (!sol_front) { sm_flow_front = (gas.y - g_front_v.y) * sm_spread; }
    new_smoke -= (sm_flow_left + sm_flow_right + sm_flow_back + sm_flow_front);
    if (new_smoke < 0.001) { new_smoke = 0.0; }

    // --- 3. Acid Fog Rising & Spreading (gas.z) ---
    var new_fog = gas.z;
    let fog_rise_speed = 0.20 * flow_speed;
    var f_flow_up = 0.0;
    if (!sol_above) {
        f_flow_up = min(new_fog, 1.0 - g_above_v.z) * fog_rise_speed;
    }
    var f_flow_from_below = 0.0;
    if (!sol_below) {
        f_flow_from_below = min(g_below_v.z, 1.0 - new_fog) * fog_rise_speed;
    }
    new_fog = new_fog - f_flow_up + f_flow_from_below;

    var f_flow_left  = 0.0;
    var f_flow_right = 0.0;
    var f_flow_back  = 0.0;
    var f_flow_front = 0.0;
    let f_spread = 0.10 * flow_speed;
    if (!sol_left)  { f_flow_left  = (gas.z - g_left_v.z)  * f_spread; }
    if (!sol_right) { f_flow_right = (gas.z - g_right_v.z) * f_spread; }
    if (!sol_back)  { f_flow_back  = (gas.z - g_back_v.z)  * f_spread; }
    if (!sol_front) { f_flow_front = (gas.z - g_front_v.z) * f_spread; }
    new_fog -= (f_flow_left + f_flow_right + f_flow_back + f_flow_front);
    if (new_fog < 0.001) { new_fog = 0.0; }

    // --- 4. Methane Gas Rising & Spreading (gas.w) ---
    var new_methane = gas.w;
    let methane_rise_speed = 0.45 * flow_speed; // methane is extremely light, rises very fast
    var m_flow_up = 0.0;
    if (!sol_above) {
        m_flow_up = min(new_methane, 1.0 - g_above_v.w) * methane_rise_speed;
    }
    var m_flow_from_below = 0.0;
    if (!sol_below) {
        m_flow_from_below = min(g_below_v.w, 1.0 - new_methane) * methane_rise_speed;
    }
    new_methane = new_methane - m_flow_up + m_flow_from_below;

    var m_flow_left  = 0.0;
    var m_flow_right = 0.0;
    var m_flow_back  = 0.0;
    var m_flow_front = 0.0;
    let m_spread = 0.15 * flow_speed;
    if (!sol_left)  { m_flow_left  = (gas.w - g_left_v.w)  * m_spread; }
    if (!sol_right) { m_flow_right = (gas.w - g_right_v.w) * m_spread; }
    if (!sol_back)  { m_flow_back  = (gas.w - g_back_v.w)  * m_spread; }
    if (!sol_front) { m_flow_front = (gas.w - g_front_v.w) * m_spread; }
    new_methane -= (m_flow_left + m_flow_right + m_flow_back + m_flow_front);
    if (new_methane < 0.001) { new_methane = 0.0; }


    // --- Mass Transfer from Liquid Phase ---
    let water_here = get_water(local_x, local_y, local_z);
    let evap_mult = 1.0 + max(0.0, local_temp - 20.0) * 0.18;
    let final_evap = u.misc_params.w * evap_mult * 3.5;

    // Steam generation from water evaporation (scaled 3.0x to match loop optimization)
    let evaporated_water = min(water_here.x, 3.0 * final_evap * dt * 50.0);
    new_steam = new_steam + evaporated_water * u.terrain_params3.w;

    // Methane generation from Crude Oil evaporation
    let evaporated_oil = min(water_here.w, final_evap * dt * 15.0 * select(1.0, 5.0, local_temp > 60.0));
    new_methane = new_methane + evaporated_oil * 2.0;

    // Steam generation from Water/Lava reaction
    if (water_here.x > 0.005 && water_here.y > 0.005) {
        let react = min(water_here.x, water_here.y) * 0.85;
        new_steam = new_steam + react * u.terrain_params3.w * 2.0;
    }

    // Acid Fog generation from Acid eating solid walls
    let adjacent_to_solid = sol_left || sol_right || sol_back || sol_front || sol_below || sol_above;
    if (adjacent_to_solid && water_here.z > 0.0) {
        let consumed_acid = min(water_here.z, 0.20 * dt);
        new_fog = new_fog + consumed_acid * 2.5;
    }

    // --- Condensation onto Ceilings & Pressure Waves ---
    var local_pressure = 0.0;
    {
        let max_inst = u32(round(u.suns[0].params.y));
        for (var i = 0u; i < max_inst; i = i + 1u) {
            let inst = u.instances[i];
            let radius = inst.pos_scale.w;
            if (radius <= 0.0) { continue; }
            let dist = length(voxel_pos - inst.pos_scale.xyz);
            if (dist < radius) {
                let weight = 1.0 - (dist / radius);
                local_pressure = local_pressure + inst.interaction_fields.z * weight;
            }
        }
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
    let is_cold = cold_ceiling || (local_temp < 10.0);
    let threshold_mult = select(0.45, 0.15, is_cold);
    let condensation_threshold = u.grid_dims.w * threshold_mult;

    // 1. Steam ceiling condensation
    var total_condensed = 0.0;
    if (near_ceiling && new_steam >= condensation_threshold) {
        let rate_mult = select(1.0, 2.5, is_cold);
        let condensation_rate = 3.0 * 0.75 * dt * u.shadow_ao_quality.w * rate_mult;
        total_condensed = total_condensed + min(new_steam, condensation_rate);
    }

    // 2. Shockwave / Pressure Condensation
    if (local_pressure > 5.0 && new_steam > 0.01) {
        let pressure_condensation_rate = 1.5 * dt * local_pressure;
        total_condensed = total_condensed + min(new_steam - total_condensed, pressure_condensation_rate);
    }
    new_steam = max(0.0, new_steam - total_condensed);

    // 3. Acid Fog ceiling condensation
    if (near_ceiling && new_fog >= condensation_threshold) {
        let rate_mult = select(1.0, 2.5, is_cold);
        let condensation_rate = 3.0 * 0.75 * dt * u.shadow_ao_quality.w * rate_mult;
        new_fog = max(0.0, new_fog - condensation_rate);
    }


    // --- Fuel & Atmospheric Combustion ---
    // Methane combusts instantly if exposed to Lava or high local temperature
    let has_combustion_source = water_here.y > 0.05 || local_temp > 120.0;
    var burned_methane = 0.0;
    if (has_combustion_source && new_methane > 0.0) {
        burned_methane = min(new_methane, 2.5 * dt);
        new_methane = new_methane - burned_methane;
    }

    // Crude Oil burned in liquid pass also generates volcanic smoke/ash
    var burned_oil = 0.0;
    if (has_combustion_source && water_here.w > 0.0) {
        burned_oil = min(water_here.w, 1.8 * dt);
    }

    // Generate Volcanic Ash/Smoke as combustion product
    if (burned_oil > 0.0 || burned_methane > 0.0) {
        new_smoke = new_smoke + burned_oil * 1.5 + burned_methane * 1.8;
    }

    // Dispersal/decay over time
    let decay_rate = select(0.012 * dt, 0.001 * dt, near_ceiling);
    new_steam = max(0.0, new_steam - decay_rate);
    new_smoke = max(0.0, new_smoke - decay_rate * 0.15); // smoke lingers longer
    new_fog = max(0.0, new_fog - decay_rate * 0.50);
    new_methane = max(0.0, new_methane - decay_rate * 0.20);

    // Prevent compiler optimization of gas_texture binding
    let dummy_gas = get_gas(0, 0, 0);
    gas.x = clamp(new_steam, 0.0, 1.0) + dummy_gas.x * 1e-10;
    gas.y = clamp(new_smoke, 0.0, 1.0);
    gas.z = clamp(new_fog, 0.0, 1.0);
    gas.w = clamp(new_methane, 0.0, 1.0);
}
