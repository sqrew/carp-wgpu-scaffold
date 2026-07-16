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
    let w_below = get_water_volume(local_x, local_y - 1, local_z);
    let w_above = get_water_volume(local_x, local_y + 1, local_z);
    let w_left  = get_water_volume(local_x - 1, local_y, local_z);
    let w_right = get_water_volume(local_x + 1, local_y, local_z);
    let w_back  = get_water_volume(local_x, local_y, local_z - 1);
    let w_front = get_water_volume(local_x, local_y, local_z + 1);

    // Check voxel solidity for neighbors (SDF <= 0.08 is solid)
    let sol_below = get_voxel(local_x, local_y - 1, local_z).x <= 0.08;
    let sol_above = get_voxel(local_x, local_y + 1, local_z).x <= 0.08;
    let sol_left  = get_voxel(local_x - 1, local_y, local_z).x <= 0.08;
    let sol_right = get_voxel(local_x + 1, local_y, local_z).x <= 0.08;
    let sol_back  = get_voxel(local_x, local_y, local_z - 1).x <= 0.08;
    let sol_front = get_voxel(local_x, local_y, local_z + 1).x <= 0.08;

    var new_volume = water.x;

    // --- 1. Downward flow (Gravity) ---
    // Water flows down to fill the empty space below (speed = 0.5 per tick)
    if (!sol_below) {
        let flow_down = min(new_volume, 1.0 - w_below) * 0.5;
        new_volume -= flow_down;
    }
    if (!sol_above) {
        let flow_from_above = min(w_above, 1.0 - new_volume) * 0.5;
        new_volume += flow_from_above;
    }

    // --- 2. Horizontal spreading (Pressure / Height Equalization) ---
    // Only spread horizontally if we have water and we are sitting on a solid floor or water (> 0.01)
    if (new_volume > 0.001 && (sol_below || w_below > 0.01)) {
        var open_neighbors = 0.0;
        var total_neighbor_water = 0.0;
        
        if (!sol_left  && w_left < new_volume)  { open_neighbors += 1.0; total_neighbor_water += w_left; }
        if (!sol_right && w_right < new_volume) { open_neighbors += 1.0; total_neighbor_water += w_right; }
        if (!sol_back  && w_back < new_volume)  { open_neighbors += 1.0; total_neighbor_water += w_back; }
        if (!sol_front && w_front < new_volume) { open_neighbors += 1.0; total_neighbor_water += w_front; }
        
        if (open_neighbors > 0.0) {
            let avg = (new_volume + total_neighbor_water) / (open_neighbors + 1.0);
            let spread_factor = 0.35; // Control spreading speed
            let flow = (new_volume - avg) * spread_factor;
            new_volume -= flow * open_neighbors;
        }
    }
    
    // Inflow from horizontal neighbors that have more water
    if (new_volume < 1.0 && (sol_below || w_below > 0.01)) {
        var inflow = 0.0;
        let spread_factor = 0.35;
        
        if (!sol_left  && w_left > new_volume)  { inflow += (w_left - new_volume) * spread_factor; }
        if (!sol_right && w_right > new_volume) { inflow += (w_right - new_volume) * spread_factor; }
        if (!sol_back  && w_back > new_volume)  { inflow += (w_back - new_volume) * spread_factor; }
        if (!sol_front && w_front > new_volume) { inflow += (w_front - new_volume) * spread_factor; }
        
        new_volume += inflow;
    }

    // Keep volume bounded
    water.x = clamp(new_volume, 0.0, 1.0);
}
