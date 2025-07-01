import cv2
import numpy as np

def image_to_memory(image_path, output_file):

    image = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
    
    height, width = image.shape
    
    # Create the output file
    with open(output_file, 'w') as f:
        # Write the width and height in 32-bit hexadecimal format
        f.write(f"{width:08x}\n")
        f.write(f"{height:08x}\n")
        
        # Convert pixel values ​​to 32 bits (four pixels per 32-bit line)
        for i in range(0, height):
            for j in range(0, width, 4):
                # Take pixels in blocks of 4 (if width is not divisible by 4, pad with zeros)
                block = image[i, j:j+4]
                if len(block) < 4:
                    block = np.pad(block, (0, 4 - len(block)), 'constant', constant_values=0)
                
                # Convert pixels to a 32-bit unsigned integer in little endian format
                block_value = 0
                for k in range(len(block)):
                    block_value |= block[k] << (8 * k)  # Shift and merge pixels in little endian
                
                # Ensure the value is within 32 unsigned bits (0 to 0xFFFFFFFF)
                block_value &= 0xFFFFFFFF
                
                # Write the value in 32-bit hexadecimal format
                f.write(f"{block_value:08x}\n")

image_to_memory('../resources/images/very_small_peppers.jpg', '../resources/files/input.txt')
print("Done")
