// /home/sqrew/Desktop/carp-wgpu-scaffold/src/shaders/gui.wgsl
struct VertexInput {
    @location(0) pos_size: vec4<f32>,
    @location(1) color: vec4<f32>,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>,
    @location(2) mode: f32,
    @location(3) local_pos: vec2<f32>,
    @location(4) rect_size: vec2<f32>,
    @location(5) corner_radius: f32,
}

@group(0) @binding(0) var<uniform> screen_res: vec2<f32>;
@group(0) @binding(1) var font_sampler: sampler;
@group(0) @binding(2) var font_texture: texture_2d<f32>;

// Helper: SDF for rounded box
fn sdRoundBox(p: vec2<f32>, b: vec2<f32>, r: f32) -> f32 {
    let q = abs(p) - b + vec2<f32>(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2<f32>(0.0))) - r;
}

@vertex
fn vs_main(in: VertexInput, @builtin(vertex_index) vertex_idx: u32) -> VertexOutput {
    var out: VertexOutput;
    
    // Unpack size, radius, and mode
    let radius = floor(in.pos_size.z / 10000.0);
    let rw = in.pos_size.z - (radius * 10000.0);
    let mode = floor(in.pos_size.w / 10000.0);
    let rh = in.pos_size.w - (mode * 10000.0);
    
    let rx = in.pos_size.x;
    let ry = in.pos_size.y;
    
    // Generate UVs based on vertex index inside quad (6 vertices)
    let idx = vertex_idx % 6u;
    var uv = vec2<f32>(0.0);
    var pos = vec2<f32>(0.0);
    
    if (idx == 0u) {
        uv = vec2<f32>(in.pos_size.x, in.pos_size.y); // We store raw uv coords in uv for text mode inside gui.carp?
        // Wait, no! The vertex shader generates the raw uv from idx, but wait!
        // In the original vs_main, it generated UVs 0.0 to 1.0!
        // Yes, and in our gui.carp, we passed the interpolated texture coordinates (uv-u, uv-v) to Vertex.init!
        // Wait! Let's check VertexInput in vs_main!
        // Ah! Location 0 of VertexInput is pos_size (which is rx, ry, radius*10000+rw, mode*10000+rh).
        // Wait, where are the vertex UVs in VertexInput?
        // Let's check how the vertex buffers are bound/configured in render.carp!
        // Oh! Let's search for "create-geom-pipeline" in render.carp or wgpu_render_helpers.h to see what the vertex layout is!
    }
    return out; // placeholder to not save yet
}
