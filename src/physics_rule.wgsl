// physics_rule.wgsl - Native GPU-Resident JIT Shader Injection Loop
// Modifying this file live updates the global physical behaviors of the voxel grid.
// Leaving this file empty (or deleting all active code) resets the simulation back to normal.
//
// === Available Context Variables ===
// - idx       : u32              -> 1D index of the current voxel cell (0 to 32767)
// - cell      : vec4<f32>        -> Voxel cell attributes:
//                                    - cell.x: Signed Distance Field (SDF / Density).
//                                              Negative values are solid space, positive values are empty air.
//                                    - cell.y: Material ID (e.g. 2.0 = green grass).
//                                    - cell.z: Ambient Occlusion / Lighting visibility.
//                                    - cell.w: Metadata.
// - dt        : f32              -> Physics simulation timestep delta (constant ~0.00833)
// - u.time    : f32              -> Accumulated simulation runtime in seconds
// - u.cam_pos : vec4<f32>        -> Player / camera position
// - voxel_pos : vec3<f32>        -> 3D world space coordinate of this voxel
// - cell_velocity : vec3<f32>    -> Velocity vector of this cell

// --- Dynamic Pressure-Based Terrain Displacement & Charring ---
// for (var i = 0u; i < 512u; i = i + 1u) {
//     let inst = u.instances[i];
//     if (inst.pos_scale.w <= 0.0) { break; } // End of active list
    
//     // light_fields.w is used to store pressure/force values
//     let pressure = inst.light_fields.w;
//     if (pressure > 0.0) {
//         let to_voxel = voxel_pos - inst.pos_scale.xyz;
//         let dist = length(to_voxel);
        
//         if (dist < inst.pos_scale.w) {
//             let falloff = 1.0 - (dist / inst.pos_scale.w);
            
//             // Push the SDF density outward (carving a physical crater)
//             let push_force = pressure * falloff * dt * 45.0;
//             cell.x += push_force;
            
//             // Apply outward kinetic velocity to cell's internal flow
//             cell_velocity += normalize(to_voxel + vec3<f32>(0.0, 0.01, 0.0)) * pressure * falloff * 8.0;
            
//             // Char the surface of the blasted crater (Material ID 3.0 = dark charred rock)
//             if (cell.x < 0.0 && falloff > 0.4) {
//                 cell.y = 3.0; 
//             }
//         }
//     }
// }



// Sample density (SDF) of the center voxel and its 6 cardially adjacent neighbors
// let center = get_voxel(local_x, local_y, local_z).x;
// let left   = get_voxel(local_x - 1, local_y, local_z).x;
// let right  = get_voxel(local_x + 1, local_y, local_z).x;
// let bottom = get_voxel(local_x, local_y - 1, local_z).x;
// let top    = get_voxel(local_x, local_y + 1, local_z).x;
// let back   = get_voxel(local_x, local_y, local_z - 1).x;
// let front  = get_voxel(local_x, local_y, local_z + 1).x;

// Apply thermal/density diffusion (Laplacian smoothing)
// let average = (left + right + bottom + top + back + front) / 6.0;

// Slowly blend the current voxel's density towards the average neighbor state
// cell.x = mix(center, average, dt * 2.0);
