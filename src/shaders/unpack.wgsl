@group(0) @binding(0) var<storage, read>       voxel_half_buffer: array<vec2<u32>>;
@group(0) @binding(1) var<storage, read_write> voxel_gpu_buffer: array<vec4<f32>>;

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let idx = global_id.x;
    if (idx >= {{TOTAL_VOXELS}}u) { return; }

    let val = voxel_half_buffer[idx];
    let p1 = unpack2x16float(val.x);
    let p2 = unpack2x16float(val.y);

    voxel_gpu_buffer[idx] = vec4<f32>(p1.x, p1.y, p2.x, p2.y);
}
