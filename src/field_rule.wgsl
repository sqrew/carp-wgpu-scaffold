// field_rule.wgsl - Native GPU-Resident JIT Field Cellular Automata Loop
// Modifying this file live updates the global environmental field behaviors.
// Leaving this file empty (or deleting all active code) disables the simulation.
//
// === Available Context Variables ===
// - idx       : u32              -> 1D index of the current voxel cell (0 to 32767)
// - fields    : vec4<f32>        -> Field cell attributes:
//                                    - fields.x: Temperature
//                                    - fields.y: Light
//                                    - fields.z: Humidity
//                                    - fields.w: Pressure
// - dt        : f32              -> Timestep delta (constant ~0.00833)
// - u.time    : f32              -> Accumulated simulation runtime in seconds
// - voxel_pos : vec3<f32>        -> 3D world space coordinate of this voxel
//

// --- Example: Simple Temperature and Light Propagation ---
// if (fields.x > 50.0) {
//     // High heat breeds light (flames)
//     fields.y = min(1.0, fields.y + dt * 2.0);
// } else {
//     // Light cools down
//     fields.y = max(0.0, fields.y - dt * 0.5);
// }
//
// // Simple decay/dissipation of pressure
// fields.w = fields.w * 0.98;
