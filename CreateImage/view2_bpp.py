#!/usr/bin/env python3
import sys
import os
import base64
import numpy as np
import matplotlib.pyplot as plt
from PIL import Image

def load_2bpp_data(data_bytes):
    # Unpack 2bpp data (4 pixels per byte)
    pixels = []
    for byte in data_bytes:
        pixels.append((byte >> 6) & 0b11)
        pixels.append((byte >> 4) & 0b11)
        pixels.append((byte >> 2) & 0b11)
        pixels.append(byte & 0b11)
    return np.array(pixels, dtype=np.uint8)

def visualize_2bpp_image(input_path, width=240, height=128):
    # Load raw 2bpp data
    if input_path.endswith(".txt"):
        with open(input_path, "r") as f:
            data_bytes = base64.b64decode(f.read().strip())
    else:
        with open(input_path, "rb") as f:
            data_bytes = f.read()

    # Convert to pixel array
    pixel_array = load_2bpp_data(data_bytes)
    print(f"Len: {len(pixel_array)}")

    expected_pixels = width * height
    if len(pixel_array) < expected_pixels:
        print("⚠️ Warning: Data too short. Padding with zeros.")
        pixel_array = np.pad(pixel_array, (0, expected_pixels - len(pixel_array)))
    elif len(pixel_array) > expected_pixels:
        print("⚠️ Warning: Data too long. Truncating.")
        pixel_array = pixel_array[:expected_pixels]

    image = pixel_array.reshape((height, width))

    # Scale pixel values to 0-255 for visualization
    image_vis = (image * 85).astype(np.uint8)  # 0–3 → 0–255

    # Show image using matplotlib
    plt.imshow(image_vis, cmap="gray", vmin=0, vmax=255)
    plt.title(f"Viewing: {os.path.basename(input_path)}")
    plt.axis("off")
    plt.show()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python view_2bpp.py <image_2bpp.bin or .b64.txt>")
        sys.exit(1)

    visualize_2bpp_image(sys.argv[1])
