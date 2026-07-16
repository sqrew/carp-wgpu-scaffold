// water_rule.wgsl - Native GPU-Resident JIT Water cellular automata & fluid loop.
//
// Input/Output variable is:
//   var water: vec4<f32>; // (x: Volume fraction [0..1], y,z,w: Velocity vector)
//
// Injected code here executes per-voxel. Use `water` to modify fluid simulation state.
//

let self_voxel = get_voxel(local_x, local_y, local_z);

// If the voxel is solid (SDF <= 0.0), it cannot contain water
if (self_voxel.x <= 0.0) {
    water = vec4<f32>(0.0);
} else {
    // 3D grid dimensions
    let chunk_w = 32;
    let chunk_h = 32;
    let chunk_d = 32;

    let idx_i = i32(idx);

    // Fetch 6 cardinal neighbor water volumes
    var w_below = 0.0;
    var w_above = 0.0;
    var w_left  = 0.0;
    var w_right = 0.0;
    var w_back  = 0.0;
    var w_front = 0.0;

    // Check voxel solidity for neighbors to prevent water flowing into walls
    let sol_below = get_voxel(local_x, local_y - 1, local_z).x <= 0.0;
    let sol_above = get_voxel(local_x, local_y + 1, local_z).x <= 0.0;
    let sol_left  = get_voxel(local_x - 1, local_y, local_z).x <= 0.0;
    let sol_right = get_voxel(local_x + 1, local_y, local_z).x <= 0.0;
    let sol_back  = get_voxel(local_x, local_y, local_z - 1).x <= 0.0;
    let sol_front = get_voxel(local_x, local_y, local_z + 1).x <= 0.0;

    if (local_y > 0 && !sol_below) {
        w_below = input_fields[idx_i - chunk_w].x;
    }
    if (local_y < chunk_h - 1 && !sol_above) {
        w_above = input_fields[idx_i + chunk_w].x;
    }
    if (local_x > 0 && !sol_left) {
        w_left = input_fields[idx_i - 1].x;
    }
    if (local_x < chunk_w - 1 && !sol_right) {
        w_right = input_fields[idx_i + 1].x;
    }
    if (local_z > 0 && !sol_back) {
        w_back = input_fields[idx_i - (chunk_w * chunk_h)].x;
    }
    if (local_z < chunk_d - 1 && !sol_front) {
        w_front = input_fields[idx_i + (chunk_w * chunk_h)].x;
    }

    var new_volume = water.x;

    // --- 1. Downward flow (Gravity) ---
    // Water flows down to fill the empty space below
    let gravity_factor = 0.4; 
    
    // We give water to the cell below
    if (local_y > 0 && !sol_below) {
        let flow_down = min(water.x, 1.0 - w_below) * gravity_factor;
        new_volume -= flow_down;
    }
    // We receive water from the cell above
    if (local_y < chunk_h - 1 && !sol_above) {
        let flow_from_above = min(w_above, 1.0 - water.x) * gravity_factor;
        new_volume += flow_from_above;
    }

    // --- 2. Horizontal flow (Pressure / Diffusion) ---
    // Water spreads out horizontally if it cannot flow downwards
    // Only diffuse horizontal water if we are sitting on a solid floor or another water block
    if (local_y == 0 || sol_below || w_below > 0.9) {
        let spread_factor = 0.12;
        
        // Left
        if (local_x > 0 && !sol_left) {
            let diff = new_volume - w_left;
            if (diff > 0.0) {
                new_volume -= diff * spread_factor;
            } else {
                new_volume += (-diff) * spread_factor;
            }
        }
        // Right
        if (local_x < chunk_w - 1 && !sol_right) {
            let diff = new_volume - w_right;
            if (diff > 0.0) {
                new_volume -= diff * spread_factor;
            } else {
                new_volume += (-diff) * spread_factor;
            }
        }
        // Back
        if (local_z > 0 && !sol_back) {
            let diff = new_volume - w_back;
            if (diff > 0.0) {
                new_volume -= diff * spread_factor;
            } else {
                new_volume += (-diff) * spread_factor;
            }
        }
        // Front
        if (local_z < chunk_d - 1 && !sol_front) {
            let diff = new_volume - w_front;
            if (diff > 0.0) {
                new_volume -= diff * spread_factor;
            } else {
                new_volume += (-diff) * spread_factor;
            }
        }
    }

    // Keep volume bounded
    water.x = clamp(new_volume, 0.0, 1.0);
}
