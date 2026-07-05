struct PointInstance {
    pos_scale: vec4<f32>,
    rot: vec4<f32>,
    color_csg: vec4<f32>,
    sph_fields: vec4<f32>,
}

struct Uniforms {
    time: f32,
    width: f32,
    height: f32,
    cell_size: f32,
    cam_pos: vec4<f32>,
    cam_dir: vec4<f32>,
    cam_right: vec4<f32>,
    cam_up: vec4<f32>,
    bg_color: vec4<f32>,
    grid_dims: vec4<f32>,
    grid_origin: vec4<f32>,
    shadow_ao_quality: vec4<f32>,
    instances: array<PointInstance, 512>,
}

@group(0) @binding(0) var<storage, read_write> fields_gpu_buffer: array<vec4<f32>>;
@group(0) @binding(1) var<uniform>             u: Uniforms;
@group(0) @binding(2) var<storage, read>       params: array<f32>;

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

    var accumulated_fields = vec4<f32>(0.0);
    var total_weight = 0.0;

    for (var i = 0u; i < num_instances; i = i + 1u) {
        let inst = u.instances[i];
        let radius = inst.pos_scale.w;
        if (radius <= 0.0) { continue; }

        let dist = length(p - inst.pos_scale.xyz);
        if (dist < radius) {
            let weight = 1.0 - (dist / radius);
            
            accumulated_fields += inst.sph_fields * weight;
            total_weight += weight;
        }
    }

    if (total_weight > 0.0) {
        fields_gpu_buffer[idx] = accumulated_fields / total_weight;
    } else {
        fields_gpu_buffer[idx] = vec4<f32>(0.0);
    }
}