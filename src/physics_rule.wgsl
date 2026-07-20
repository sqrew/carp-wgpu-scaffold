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
    
    // Treat unloaded chunk bounds (returning 1.5, 1.0) as solid support to prevent boundary false-collapses
    let is_below_unloaded = (below_voxel.x == 1.5 && below_voxel.y == 1.0);
    
    if (below_voxel.x >= 0.0 && !is_below_unloaded) { // Air below us (overhang!)
        var min_dist = 999.0;
        // Scan Left (-X)
        for (var dx = 1; dx <= 6; dx = dx + 1) {
            let voxel_here = get_voxel(local_x - dx, local_y, local_z);
            let here_unloaded = (voxel_here.x == 1.5 && voxel_here.y == 1.0);
            if (voxel_here.x < 0.0 || here_unloaded) {
                let voxel_below = get_voxel(local_x - dx, local_y - 1, local_z);
                let below_unloaded = (voxel_below.x == 1.5 && voxel_below.y == 1.0);
                if (voxel_below.x < 0.0 || below_unloaded) {
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
            let here_unloaded = (voxel_here.x == 1.5 && voxel_here.y == 1.0);
            if (voxel_here.x < 0.0 || here_unloaded) {
                let voxel_below = get_voxel(local_x + dx, local_y - 1, local_z);
                let below_unloaded = (voxel_below.x == 1.5 && voxel_below.y == 1.0);
                if (voxel_below.x < 0.0 || below_unloaded) {
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
            let here_unloaded = (voxel_here.x == 1.5 && voxel_here.y == 1.0);
            if (voxel_here.x < 0.0 || here_unloaded) {
                let voxel_below = get_voxel(local_x, local_y - 1, local_z + dz);
                let below_unloaded = (voxel_below.x == 1.5 && voxel_below.y == 1.0);
                if (voxel_below.x < 0.0 || below_unloaded) {
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
            let here_unloaded = (voxel_here.x == 1.5 && voxel_here.y == 1.0);
            if (voxel_here.x < 0.0 || here_unloaded) {
                let voxel_below = get_voxel(local_x, local_y - 1, local_z - dz);
                let below_unloaded = (voxel_below.x == 1.5 && voxel_below.y == 1.0);
                if (voxel_below.x < 0.0 || below_unloaded) {
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

    var limit = 14.0;
    let mat = round(cell.y);
    if (mat == 3.0) { // Stone grey
        limit = 24.0;
    } else if (mat == 5.0) { // Sand Beige
        limit = 4.0; // Very weak!
    } else if (mat == 6.0) { // Snow / Ice
        limit = 8.0; 
    } else if (mat == 7.0 || mat == 14.0) { // Obsidian
        limit = 36.0;
    } else if (mat == 12.0) { // Gold / Brass
        limit = 30.0;
    }

    // Critical stress threshold per material ID
    if (total_stress >= limit) {
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

    // --- Water Erosion ---
    // Since water simulation only runs in air/empty voxels, a solid voxel's own water volume is always 0.
    // We check the water volume of the voxels adjacent to it (above and horizontal neighbors).
    let w_above = get_water(local_x, local_y + 1, local_z).x;
    let w_left  = get_water(local_x - 1, local_y, local_z).x;
    let w_right = get_water(local_x + 1, local_y, local_z).x;
    let w_front = get_water(local_x, local_y, local_z - 1).x;
    let w_back  = get_water(local_x, local_y, local_z + 1).x;
    
    let water_vol = max(w_above, max(w_left, max(w_right, max(w_front, w_back))));
    if (water_vol > 0.05) {
        var erosion_rate = 0.25; // default grass/soil erosion (was 0.05)
        if (mat == 3.0) { // Stone
            erosion_rate = 0.06; // stone is hard to erode (was 0.01)
        } else if (mat == 5.0) { // Sand
            erosion_rate = 0.95; // sand washes away immediately! (was 0.35)
        } else if (mat == 7.0 || mat == 14.0) { // Obsidian
            erosion_rate = 0.005; // obsidian is highly resistant (was 0.001)
        }
        
        // Erode density (increment SDF towards empty space)
        cell.x = cell.x + dt * water_vol * erosion_rate * 25.0;
        
        // Turn partially eroded blocks to wet clay/mud (Material 10)
        if (cell.x > -0.2 && cell.x < 0.0 && mat != 10.0) {
            cell.y = 10.0; 
        }
    }
}
