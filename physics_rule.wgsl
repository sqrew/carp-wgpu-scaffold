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
//
// === Examples (Uncomment to play) ===

// --- Example 1: Sinusoidal Terrain Waving ---
/// cell.x = sin(u.time + (f32(idx) * 0.01));

// --- Example 2: Pulsing Material Colors ---
// cell.y = 2.0 + (sin(u.time * 2.0) * 0.5 + 0.5) * 4.0;

// --- Example 3: Dynamic Expanding/Contracting SDF Shells ---
// cell.x = cell.x + sin(u.time * 3.0) * 0.2;
