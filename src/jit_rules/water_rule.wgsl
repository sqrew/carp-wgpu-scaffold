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
    // Fetch 6 cardinal neighbor water volumes using our boundary-aware function
    let w_below  = get_water_volume(local_x, local_y - 1, local_z);
    let w_below2 = get_water_volume(local_x, local_y - 2, local_z);
    let w_above  = get_water_volume(local_x, local_y + 1, local_z);
    let w_left   = get_water_volume(local_x - 1, local_y, local_z);
    let w_right  = get_water_volume(local_x + 1, local_y, local_z);
    let w_back   = get_water_volume(local_x, local_y, local_z - 1);
    let w_front  = get_water_volume(local_x, local_y, local_z + 1);

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


    // --- Evaporation modulated by local heat (Inlined loop for WGSL function scope rules) ---
    var local_temp = 0.0;
    var total_weight = 0.0;
    for (var i = 0u; i < 512u; i = i + 1u) {
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
    var my_humidity = water.y + evaporated_volume * 2.2;

    // --- Humidity Rising cellular automata flow ---
    let flow_up_speed = 0.22 * flow_speed;
    var flow_up = 0.0;
    if (!sol_above) {
        flow_up = my_humidity * flow_up_speed;
        my_humidity = my_humidity - flow_up;
    }
    
    var flow_from_below = 0.0;
    if (!sol_below) {
        let below_vec = get_water(local_x, local_y - 1, local_z);
        flow_from_below = below_vec.y * flow_up_speed;
        my_humidity = my_humidity + flow_from_below;
    }

    // --- Humidity horizontal diffusion (cloud spreading) ---
    let diffuse_rate = 0.06 * flow_speed;
    let h_left = get_water(local_x - 1, local_y, local_z).y;
    let h_right = get_water(local_x + 1, local_y, local_z).y;
    let h_front = get_water(local_x, local_y, local_z + 1).y;
    let h_back = get_water(local_x, local_y, local_z - 1).y;
    
    let hum_flow_left = (water.y - h_left) * diffuse_rate;
    let hum_flow_right = (water.y - h_right) * diffuse_rate;
    let hum_flow_front = (water.y - h_front) * diffuse_rate;
    let hum_flow_back = (water.y - h_back) * diffuse_rate;
    
    my_humidity = my_humidity - (hum_flow_left + hum_flow_right + hum_flow_front + hum_flow_back);

    // --- Cavern ceiling or high saturation condensation (Vapor -> Liquid) ---
    // Under ceilings, we condense extremely fast so that we accumulate discrete, large droplets
    // that are heavy enough to trigger gravity flow downward instead of instantly dissipating.
    if (sol_above || my_humidity >= 0.82) {
        let condensation_rate = select(0.06 * dt, 0.75 * dt * 18.0, sol_above);
        let condensed = min(my_humidity, condensation_rate);
        new_volume = new_volume + condensed * 0.88; // convert back to liquid
        my_humidity = my_humidity - condensed;
    }

    // Dispersal/decay over time
    my_humidity = max(0.0, my_humidity - 0.012 * dt);

    // Keep volume bounded and clear tiny values to allow evaporation/drying
    if (new_volume < 0.001) {
        new_volume = 0.0;
    }
    water.x = clamp(new_volume, 0.0, 1.0);
    water.y = clamp(my_humidity, 0.0, 1.0);
}
