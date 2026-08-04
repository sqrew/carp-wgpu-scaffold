// em_rule.wgsl - Native GPU-Resident JIT Electromagnetism solver (Jacobi Potential Relaxation)

// Average potential and magnetic vector potential from neighbors
let V_left  = get_em(local_x - 1, local_y, local_z).w;
let V_right = get_em(local_x + 1, local_y, local_z).w;
let V_down  = get_em(local_x, local_y - 1, local_z).w;
let V_up    = get_em(local_x, local_y + 1, local_z).w;
let V_back  = get_em(local_x, local_y, local_z - 1).w;
let V_front = get_em(local_x, local_y, local_z + 1).w;

let relaxed_V = (V_left + V_right + V_down + V_up + V_back + V_front) / 6.0;

let A_left  = get_em(local_x - 1, local_y, local_z).xyz;
let A_right = get_em(local_x + 1, local_y, local_z).xyz;
let A_down  = get_em(local_x, local_y - 1, local_z).xyz;
let A_up    = get_em(local_x, local_y + 1, local_z).xyz;
let A_back  = get_em(local_x, local_y, local_z - 1).xyz;
let A_front = get_em(local_x, local_y, local_z + 1).xyz;

let relaxed_A = (A_left + A_right + A_down + A_up + A_back + A_front) / 6.0;

// Scan instances list to find charge sources & grounds
var local_charge = 0.0;
var local_current = vec3<f32>(0.0);
var grounded = false;

for (var i = 0u; i < 512u; i = i + 1u) {
    let inst = u.instances[i];
    let radius = inst.pos_scale.w;
    if (radius <= 0.0) { continue; }
    
    let dist = distance(voxel_pos, inst.pos_scale.xyz);
    if (dist < radius) {
        // em_fields.w is the electric charge, em_fields.xyz is the magnetic vector (current/vector potential)
        local_charge += inst.em_fields.w;
        local_current += inst.em_fields.xyz;
        
        // If shape_info.y is ground / lightning rod (value 9.0), force potential to ground
        if (inst.shape_info.y == 9.0) {
            grounded = true;
        }
    }
}

// Compute new potential V and vector potential A
let water_here = get_water(local_x, local_y, local_z).x;
let conductivity = select(0.97, 0.998, water_here > 0.05);

var new_V = 0.0;
if (grounded) {
    new_V = 0.0;
} else {
    // Diffuse potential and add source charge with decay
    new_V = relaxed_V * conductivity + local_charge * 0.5;
}

var new_A = relaxed_A * conductivity + local_current * 0.5;

// Save back to output em field voxel
em = vec4<f32>(new_A, new_V);
