// water_rule.wgsl - Native GPU-Resident JIT Water cellular automata & fluid loop.
//
// Input/Output variable is:
//   var water: vec4<f32>; // (x: Volume fraction [0..1], y,z,w: Velocity vector)
//
// Injected code here executes per-voxel. Use `water` to modify fluid simulation state.
//

let self_voxel = get_voxel(local_x, local_y, local_z);

// If the voxel is solid (SDF <= 0.08), it cannot contain water
if (self_voxel.x <= 0.08) {
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

    // Check voxel solidity for neighbors (SDF <= 0.08 is solid)
    let sol_below  = get_voxel(local_x, local_y - 1, local_z).x <= 0.08;
    let sol_below2 = get_voxel(local_x, local_y - 2, local_z).x <= 0.08;
    let sol_above  = get_voxel(local_x, local_y + 1, local_z).x <= 0.08;
    let sol_left  = get_voxel(local_x - 1, local_y, local_z).x <= 0.08;
    let sol_right = get_voxel(local_x + 1, local_y, local_z).x <= 0.08;
    let sol_back  = get_voxel(local_x, local_y, local_z - 1).x <= 0.08;
    let sol_front = get_voxel(local_x, local_y, local_z + 1).x <= 0.08;
    
    var new_volume = water.x;
    
    // --- 1. Downward flow (Gravity with look-ahead) ---
    var flow_down_below = 0.0;
    if (!sol_below && !sol_below2) {
        flow_down_below = min(w_below, 1.0 - w_below2);
    }
    
    var flow_down = 0.0;
    if (!sol_below) {
        flow_down = min(new_volume, 1.0 - w_below + flow_down_below);
    }
    
    var flow_from_above = 0.0;
    if (!sol_above) {
        var flow_self_below = 0.0;
        if (!sol_below) {
            flow_self_below = min(new_volume, 1.0 - w_below);
        }
        flow_from_above = min(w_above, 1.0 - new_volume + flow_self_below);
    }
    
    new_volume = new_volume - flow_down + flow_from_above;

    // --- 2. Horizontal spreading (Height Equalization) ---
    var flow_left  = 0.0;
    var flow_right = 0.0;
    var flow_back  = 0.0;
    var flow_front = 0.0;
    
    let spread_factor = 0.15;
    if (!sol_left)  { flow_left  = (water.x - w_left)  * spread_factor; }
    if (!sol_right) { flow_right = (water.x - w_right) * spread_factor; }
    if (!sol_back)  { flow_back  = (water.x - w_back)  * spread_factor; }
    if (!sol_front) { flow_front = (water.x - w_front) * spread_factor; }
    
    new_volume -= (flow_left + flow_right + flow_back + flow_front);

    // Keep volume bounded and clear tiny values to allow evaporation/drying
    if (new_volume < 0.005) {
        new_volume = 0.0;
    }
    water.x = clamp(new_volume, 0.0, 1.0);
}
