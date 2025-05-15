#!/usr/bin/env python3
import sys
import os
import base64
from PIL import Image
import numpy as np

def image_to_2bpp_bin(input_path):
    # Load and resize image to 240x128
    img = Image.open(input_path).convert("L").resize((240, 128))

    # Quantize to 2 bits (0-3)
    img_np = np.array(img) // 64  # 0-255 → 0-3

    # Pack 4 pixels (2 bits each) into 1 byte
    flat = img_np.flatten()
    packed = bytearray()

    for i in range(0, len(flat), 4):
        chunk = flat[i:i+4]
        if len(chunk) < 4:
            chunk = np.pad(chunk, (0, 4 - len(chunk)))
        byte = (chunk[0] << 6) | (chunk[1] << 4) | (chunk[2] << 2) | chunk[3]
        packed.append(byte)

    # Use input filename as base
    base = os.path.splitext(input_path)[0]
    output_bin_path = f"{base}_2bpp.bin"

    # Write binary file
    with open(output_bin_path, "wb") as f:
        f.write(packed)
    print(f"✅ Saved {len(packed)} bytes to '{output_bin_path}'")

    # Encode to base64
    b64_encoded = base64.b64encode(packed).decode("ascii") #RFC 4648
    output_b64_path = f"{output_bin_path}.b64.txt"

    with open(output_b64_path, "w") as f:
        f.write(b64_encoded)
    print(f"📄 Base64 saved to '{output_b64_path}' ({len(b64_encoded)} characters)")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python convert2bpp.py <input_image>")
        sys.exit(1)

    input_image = sys.argv[1]
    image_to_2bpp_bin(input_image)
