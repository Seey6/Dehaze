import cv2
import numpy as np
import struct

def prepare_image(input_path, output_path, width, height):
    # Read image
    img = cv2.imread(input_path)
    if img is None:
        print(f"Error: Could not read {input_path}")
        return

    # Resize
    img_resized = cv2.resize(img, (width, height))
    
    # OpenCV uses BGR, convert to RGB
    img_rgb = cv2.cvtColor(img_resized, cv2.COLOR_BGR2RGB)
    
    # Save raw bytes (R, G, B, R, G, B...)
    with open(output_path, 'wb') as f:
        f.write(img_rgb.tobytes())
        
    print(f"Saved resized image ({width}x{height}) to {output_path}")
    print(f"Total bytes: {len(img_rgb.tobytes())}")

if __name__ == "__main__":
    prepare_image("haze.jpg", "sim/image.bin", 320, 240)
