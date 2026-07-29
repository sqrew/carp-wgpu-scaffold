// light_rule.wgsl - Native GPU-Resident JIT Light Cellular Automata Loop

// Query if this cell is solid terrain
let voxel = get_voxel(local_x, local_y, local_z);
let solid_thresh = u.terrain_params3.z;
if (voxel.x <= solid_thresh) {
    let mat_id = round(abs(voxel.y));
    var emitter = vec4<f32>(0.0);
    let seed = dot(voxel_pos, vec3<f32>(12.9898, 78.233, 37.719));
    let flicker = 1.0 + 0.10 * sin(u.time * 8.0 + seed);
    
    if (mat_id == 11.0) { // Glowing Neon Cyan
        emitter = vec4<f32>(0.0, 1.5 * flicker, 1.5 * flicker, 1.0);
    } else if (mat_id == 9.0) { // Amethyst Purple Crystal
        emitter = vec4<f32>(1.2 * flicker, 0.0, 1.5 * flicker, 1.0);
    } else if (mat_id == 13.0) { // Pulsating Lava Crimson (hot rock / embers)
        emitter = vec4<f32>(1.5 * flicker, 0.4 * flicker, 0.0, 1.0);
    }
    light = emitter;
} else {
    // 1. Emitters Check (read from water/liquid texture)
    let water_here = get_water(local_x, local_y, local_z);
    let lava_val = water_here.y;
    let acid_val = water_here.z;
    
    var emitter = vec4<f32>(0.0);
    
    // Simple pseudo-random flicker based on time and position
    let seed = dot(voxel_pos, vec3<f32>(12.9898, 78.233, 37.719));
    let flicker = 1.0 + 0.12 * sin(u.time * 9.5 + seed);
    
    if (lava_val > 0.05) {
        // Red-orange glowing light
        emitter = vec4<f32>(lava_val * 1.6 * flicker, lava_val * 0.5 * flicker, 0.0, lava_val * 1.5);
    } else if (acid_val > 0.05) {
        // Green radioactive glowing light
        emitter = vec4<f32>(0.0, acid_val * 1.2 * flicker, acid_val * 0.15 * flicker, acid_val * 1.0);
    }
    
    // 2. Light Propagation (Average or max of neighbors in the light grid)
    let l_left  = get_fluid(local_x - 1, local_y, local_z);
    let l_right = get_fluid(local_x + 1, local_y, local_z);
    let l_below = get_fluid(local_x, local_y - 1, local_z);
    let l_above = get_fluid(local_x, local_y + 1, local_z);
    let l_front = get_fluid(local_x, local_y, local_z - 1);
    let l_back  = get_fluid(local_x, local_y, local_z + 1);
    
    // Take the maximum of neighbors to propagate light waves
    let max_neighbor = max(l_left, max(l_right, max(l_below, max(l_above, max(l_front, l_back)))));
    
    // 3. Smoke & Liquid Light Absorption
    let gas_here = get_gas(local_x, local_y, local_z);
    let smoke_density = gas_here.y; // Volcanic Smoke/Ash is in .y channel
    let water_density = water_here.x; // Water is in .x channel
    let oil_density = water_here.w;   // Crude Oil is in .w channel
    
    // Ambient decay is 0.94; smoke/liquid absorbs propagating light
    let smoke_absorption = clamp(smoke_density * 1.8, 0.0, 0.90);
    let liquid_absorption = clamp(oil_density * 1.0 + water_density * 0.15, 0.0, 1.0);
    let total_absorption = clamp(smoke_absorption + liquid_absorption, 0.0, 1.0);
    let decay = 0.94 * (1.0 - total_absorption);
    
    // Combine emitter and decayed neighbor light propagation
    let propagated = max_neighbor * decay;
    
    // Blend them
    light = max(emitter, propagated);
}
