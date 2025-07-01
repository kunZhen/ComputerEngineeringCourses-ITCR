import numpy as np
import cv2

def file_to_image(input_file, output_image):
    with open(input_file, 'r') as f:
        # Read the width and height of the image
        width = int(f.readline().strip(), 16)
        height = int(f.readline().strip(), 16)
        
        # Initialize an empty array for the pixels
        image_data = np.zeros((height, width), dtype=np.uint8)
        
        # Read each 32-bit data line and fill the image pixels
        row = 0
        col = 0
        for line in f:
            line = line.strip()
            # Skip lines that contain "xxxxxxxx"
            if line == "xxxxxxxx":
                continue
                
            # Convert the hexadecimal value to a 32-bit unsigned integer
            block_value = int(line, 16)
            
            # Extract the 4 bytes (each representing a grayscale pixel)
            for i in range(4):
                pixel = (block_value >> (8 * i)) & 0xFF # Extract the corresponding byte
                if col < width:  # Avoid exceeding the width
                    image_data[row, col] = pixel
                    col += 1
                if col >= width:  # Move to the next row if the end of the current row is reached
                    col = 0
                    row += 1
                if row >= height:  # If the entire image is already filled, exit
                    break
            if row >= height:
                break

    # Save the generated image
    cv2.imwrite(output_image, image_data)

file_to_image('data_out.hex', 'image_result.jpg')
print("Done")
