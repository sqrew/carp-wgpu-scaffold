// physics_rule.wgsl - Native GPU-Resident JIT Shader Injection Loop
// Modifying this file live updates the global physical behaviors of the voxel grid.

// --- Structural Collapse / Exploding Red Stress Blocks ---
if (cell.x < 0.0) {
    // 1. Compressive stress (gravity load): scan upwards
    var gravity_load = 1.0;
    for (var dy = 1; dy <= 12; dy = dy + 1) {
        let voxel = get_voxel(local_x, local_y + dy, local_z);
        if (voxel.x < 0.0) { // Solid
            gravity_load = gravity_load + 1.0;
        } else {
            break;
        }
    }

    // 2. Shear stress: scan below to see if unsupported
    let below_voxel = get_voxel(local_x, local_y - 1, local_z);
    var shear_load = 0.0;
    if (below_voxel.x >= 0.0) { // Air below us (overhang!)
        var min_dist = 999.0;
        // Scan Left (-X)
        for (var dx = 1; dx <= 6; dx = dx + 1) {
            let voxel_here = get_voxel(local_x - dx, local_y, local_z);
            if (voxel_here.x < 0.0) {
                let voxel_below = get_voxel(local_x - dx, local_y - 1, local_z);
                if (voxel_below.x < 0.0) {
                    min_dist = min(min_dist, f32(dx));
                    break;
                }
            } else {
                break;
            }
        }
        // Scan Right (+X)
        for (var dx = 1; dx <= 6; dx = dx + 1) {
            let voxel_here = get_voxel(local_x + dx, local_y, local_z);
            if (voxel_here.x < 0.0) {
                let voxel_below = get_voxel(local_x + dx, local_y - 1, local_z);
                if (voxel_below.x < 0.0) {
                    min_dist = min(min_dist, f32(dx));
                    break;
                }
            } else {
                break;
            }
        }
        // Scan Forward (+Z)
        for (var dz = 1; dz <= 6; dz = dz + 1) {
            let voxel_here = get_voxel(local_x, local_y, local_z + dz);
            if (voxel_here.x < 0.0) {
                let voxel_below = get_voxel(local_x, local_y - 1, local_z + dz);
                if (voxel_below.x < 0.0) {
                    min_dist = min(min_dist, f32(dz));
                    break;
                }
            } else {
                break;
            }
        }
        // Scan Backward (-Z)
        for (var dz = 1; dz <= 6; dz = dz + 1) {
            let voxel_here = get_voxel(local_x, local_y, local_z - dz);
            if (voxel_here.x < 0.0) {
                let voxel_below = get_voxel(local_x, local_y - 1, local_z - dz);
                if (voxel_below.x < 0.0) {
                    min_dist = min(min_dist, f32(dz));
                    break;
                }
            } else {
                break;
            }
        }
        if (min_dist < 999.0) {
            shear_load = min_dist;
        } else {
            shear_load = 6.0;
        }
    }

    let total_stress = (gravity_load - 1.0) + shear_load * 3.0;

    // Critical stress threshold (RED stuff is total_stress >= 14.0)
    if (total_stress >= 14.0) {
        // Slowly dissolve and crumble! (takes ~0.6 seconds of sustained stress to vanish)
        cell.x = cell.x + dt * 2.5; 
        
        // Push downward and outward slightly to simulate collapsing gravel/slump
        cell_velocity += vec3<f32>(
            sin(voxel_pos.x * 20.0) * 1.5,
            -6.0,
            cos(voxel_pos.z * 20.0) * 1.5
        ) * dt * 20.0;
        
        // Visual indicator: turn stressed parts to dark charred debris during crumble
        cell.y = 3.0; 
    }
}
