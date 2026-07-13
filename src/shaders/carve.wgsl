@group(0) @binding(0) var<storage, read_write> voxel_gpu_buffer: array<vec4<f32>>;
@group(0) @binding(1) var<storage, read>       params: array<f32>;

fn smin(a: f32, b: f32, k: f32) -> f32 {
    let h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * h * k * (1.0 / 6.0);
}

fn smax(a: f32, b: f32, k: f32) -> f32 {
    let h = max(k - abs(a - b), 0.0) / k;
    return max(a, b) + h * h * h * k * (1.0 / 6.0);
}

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let idx = global_id.x;
    if (idx >= {{TOTAL_VOXELS}}u) { return; }

    let ox = params[0];
    let oy = params[1];
    let oz = params[2];
    let cell_size = params[3];
    let cx = params[4];
    let cy = params[5];
    let cz = params[6];
    let radius = params[7];
    let op = params[8];

    let sx = f32(idx % {{VOXEL_RES}}u);
    let sy = f32((idx / {{VOXEL_RES}}u) % {{VOXEL_RES}}u);
    let sz = f32(idx / ({{VOXEL_RES}}u * {{VOXEL_RES}}u));

    let px = ox + (sx + 0.5) * cell_size;
    let py = oy + (sy + 0.5) * cell_size;
    let pz = oz + (sz + 0.5) * cell_size;

    let dx = px - cx;
    let dy = py - cy;
    let dz = pz - cz;
    let dist_to_crater_center = sqrt(dx*dx + dy*dy + dz*dz);
    let crater_dist = dist_to_crater_center - radius;

    var val = voxel_gpu_buffer[idx];
    let old_dist = val.x;

    if (op < 0.5) {
        // Carve (using smax to match CPU)
        let neg_crater_dist = -crater_dist;
        let new_dist = smax(old_dist, neg_crater_dist, 2.5);
        val.x = new_dist;
    } else {
        // Build (hard union, no blending)
        let new_dist = min(old_dist, crater_dist);
        val.x = new_dist;
        if (crater_dist < 0.0) {
            val.y = op;
        }
    }

    voxel_gpu_buffer[idx] = val;
}