struct PointInstance {
    pos_scale: vec4<f32>,
    rot: vec4<f32>,
    color_csg: vec4<f32>,
    light_fields: vec4<f32>,
    interaction_fields: vec4<f32>,
    em_fields: vec4<f32>,
    shape_info: vec4<f32>,
    gravity_field: vec4<f32>,
}

struct SunData {
    dir: vec4<f32>,
    color: vec4<f32>,
    params: vec4<f32>,
}

@group(0) @binding(2) var<storage, read> instances: array<PointInstance>;

@group(0) @binding(0) var<storage, read_write> water_gpu_buffer: array<vec4<f32>>;
@group(0) @binding(1) var<storage, read>       params: array<f32>;

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let idx = global_id.x;
    if (idx >= {{TOTAL_VOXELS}}u) { return; }

    let ox = params[0];
    let oy = params[1];
    let oz = params[2];
    let cell_size = params[3];
    let num_instances = u32(round(params[4]));

    let sx = f32(idx % {{VOXEL_RES}}u);
    let sy = f32((idx / {{VOXEL_RES}}u) % {{VOXEL_RES}}u);
    let sz = f32(idx / ({{VOXEL_RES}}u * {{VOXEL_RES}}u));

    let p = vec3<f32>(
        ox + (sx + 0.5) * cell_size,
        oy + (sy + 0.5) * cell_size,
        oz + (sz + 0.5) * cell_size
    );

    var water_vol = 0.0;
    var lava_vol = 0.0;
    var acid_vol = 0.0;
    var oil_vol = 0.0;

    for (var i = 0u; i < num_instances; i = i + 1u) {
        let inst = instances[i];
        let radius = inst.pos_scale.w;
        if (radius <= 0.0) { continue; }

        let inst_type = i32(round(inst.shape_info.y));
        if (inst_type == 2 || inst_type == 4 || inst_type == 5 || inst_type == 6) {
            let speed = inst.shape_info.w;
            let dist = length(p - inst.pos_scale.xyz);
            
            // If flying fast, leave a thin, low-density trail of water.
            // If stopped or impacting, make a big full-density splash.
            var splat_radius = radius * 1.5;
            var density_mult = 0.35; // visible, medium-density trail in the air
            
            if (speed < 1.5) {
                splat_radius = radius * 4.5; // big splash radius
                density_mult = 1.0;          // full density splash
            }
            
            if (dist < splat_radius) {
                let weight = (1.0 - (dist / splat_radius)) * density_mult;
                if (inst_type == 2) {
                    water_vol = max(water_vol, weight);
                } else if (inst_type == 4) {
                    lava_vol = max(lava_vol, weight);
                } else if (inst_type == 5) {
                    acid_vol = max(acid_vol, weight);
                } else if (inst_type == 6) {
                    oil_vol = max(oil_vol, weight);
                }
            }
        }
    }

    let existing = water_gpu_buffer[idx];
    var final_id = existing.x;
    var final_vol = existing.y;
    var final_sleep = existing.w;
    
    var incoming_id = 0.0;
    var incoming_vol = 0.0;
    if (water_vol > incoming_vol) { incoming_id = 1.0; incoming_vol = water_vol; }
    if (lava_vol > incoming_vol)  { incoming_id = 2.0; incoming_vol = lava_vol; }
    if (acid_vol > incoming_vol)  { incoming_id = 3.0; incoming_vol = acid_vol; }
    if (oil_vol > incoming_vol)   { incoming_id = 4.0; incoming_vol = oil_vol; }
    
    if (incoming_vol > 0.0) {
        if (incoming_id == final_id || final_id == 0.0) {
            final_id = incoming_id;
            final_vol = max(final_vol, incoming_vol);
        } else {
            if (incoming_vol > final_vol) {
                final_id = incoming_id;
                final_vol = incoming_vol;
            }
        }
        final_sleep = 0.0; // Wake voxel
    }
    
    water_gpu_buffer[idx] = vec4<f32>(final_id, final_vol, existing.z, final_sleep);
}
