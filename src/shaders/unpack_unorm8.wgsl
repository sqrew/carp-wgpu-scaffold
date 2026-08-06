@group(0) @binding(0) var<storage, read>       voxel_half_buffer: array<u32>;
@group(0) @binding(1) var<storage, read_write> voxel_gpu_buffer: array<vec4<f32>>;

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let idx = global_id.x;
    if (idx >= {{TOTAL_VOXELS}}u) { return; }
    
    let x = idx % 32u;
    let y = (idx / 32u) % 32u;
    let z = idx / 1024u;
    
    let src_idx = x + y * 64u + z * 2048u;

    let val = voxel_half_buffer[src_idx];
    voxel_gpu_buffer[idx] = unpack4x8unorm(val);
}
