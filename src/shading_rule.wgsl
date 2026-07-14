// shading_rule.wgsl - Native GPU-Resident JIT Shading Injection Loop
// Modifying this file live updates the visual rendering of materials.
// Leaving this file empty (or deleting all active code) resets materials to default.
//
// === Available Context Variables ===
// - p                    : vec3<f32>  -> 3D world space coordinate of the hit point
// - normal               : vec3<f32>  -> Normalized surface normal at the hit point
// - mat_id               : i32        -> Material ID of the surface (1 to 14)
// - terr_col             : vec3<f32>  -> Output base color/albedo (read/write)
// - custom_glow          : vec3<f32>  -> Output emissive/glow light (read/write)
// - custom_specular_mult : f32        -> Output specular/shine multiplier (read/write)
// - u.time               : f32        -> Accumulated simulation runtime in seconds

if (mat_id == 9) {
    terr_col = vec3<f32>(0.1, 1.0, 0.3); // Bright neon green amethyst!
    let pulse = sin(u.time * 4.0) * 0.3 + 0.7;
    custom_glow = vec3<f32>(0.2, 1.0, 0.4) * pulse * 2.5;
    custom_specular_mult = 6.0;
}
