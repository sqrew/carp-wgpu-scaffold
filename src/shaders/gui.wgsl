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
    
    let pos = vec2<f32>(in.pos_size.x, in.pos_size.y);
    
    // Generate UVs based on vertex index inside quad (6 vertices)
    let idx = vertex_idx % 6u;
    var uv = vec2<f32>(0.0);
    
    if (idx == 0u) {
        uv = vec2<f32>(0.0, 0.0);
    } else if (idx == 1u) {
        uv = vec2<f32>(0.0, 1.0);
    } else if (idx == 2u) {
        uv = vec2<f32>(1.0, 0.0);
    } else if (idx == 3u) {
        uv = vec2<f32>(1.0, 0.0);
    } else if (idx == 4u) {
        uv = vec2<f32>(0.0, 1.0);
    } else if (idx == 5u) {
        uv = vec2<f32>(1.0, 1.0);
    }
    
    let ndc_x = (pos.x / screen_res.x) * 2.0 - 1.0;
    let ndc_y = 1.0 - (pos.y / screen_res.y) * 2.0;
    
    let quad_idx = f32(vertex_idx / 6u);
    let depth = 0.9 - (quad_idx * 0.01);
    
    out.position = vec4<f32>(ndc_x, ndc_y, depth, 1.0);
    
    if (mode > 0.5) {
        // Text mode: pos_size.z contains the exact U coord, pos_size.w contains 10000.0f + V coord
        out.uv = vec2<f32>(in.pos_size.z, in.pos_size.w - 10000.0);
    } else {
        out.uv = uv;
    }
    
    out.color = in.color;
    out.mode = mode;
    out.local_pos = (uv - vec2<f32>(0.5)) * vec2<f32>(rw, rh);
    out.rect_size = vec2<f32>(rw, rh);
    out.corner_radius = radius;
    
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    if (in.mode < 0.5) {
        // Rounded Rect mode using pixel-perfect derivatives
        let half_size = in.rect_size * 0.5;
        let d = sdRoundBox(in.local_pos, half_size, in.corner_radius);
        
        // Rounded Rect mode using fixed edge size (antialiased over 1.0 pixel boundary)
        let alpha = smoothstep(1.0, -1.0, d);
        
        if (alpha <= 0.0) {
            discard;
        }
        return vec4<f32>(in.color.rgb, in.color.a * alpha);
    } else {
        // SDF Font Text mode sampling
        let sample_val = textureSample(font_texture, font_sampler, in.uv).r;
        let text_alpha = smoothstep(0.45, 0.55, sample_val);
        
        if (text_alpha <= 0.05) {
            discard;
        }
        return vec4<f32>(in.color.rgb, in.color.a * text_alpha);
    }
}
