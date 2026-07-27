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

// 3. Fluid Heat Interaction (Water cools, Lava heats, Steam warms)
let water_here = get_water(local_x, local_y, local_z);
let gas_here = get_gas(local_x, local_y, local_z);

let w_water = water_here.x;
let w_lava = water_here.y;
let g_steam = gas_here.x;

if (w_lava > 0.05) {
    fields.x = min(150.0, fields.x + w_lava * 120.0 * dt);
} else if (w_water > 0.05) {
    fields.x = max(15.0, fields.x - w_water * 50.0 * dt);
} else if (g_steam > 0.05) {
    fields.x = min(90.0, fields.x + g_steam * 25.0 * dt);
}

// 4. Thermal Diffusion & Ambient Decay (executed for all voxels)
var temp_sum = 0.0;
var count = 0.0;

let directions = array<vec3<i32>, 6>(
    vec3<i32>(-1, 0, 0), vec3<i32>(1, 0, 0),
    vec3<i32>(0, -1, 0), vec3<i32>(0, 1, 0),
    vec3<i32>(0, 0, -1), vec3<i32>(0, 0, 1)
);

for (var i = 0; i < 6; i = i + 1) {
    let nx = local_x + directions[i].x;
    let ny = local_y + directions[i].y;
    let nz = local_z + directions[i].z;
    
    if (nx >= 0 && nx < 32 && ny >= 0 && ny < 32 && nz >= 0 && nz < 32) {
        let n_idx = u32(nx + ny * 32 + nz * 1024);
        temp_sum = temp_sum + input_fields[n_idx].x;
        count = count + 1.0;
    } else {
        // Adiabatic boundary (insulated chunk edges)
        temp_sum = temp_sum + fields.x;
        count = count + 1.0;
    }
}

let avg_neighbor_temp = temp_sum / count;

// Heat diffusion (conduction) rate (1.5)
fields.x = fields.x + (avg_neighbor_temp - fields.x) * 1.5 * dt;

// Slow decay towards ambient temperature (20.0 C)
fields.x = fields.x + (20.0 - fields.x) * 0.05 * dt;
