// physics_rule.wgsl - Native GPU-Resident JIT Shader Injection Loop
// Modifying this file live updates the global physical behaviors of the voxel grid.

let solid_thresh = u.terrain_params3.z;

if (cell.y <= solid_thresh) {
    var gravity_load = 1.0;
    for (var dy = 1; dy <= 12; dy = dy + 1) {
        let voxel = get_voxel(local_x, local_y + dy, local_z);
        if (voxel.y <= solid_thresh) { // Solid
            let top_mat = round(abs(voxel.x));
            let top_props = get_material_properties(top_mat);
            gravity_load = gravity_load + top_props.density;
        } else {
            break;
        }
    }

    // 2. Shear stress: scan below to see if unsupported
    let below_voxel = get_voxel(local_x, local_y - 1, local_z);
    var shear_load = 0.0;
    
    // Treat unloaded chunk bounds (returning 1.5, 1.0) as solid support to prevent boundary false-collapses
    let is_below_unloaded = (below_voxel.y <= solid_thresh && below_voxel.x == 1.5);
    
    if (below_voxel.y > solid_thresh && !is_below_unloaded) { // Air below us (overhang!)
        var min_dist = 999.0;
        // Scan Left (-X)
        for (var dx = 1; dx <= 6; dx = dx + 1) {
            let voxel_here = get_voxel(local_x - dx, local_y, local_z);
            let here_unloaded = (voxel_here.y <= solid_thresh && voxel_here.x == 1.5);
            if (voxel_here.y <= solid_thresh || here_unloaded) {
                let voxel_below = get_voxel(local_x - dx, local_y - 1, local_z);
                let below_unloaded = (voxel_below.y <= solid_thresh && voxel_below.x == 1.5);
                if (voxel_below.y <= solid_thresh || below_unloaded) {
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
            let here_unloaded = (voxel_here.y <= solid_thresh && voxel_here.x == 1.5);
            if (voxel_here.y <= solid_thresh || here_unloaded) {
                let voxel_below = get_voxel(local_x + dx, local_y - 1, local_z);
                let below_unloaded = (voxel_below.y <= solid_thresh && voxel_below.x == 1.5);
                if (voxel_below.y <= solid_thresh || below_unloaded) {
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
            let here_unloaded = (voxel_here.y <= solid_thresh && voxel_here.x == 1.5);
            if (voxel_here.y <= solid_thresh || here_unloaded) {
                let voxel_below = get_voxel(local_x, local_y - 1, local_z + dz);
                let below_unloaded = (voxel_below.y <= solid_thresh && voxel_below.x == 1.5);
                if (voxel_below.y <= solid_thresh || below_unloaded) {
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
            let here_unloaded = (voxel_here.y <= solid_thresh && voxel_here.x == 1.5);
            if (voxel_here.y <= solid_thresh || here_unloaded) {
                let voxel_below = get_voxel(local_x, local_y - 1, local_z - dz);
                let below_unloaded = (voxel_below.y <= solid_thresh && voxel_below.x == 1.5);
                if (voxel_below.y <= solid_thresh || below_unloaded) {
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

    // Reduced coefficients (gravity * 0.4, shear * 1.2) to allow natural terrain overhangs
    // and arches to stand stable, while still slumping under heavy structural loads.
    let total_stress = (gravity_load - 1.0) * 0.4 + shear_load * 1.2;
    let mat = round(abs(cell.x));
    let props = get_material_properties(mat);
    let limit = props.strength;

    if (cell.x < 0.0) {
        let below = get_voxel(local_x, local_y - 1, local_z);
        let solid_thresh_check = u.terrain_params3.z;
        if (below.y > solid_thresh_check && below.x != 1.5) {
            // Fall straight down
            cell.x = 0.0; // Air ID
            cell.y = 0.5; // open density
        } else {
            // Try sliding diagonally below in 4 directions
            let below_r = get_voxel(local_x + 1, local_y - 1, local_z);
            let below_l = get_voxel(local_x - 1, local_y - 1, local_z);
            let below_b = get_voxel(local_x, local_y - 1, local_z - 1);
            let below_f = get_voxel(local_x, local_y - 1, local_z + 1);
            
            if (below_r.y > solid_thresh_check && below_r.x != 1.5) {
                cell.x = 0.0;
                cell.y = 0.5;
            } else if (below_l.y > solid_thresh_check && below_l.x != 1.5) {
                cell.x = 0.0;
                cell.y = 0.5;
            } else if (below_b.y > solid_thresh_check && below_b.x != 1.5) {
                cell.x = 0.0;
                cell.y = 0.5;
            } else if (below_f.y > solid_thresh_check && below_f.x != 1.5) {
                cell.x = 0.0;
                cell.y = 0.5;
            } else {
                cell.x = abs(cell.x); // stabilize and land!
            }
        }
    } else {
        if (total_stress >= limit && shear_load > 0.5) {
            cell_velocity += vec3<f32>(
                sin(voxel_pos.x * 20.0) * 1.5,
                -6.0,
                cos(voxel_pos.z * 20.0) * 1.5
            ) * dt * 20.0;
            cell.x = -abs(cell.x); // start crumbling!
        }

        // --- Water Erosion ---
        let w_above_val = get_water(local_x, local_y + 1, local_z);
        let w_left_val  = get_water(local_x - 1, local_y, local_z);
        let w_right_val = get_water(local_x + 1, local_y, local_z);
        let w_front_val = get_water(local_x, local_y, local_z - 1);
        let w_back_val  = get_water(local_x, local_y, local_z + 1);
        
        let w_above = select(0.0, w_above_val.y, round(w_above_val.x) == 1.0);
        let w_left  = select(0.0, w_left_val.y,  round(w_left_val.x) == 1.0);
        let w_right = select(0.0, w_right_val.y, round(w_right_val.x) == 1.0);
        let w_front = select(0.0, w_front_val.y, round(w_front_val.x) == 1.0);
        let w_back  = select(0.0, w_back_val.y,  round(w_back_val.x) == 1.0);
        
        let water_vol = max(w_above, max(w_left, max(w_right, max(w_front, w_back))));
        if (water_vol > 0.05) {
            let erosion_rate = props.erosion_rate;
            let stress_factor = 1.0 + clamp((total_stress - limit) / limit, 0.0, 2.0);
            let actual_erosion = erosion_rate * stress_factor;
            cell.y = cell.y + dt * water_vol * actual_erosion * 2.5 * u.misc_params.z;
            
            if (cell.y > -0.2 && cell.y < 0.0 && mat != 10.0) {
                cell.x = 10.0; // clay
            }
        }
    }
}

// --- Lava Solidification & Falling Material (Runs in air cells) ---
if (cell.y > solid_thresh) {
    let water_here = get_water(local_x, local_y, local_z);
    
    // If we are Lava and contact Water neighbor, or if we are Water and contact Lava neighbor
    let is_lava = round(water_here.x) == 2.0 && water_here.y > 0.08;
    
    var has_water_neighbor = false;
    if (is_lava) {
        has_water_neighbor = 
            round(get_water(local_x - 1, local_y, local_z).x) == 1.0 ||
            round(get_water(local_x + 1, local_y, local_z).x) == 1.0 ||
            round(get_water(local_x, local_y - 1, local_z).x) == 1.0 ||
            round(get_water(local_x, local_y + 1, local_z).x) == 1.0 ||
            round(get_water(local_x, local_y, local_z - 1).x) == 1.0 ||
            round(get_water(local_x, local_y, local_z + 1).x) == 1.0;
    }
    
    if (is_lava && has_water_neighbor) {
        cell.y = -0.6; // turn to solid!
        cell.x = 7.0;  // Volcanic Obsidian
    } else {
        // Receive falling material
        var incoming_cell = vec4<f32>(0.0);
        var has_incoming = false;
        
        // 1. Check directly above
        let above = get_voxel(local_x, local_y + 1, local_z);
        if (above.y <= solid_thresh && above.x < 0.0) {
            incoming_cell = above;
            has_incoming = true;
        } else {
            // 2. Check left-above (slides into us because its directly-below is solid)
            let la = get_voxel(local_x - 1, local_y + 1, local_z);
            let la_below = get_voxel(local_x - 1, local_y, local_z);
            if (la.y <= solid_thresh && la.x < 0.0 && la_below.y <= solid_thresh) {
                incoming_cell = la;
                has_incoming = true;
            } else {
                // 3. Check right-above (slides into us because its directly-below is solid)
                let ra = get_voxel(local_x + 1, local_y + 1, local_z);
                let ra_below = get_voxel(local_x + 1, local_y, local_z);
                if (ra.y <= solid_thresh && ra.x < 0.0 && ra_below.y <= solid_thresh) {
                    incoming_cell = ra;
                    has_incoming = true;
                } else {
                    // 4. Check back-above (slides into us because its directly-below is solid)
                    let ba = get_voxel(local_x, local_y + 1, local_z - 1);
                    let ba_below = get_voxel(local_x, local_y, local_z - 1);
                    if (ba.y <= solid_thresh && ba.x < 0.0 && ba_below.y <= solid_thresh) {
                        incoming_cell = ba;
                        has_incoming = true;
                    } else {
                        // 5. Check front-above (slides into us because its directly-below is solid)
                        let fa = get_voxel(local_x, local_y + 1, local_z + 1);
                        let fa_below = get_voxel(local_x, local_y, local_z + 1);
                        if (fa.y <= solid_thresh && fa.x < 0.0 && fa_below.y <= solid_thresh) {
                            incoming_cell = fa;
                            has_incoming = true;
                        }
                    }
                }
            }
        }
        
        if (has_incoming) {
            let below = get_voxel(local_x, local_y - 1, local_z);
            if (below.y > solid_thresh && below.x != 1.5) {
                // Keep falling down
                cell.x = incoming_cell.x;
                cell.y = incoming_cell.y;
            } else {
                // Land and solidify!
                cell.x = abs(incoming_cell.x);
                cell.y = incoming_cell.y;
            }
        }
    }
}

if (cell.y <= solid_thresh) {
    let mat = round(abs(cell.x));
    let props = get_material_properties(mat);
    
    // Acid eating walls
    let a_above_val = get_water(local_x, local_y + 1, local_z);
    let a_left_val  = get_water(local_x - 1, local_y, local_z);
    let a_right_val = get_water(local_x + 1, local_y, local_z);
    let a_front_val = get_water(local_x, local_y, local_z - 1);
    let a_back_val  = get_water(local_x, local_y, local_z + 1);
    
    let a_above = select(0.0, a_above_val.y, round(a_above_val.x) == 3.0);
    let a_left  = select(0.0, a_left_val.y,  round(a_left_val.x) == 3.0);
    let a_right = select(0.0, a_right_val.y, round(a_right_val.x) == 3.0);
    let a_front = select(0.0, a_front_val.y, round(a_front_val.x) == 3.0);
    let a_back = select(0.0, a_back_val.y,  round(a_back_val.x) == 3.0);
    
    let acid_vol = max(a_above, max(a_left, max(a_right, max(a_front, a_back))));
    if (acid_vol > 0.05) {
        // Acid corrosion speed scaled by material vulnerability
        let corrosion_speed = 15.0 * (1.0 - props.acid_resist);
        cell.y = cell.y + dt * acid_vol * corrosion_speed;
    }

    // Lava melting walls
    let l_above_val = get_water(local_x, local_y + 1, local_z);
    let l_left_val  = get_water(local_x - 1, local_y, local_z);
    let l_right_val = get_water(local_x + 1, local_y, local_z);
    let l_front_val = get_water(local_x, local_y, local_z - 1);
    let l_back_val  = get_water(local_x, local_y, local_z + 1);
    
    let l_above = select(0.0, l_above_val.y, round(l_above_val.x) == 2.0);
    let l_left  = select(0.0, l_left_val.y,  round(l_left_val.x) == 2.0);
    let l_right = select(0.0, l_right_val.y, round(l_right_val.x) == 2.0);
    let l_front = select(0.0, l_front_val.y, round(l_front_val.x) == 2.0);
    let l_back  = select(0.0, l_back_val.y,  round(l_back_val.x) == 2.0);
    
    let lava_vol = max(l_above, max(l_left, max(l_right, max(l_front, l_back))));
    if (lava_vol > 0.05 && props.melt_speed > 0.0) {
        cell.y = cell.y + dt * lava_vol * props.melt_speed;
    }
}

// Prevent compiler optimization of gas_texture binding
let dummy_gas = get_gas(0, 0, 0);
cell.x = cell.x + dummy_gas.x * 1e-10;
