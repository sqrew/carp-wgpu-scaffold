// interaction_rule.wgsl - Native GPU-Resident JIT Voxel-Interaction Simulation Loop
//
// Input/Output variable is:
//   var fields: vec4<f32>; // (x: Temp, y: Density, z: Stress, w: Material ID)
//
// You also have access to:
//   - `voxel_pos` (vec3<f32> representing the voxel's world space position)
//   - `dt` (f32 time step, e.g., 0.00833)
//   - `get_voxel(x, y, z)`: helper to sample voxel SDF/Materials at absolute chunk coordinates.
//     Returns a vec4<f32> where:
//       - x: SDF distance (negative inside material, positive outside)
//       - y: Material ID of that neighbor
//

let voxel_self = get_voxel(local_x, local_y, local_z);

if (voxel_self.x >= 0.0) {
    // Air has no stress or density
    fields.y = 0.0;
    fields.z = 0.0;
} else {
    // Solid terrain
    var stress = 1.0;
    
    // 1. Compressive Stress (Gravity): Count the number of solid voxels sitting directly above us
    for (var dy = 1; dy <= 12; dy = dy + 1) {
        let v = get_voxel(local_x, local_y + dy, local_z);
        if (v.x < 0.0) {
            stress = stress + 1.0;
        } else {
            break; // Stop scanning if we hit air
        }
    }
    
    // 2. Shear Stress (Overhangs): If unsupported below, find the distance to the nearest vertical support
    let below_voxel = get_voxel(local_x, local_y - 1, local_z);
    if (below_voxel.x >= 0.0) {
        var min_dist = 999.0;
        
        // Scan Left
        for (var dx = 1; dx <= 6; dx = dx + 1) {
            let v_here = get_voxel(local_x - dx, local_y, local_z);
            if (v_here.x < 0.0) {
                let v_below = get_voxel(local_x - dx, local_y - 1, local_z);
                if (v_below.x < 0.0) {
                    min_dist = min(min_dist, f32(dx));
                    break;
                }
            } else {
                break; // Hit air
            }
        }
        
        // Scan Right
        for (var dx = 1; dx <= 6; dx = dx + 1) {
            let v_here = get_voxel(local_x + dx, local_y, local_z);
            if (v_here.x < 0.0) {
                let v_below = get_voxel(local_x + dx, local_y - 1, local_z);
                if (v_below.x < 0.0) {
                    min_dist = min(min_dist, f32(dx));
                    break;
                }
            } else {
                break; // Hit air
            }
        }
        
        // Scan Back
        for (var dz = 1; dz <= 6; dz = dz + 1) {
            let v_here = get_voxel(local_x, local_y, local_z - dz);
            if (v_here.x < 0.0) {
                let v_below = get_voxel(local_x, local_y - 1, local_z - dz);
                if (v_below.x < 0.0) {
                    min_dist = min(min_dist, f32(dz));
                    break;
                }
            } else {
                break; // Hit air
            }
        }
        
        // Scan Front
        for (var dz = 1; dz <= 6; dz = dz + 1) {
            let v_here = get_voxel(local_x, local_y, local_z + dz);
            if (v_here.x < 0.0) {
                let v_below = get_voxel(local_x, local_y - 1, local_z + dz);
                if (v_below.x < 0.0) {
                    min_dist = min(min_dist, f32(dz));
                    break;
                }
            } else {
                break; // Hit air
            }
        }
        
        var shear_stress = 15.0;
        if (min_dist < 999.0) {
            shear_stress = min_dist * 2.5;
        }
        stress = max(stress, shear_stress);
    }
    
    // Clamp stress to avoid infinite build-up and match our scale range [0, 15.0]
    fields.z = min(stress, 15.0);
    fields.y = 1.0; // Density

    // Material thermal conductivity influence (Snow/Ice cools, Lava heats)
    let mat_id = round(abs(voxel_self.y));
    if (mat_id == 6.0) { // Snow / Ice
        fields.x = max(-50.0, fields.x - 35.0 * dt);
    } else if (mat_id == 13.0) { // Lava / Burning embers
        fields.x = min(150.0, fields.x + 90.0 * dt);
    }
}
