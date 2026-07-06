@group(0) @binding(0) var<storage, read>       voxel_gpu_buffer: array<vec4<f32>>;
@group(0) @binding(1) var<storage, read_write> voxel_half_buffer: array<vec2<u32>>;

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let idx = global_id.x;
    if (idx >= {{TOTAL_VOXELS}}u) { return; }

    let val = voxel_gpu_buffer[idx];
    let p1 = pack2x16float(val.xy);
    let p2 = pack2x16float(val.zw);

    voxel_half_buffer[idx] = vec2<u32>(p1, p2);
}