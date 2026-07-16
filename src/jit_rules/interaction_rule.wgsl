// interaction_rule.wgsl - Native GPU-Resident JIT Voxel-Interaction Simulation Loop
//
// Input/Output variable is:
//   var fields: vec4<f32>; // (x: Temp, y: Density, z: Stress, w: Material ID)
//
// You also have access to:
//   - `voxel_pos` (vec3<f32> representing the voxel's world space position)
//   - `dt` (f32 time step, e.g., 0.00833)
//   - `get_voxel(dx, dy, dz)`: helper to sample neighboring voxel SDF/Materials.
//     Returns a vec4<f32> where:
//       - x: SDF distance (negative inside material, positive outside)
//       - y: Material ID of that neighbor
//
// Injected code here executes per-voxel. Use `fields` to modify simulation state.

// Example: Heat propagation and material combustion
let voxel_self = get_voxel(0, 0, 0);

// Only simulate inside solid voxel boundaries
// if (voxel_self.x < 0.0) {
//     // Sample surrounding neighborhood for temperature diffusion
//     // In our fields system, temp is mapped to fields.x
//     // (Note: we use a small offset in texture coordinates via the JIT's get_voxel helper)
//     var neighbor_temp = 0.0;
    
//     // We can query neighbor voxel properties (though fields is currently read/write for self,
//     // we can diffuse based on nearby state if they have been splatted/baked).
//     // For now, let's diffuse heat locally:
//     fields.x += (neighbor_temp - fields.x) * dt * 0.5;

//     // Combustion/Melting simulation:
//     // If the voxel gets extremely hot (Temp > 100.0), it begins to burn/consume density
//     if (fields.x > 100.0) {
//         fields.y = max(0.0, fields.y - dt * 5.0); // burn density
        
//         // If density is fully consumed, destroy the material (turn to ID 0 / Air)
//         if (fields.y <= 0.0) {
//             fields.w = 0.0; 
//         }
//     }
// }
