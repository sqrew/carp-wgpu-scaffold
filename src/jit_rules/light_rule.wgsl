// light_rule.wgsl - Native GPU-Resident JIT Light Cellular Automata Loop
// Modifying this file live updates the global light behaviors.
// Leaving this file empty (or deleting all active code) disables the simulation.
//
// === Available Context Variables ===
// - idx       : u32              -> 1D index of the current voxel cell (0 to 32767)
// - light     : vec4<f32>        -> Light cell attributes:
//                                    - light.x: R (Red Intensity)
//                                    - light.y: G (Green Intensity)
//                                    - light.z: B (Blue Intensity)
//                                    - light.w: Intensity (Strength)
// - dt        : f32              -> Timestep delta (constant ~0.00833)
// - u.time    : f32              -> Accumulated simulation runtime in seconds
// - voxel_pos : vec3<f32>        -> 3D world space coordinate of this voxel
//
