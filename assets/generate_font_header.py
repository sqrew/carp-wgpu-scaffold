import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import distance_transform_edt

def generate_sdf_font_header():
    # Grid parameters
    cols = 16
    rows = 16
    cell_w = 32
    cell_h = 32
    
    font_path = "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf"
    if not os.path.exists(font_path):
        raise FileNotFoundError(f"Font not found at {font_path}")
        
    atlas_w = cols * cell_w
    atlas_h = rows * cell_h
    atlas_img = np.zeros((atlas_h, atlas_w), dtype=np.uint8)
    
    font_size = 22 # Fits nicely in 32x32 with padding
    font = ImageFont.truetype(font_path, font_size)
    
    for char_code in range(256):
        col = char_code % cols
        row = char_code // cols
        
        # Create a single character image
        char_img = Image.new("L", (cell_w, cell_h), 0)
        draw = ImageDraw.Draw(char_img)
        
        # Get character string. Handle non-printable characters gracefully.
        if char_code < 32 or (127 <= char_code < 160):
            char_str = " "
        else:
            try:
                char_str = chr(char_code)
            except Exception:
                char_str = " "
                
        # Get character size using getbbox
        bbox = draw.textbbox((0, 0), char_str, font=font)
        char_w_actual = bbox[2] - bbox[0]
        char_h_actual = bbox[3] - bbox[1]
        
        # Center the character in the cell
        x = (cell_w - char_w_actual) // 2 - bbox[0]
        y = (cell_h - char_h_actual) // 2 - bbox[1]
        
        draw.text((x, y), char_str, fill=255, font=font)
        
        # Convert PIL image to numpy array
        char_arr = np.array(char_img) / 255.0
        
        # Compute Signed Distance Field
        # Threshold to binary (0 or 1)
        binary = char_arr > 0.5
        
        if np.any(binary) and not np.all(binary):
            dt_in = distance_transform_edt(binary)
            dt_out = distance_transform_edt(~binary)
            sdf = dt_in - dt_out
            
            # Normalize to 0-255. spread of e.g. 4.0 pixels for 32x32
            spread = 4.0
            sdf_normalized = np.clip((sdf / spread) * 127.5 + 127.5, 0, 255).astype(np.uint8)
        else:
            # Empty character or solid character
            if np.all(binary):
                sdf_normalized = np.ones((cell_h, cell_w), dtype=np.uint8) * 255
            else:
                sdf_normalized = np.zeros((cell_h, cell_w), dtype=np.uint8)
                
        # Insert into atlas
        y_start = row * cell_h
        y_end = y_start + cell_h
        x_start = col * cell_w
        x_end = x_start + cell_w
        atlas_img[y_start:y_end, x_start:x_end] = sdf_normalized
        
    # Convert 512x512 single channel atlas to 512x512 RGBA8 bytes
    rgba_bytes = []
    for y in range(atlas_h):
        for x in range(atlas_w):
            val = atlas_img[y, x]
            # Write R, G, B, A
            rgba_bytes.extend([val, val, val, val])
            
    # Write C header file
    header_path = "/home/sqrew/Desktop/carp-wgpu-scaffold/src/font_data.h"
    with open(header_path, 'w') as f:
        f.write("/* Generated font atlas header containing JetBrains Mono SDF */\n")
        f.write("#ifndef FONT_DATA_H\n")
        f.write("#define FONT_DATA_H\n\n")
        f.write("#include \"wgpu.h\"\n")
        f.write("#include <stdlib.h>\n\n")
        
        f.write(f"static const unsigned char font_data_bytes[{len(rgba_bytes)}] = {{\n")
        
        # Write bytes in chunks of 16 for readability and compiler friendliness
        for i in range(0, len(rgba_bytes), 16):
            chunk = rgba_bytes[i:i+16]
            chunk_str = ", ".join(f"0x{b:02x}" for b in chunk)
            f.write(f"    {chunk_str},\n")
            
        f.write("};\n\n")
        
        # C helper function to upload texture
        f.write("static void wgpu_upload_font_texture(WGPUContext* ctx, WGPURenderTexture* rt) {\n")
        f.write("    if (!ctx || !rt) return;\n\n")
        f.write("    WGPUTexelCopyTextureInfo destination = {\n")
        f.write("        .texture = rt->texture,\n")
        f.write("        .mipLevel = 0,\n")
        f.write("        .origin = { .x = 0, .y = 0, .z = 0 },\n")
        f.write("        .aspect = WGPUTextureAspect_All,\n")
        f.write("    };\n\n")
        f.write("    WGPUTexelCopyBufferLayout data_layout = {\n")
        f.write("        .offset = 0,\n")
        f.write("        .bytesPerRow = 512 * 4,\n")
        f.write("        .rowsPerImage = 512,\n")
        f.write("    };\n\n")
        f.write("    WGPUExtent3D write_size = {\n")
        f.write("        .width = 512,\n")
        f.write("        .height = 512,\n")
        f.write("        .depthOrArrayLayers = 1,\n")
        f.write("    };\n\n")
        f.write("    wgpuQueueWriteTexture(ctx->queue, &destination, font_data_bytes, sizeof(font_data_bytes), &data_layout, &write_size);\n")
        f.write("}\n\n")
        
        # C helper function to create bind group
        f.write("static WGPUBindGroup wgpu_create_gui_bind_group(\n")
        f.write("    WGPUContext* ctx,\n")
        f.write("    WGPUGeomPipelineWrapper* pipe_wrapper,\n")
        f.write("    WGPUUniformBufferWrapper* ubo_wrapper,\n")
        f.write("    WGPUSampler sampler,\n")
        f.write("    WGPURenderTexture* texture)\n")
        f.write("{\n")
        f.write("    if (!ctx || !pipe_wrapper || !ubo_wrapper || !sampler || !texture) {\n")
        f.write("        return NULL;\n")
        f.write("    }\n\n")
        f.write("    WGPUBindGroupEntry entries[3] = {\n")
        f.write("        {\n")
        f.write("            .binding = 0,\n")
        f.write("            .buffer = ubo_wrapper->buffer,\n")
        f.write("            .offset = 0,\n")
        f.write("            .size = ubo_wrapper->size,\n")
        f.write("        },\n")
        f.write("        {\n")
        f.write("            .binding = 1,\n")
        f.write("            .sampler = sampler,\n")
        f.write("        },\n")
        f.write("        {\n")
        f.write("            .binding = 2,\n")
        f.write("            .textureView = texture->view,\n")
        f.write("        }\n")
        f.write("    };\n\n")
        f.write("    WGPUBindGroupDescriptor desc = {\n")
        f.write("        .layout = pipe_wrapper->bgl,\n")
        f.write("        .entryCount = 3,\n")
        f.write("        .entries = entries,\n")
        f.write("    };\n\n")
        f.write("    return wgpuDeviceCreateBindGroup(ctx->device, &desc);\n")
        f.write("}\n\n")
        
        f.write("#endif /* FONT_DATA_H */\n")
        
    print(f"Font header written successfully to {header_path}!")

if __name__ == '__main__':
    generate_sdf_font_header()
