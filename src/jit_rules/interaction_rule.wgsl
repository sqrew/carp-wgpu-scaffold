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
    // Air has no stress or shear/fatigue
    fields.y = 0.0;
    fields.z = 0.0;
    fields.w = 0.0;
} else {
    // Solid terrain
    let mat_id = round(abs(voxel_self.y));
    let props = get_material_properties(mat_id);
    let ix = local_x;
    let iy = local_y;
    let iz = local_z;
    
    // 1. CA-Based Compressive Stress Propagation (Gravity)
    var stress = props.density;
    
    // Get load from directly above
    let above_y = iy + 1;
    if (above_y < 32) {
        let above_idx = u32(ix + above_y * 32 + iz * 1024);
        let above_voxel = get_voxel(ix, above_y, iz);
        if (above_voxel.x < 0.0) {
            stress = stress + input_fields[above_idx].z;
        }
    }
    
    // Gather redistributed load from neighboring overhangs
    var redistributed_load = 0.0;
    let horiz_dirs = array<vec3<i32>, 4>(
        vec3<i32>(-1, 0, 0), vec3<i32>(1, 0, 0),
        vec3<i32>(0, 0, -1), vec3<i32>(0, 0, 1)
    );
    
    for (var i = 0; i < 4; i = i + 1) {
        let nx = ix + horiz_dirs[i].x;
        let nz = iz + horiz_dirs[i].z;
        if (nx >= 0 && nx < 32 && nz >= 0 && nz < 32) {
            let n_voxel = get_voxel(nx, iy, nz);
            if (n_voxel.x < 0.0) {
                let n_below_voxel = get_voxel(nx, iy - 1, nz);
                if (n_below_voxel.x >= 0.0) {
                    var solid_count = 0.0;
                    for (var j = 0; j < 4; j = j + 1) {
                        let nnx = nx + horiz_dirs[j].x;
                        let nnz = nz + horiz_dirs[j].z;
                        if (nnx >= 0 && nnx < 32 && nnz >= 0 && nnz < 32) {
                            let nn_voxel = get_voxel(nnx, iy, nnz);
                            if (nn_voxel.x < 0.0) {
                                solid_count = solid_count + 1.0;
                            }
                        }
                    }
                    if (solid_count > 0.0) {
                        let n_idx = u32(nx + iy * 32 + nz * 1024);
                        var neighbor_load = get_material_properties(round(abs(n_voxel.y))).density;
                        if (above_y < 32) {
                            let n_above_idx = u32(nx + above_y * 32 + nz * 1024);
                            let n_above_voxel = get_voxel(nx, above_y, nz);
                            if (n_above_voxel.x < 0.0) {
                                neighbor_load = neighbor_load + input_fields[n_above_idx].z;
                            }
                        }
                        redistributed_load = redistributed_load + (neighbor_load / solid_count);
                    }
                }
            }
        }
    }
    stress = stress + redistributed_load;
    
    // 2. CA-Based Shear Stress Propagation (Bending Moment)
    var shear_stress = 0.0;
    let below_voxel = get_voxel(ix, iy - 1, iz);
    if (below_voxel.x >= 0.0) {
        var max_neighbor_shear = 0.0;
        for (var i = 0; i < 4; i = i + 1) {
            let nx = ix + horiz_dirs[i].x;
            let nz = iz + horiz_dirs[i].z;
            if (nx >= 0 && nx < 32 && nz >= 0 && nz < 32) {
                let n_voxel = get_voxel(nx, iy, nz);
                if (n_voxel.x < 0.0) {
                    let n_idx = u32(nx + iy * 32 + nz * 1024);
                    max_neighbor_shear = max(max_neighbor_shear, input_fields[n_idx].y);
                }
            }
        }
        shear_stress = 2.0 + max_neighbor_shear;
    } else {
        shear_stress = max(0.0, fields.y - 5.0 * dt);
    }
    
    fields.z = min(stress, 15.0);
    fields.y = min(shear_stress, 15.0);
    
    // 3. Accumulate Structural Fatigue / Damage (with Thermal Shock & Weakening)
    var fatigue = fields.w;
    let limit = props.strength;
    
    var temp_grad = 0.0;
    var temp_count = 0.0;
    for (var i = 0; i < 4; i = i + 1) {
        let nx = ix + horiz_dirs[i].x;
        let nz = iz + horiz_dirs[i].z;
        if (nx >= 0 && nx < 32 && nz >= 0 && nz < 32) {
            let n_voxel = get_voxel(nx, iy, nz);
            if (n_voxel.x < 0.0) {
                let n_idx = u32(nx + iy * 32 + nz * 1024);
                temp_grad = temp_grad + abs(input_fields[n_idx].x - fields.x);
                temp_count = temp_count + 1.0;
            }
        }
    }
    var thermal_stress = 0.0;
    if (temp_count > 0.0) {
        thermal_stress = (temp_grad / temp_count) * 0.4;
    }
    
    var effective_limit = limit;
    if (props.melt_temp < 9000.0) {
        let temp_ratio = clamp(fields.x / props.melt_temp, 0.0, 1.0);
        effective_limit = limit * (1.0 - temp_ratio * 0.85);
    }
    
    let total_stress = (fields.z - 1.0) * 0.5 + fields.y * 3.0 + thermal_stress;
    let fatigue_threshold = effective_limit * 0.65;
    if (total_stress >= fatigue_threshold) {
        let excess = total_stress - fatigue_threshold;
        fatigue = fatigue + (0.3 + excess * 0.2) * dt;
    } else {
        fatigue = fatigue - 0.05 * dt;
    }
    fields.w = clamp(fatigue, 0.0, 1.0);

    // Material thermal conductivity influence (Snow/Ice cools, Lava heats)
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
