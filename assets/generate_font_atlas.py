import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import distance_transform_edt

def generate_sdf_font_atlas():
    # Grid parameters
    cols = 16
    rows = 16
    cell_w = 64
    cell_h = 64
    
    font_path = "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf"
    if not os.path.exists(font_path):
        raise FileNotFoundError(f"Font not found at {font_path}")
        
    atlas_w = cols * cell_w
    atlas_h = rows * cell_h
    atlas_img = np.zeros((atlas_h, atlas_w), dtype=np.uint8)
    
    font_size = 44 # Fits nicely in 64x64 with padding
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
            
            # Normalize to 0-255. spread of e.g. 6.0 pixels
            spread = 6.0
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
        
    # Save as PNG
    os.makedirs("/home/sqrew/Desktop/carp-wgpu-scaffold/assets", exist_ok=True)
    out_img = Image.fromarray(atlas_img)
    out_img.save("/home/sqrew/Desktop/carp-wgpu-scaffold/assets/font.png")
    print("Font atlas generated successfully at assets/font.png!")

if __name__ == '__main__':
    generate_sdf_font_atlas()
