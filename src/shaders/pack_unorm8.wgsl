@group(0) @binding(0) var<storage, read>       voxel_gpu_buffer: array<vec4<f32>>;
@group(0) @binding(1) var<storage, read_write> voxel_half_buffer: array<u32>;

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let idx = global_id.x;
    let x = idx % 32u;
    let y = (idx / 32u) % 32u;
    let z = idx / 1024u;
    
    // Stride to 64 elements (256 bytes) to satisfy alignment
    let dest_idx = x + y * 64u + z * 2048u;

    let val = voxel_gpu_buffer[idx];
    let p1 = pack4x8unorm(val);

    voxel_half_buffer[dest_idx] = p1;
}
