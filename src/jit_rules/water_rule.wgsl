// water_rule.wgsl - Native GPU-Resident JIT Water cellular automata & fluid loop.
//
// Input/Output variable is:
//   var water: vec4<f32>; // (x: Volume fraction [0..1], y,z,w: Velocity vector)
//
// Injected code here executes per-voxel. Use `water` to modify fluid simulation state.
//
