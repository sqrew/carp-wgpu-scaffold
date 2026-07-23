struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
}

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> VertexOutput {
    var out: VertexOutput;
    let uv = vec2<f32>(
        f32((vertex_index << 1u) & 2u),
        f32(vertex_index & 2u)
    );
    out.position = vec4<f32>(uv * 2.0 - 1.0, 0.0, 1.0);
    out.uv = vec2<f32>(uv.x, 1.0 - uv.y);
    return out;
}

@group(0) @binding(0) var terrain_color_texture: texture_2d<f32>;
@group(0) @binding(1) var depth_texture: texture_depth_2d;
@group(0) @binding(2) var volumetric_texture: texture_2d<f32>;
@group(0) @binding(3) var linear_sampler: sampler;

@fragment
fn fs_main(@location(0) uv: vec2<f32>, @builtin(position) frag_coord: vec4<f32>) -> @location(0) vec4<f32> {
    let tex_size = vec2<f32>(textureDimensions(volumetric_texture, 0));
    let texel_size = 1.0 / tex_size;
    
    // Sample the center pixel and its 4 cross neighbors
    let c = textureSample(volumetric_texture, linear_sampler, uv).rgb;
    let l = textureSample(volumetric_texture, linear_sampler, uv + vec2<f32>(-texel_size.x, 0.0)).rgb;
    let r = textureSample(volumetric_texture, linear_sampler, uv + vec2<f32>(texel_size.x, 0.0)).rgb;
    let t = textureSample(volumetric_texture, linear_sampler, uv + vec2<f32>(0.0, -texel_size.y)).rgb;
    let b = textureSample(volumetric_texture, linear_sampler, uv + vec2<f32>(0.0, texel_size.y)).rgb;
    
    // Contrast-adaptive sharpening (CAS)
    let min_rgb = min(c, min(min(l, r), min(t, b)));
    let max_rgb = max(c, max(max(l, r), max(t, b)));
    
    let sharpening_strength = 0.22; // Strength of sharpening filter
    let peak = -1.0 / (3.0 + sharpening_strength * 5.0);
    
    let diff = max_rgb - min_rgb;
    let w = diff * peak;
    
    let final_rgb = (l + r + t + b) * w + c * (1.0 - 4.0 * w);
    
    // Keep bindings active to avoid dead-code elimination by WGSL
    let dummy1 = textureLoad(terrain_color_texture, vec2<i32>(0, 0), 0);
    let dummy2 = textureLoad(depth_texture, vec2<i32>(0, 0), 0);
    
    return vec4<f32>(max(vec3<f32>(0.0), final_rgb) + (dummy1.rgb + vec3<f32>(dummy2)) * 0.000001, 1.0);
}
