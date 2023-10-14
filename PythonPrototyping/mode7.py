import numpy as np
from PIL import Image
from matplotlib import pyplot as plt
import math

road_base = None
road_img_width = 1
road_img_height = 1

with Image.open("base.png") as im:
    imrgb = im.convert("RGB")
    road_base = list(imrgb.getdata())
    road_img_width = im.width
    road_img_height = im.height

def affine_renderer(position, angle, screen_size, image_scale, perspective_intensity):
    road_modified = np.ndarray((screen_size[0], screen_size[1], 3), dtype=np.int32) # Where we output the datas

    scale_x = road_img_width * image_scale[0] # scale-adjusted width of the original image
    scale_y = road_img_height * image_scale[1] # scale-adjusted height of the original image
    height_ratio = screen_size[1] / scale_y # Ratio between canvas height and image height

    # Precalculated to save performance
    sin_of_angle = math.sin(angle)
    cos_of_angle = math.cos(angle)

    for y in range(0, screen_size[1]):
        depth_scale = 1
        if (y > 0):
            depth_scale = 1 - ((y * perspective_intensity) / screen_size[1]) # The ratio by which the width of the image is scaled at this row.
            # Each row, starting from the bottom of the image, gets stretched horizontally (or squashed?)

        width_ratio = (screen_size[0] * depth_scale) / scale_x # Ratio between canvas width and image width
        
        for x in range(0, screen_size[0]):
            height_ratio = (screen_size[1] * depth_scale * 0.5) / scale_y # Ratio between canvas width and image width

            color = [0, 250, 0] # Default color for "uh oh"

            # We do an inverse affine transformation.
            # The formula involves a 2x2 matrix multiplying against
            # the current pixel coords to get a "sample" coordinate (representing the
            # relative pixel in the original image)

            start_x = x - position[0] # First, offset to the image origin
            start_y = y - position[1]
            image_x = (start_x * cos_of_angle * height_ratio)\
                        + (start_y * sin_of_angle * width_ratio)
            image_x /= (height_ratio * width_ratio)
            image_y = (-start_x * sin_of_angle * height_ratio)\
                        + (start_y * cos_of_angle * width_ratio)
            image_y /= (height_ratio * width_ratio)

            # Are we within the boundaries of the map?
            if image_x >= (-road_img_width / 2) + (screen_size[0] / 2) and image_x <= (road_img_width / 2) + (screen_size[0] / 2)\
                and image_y >= (-road_img_height / 2) + (screen_size[1] / 2) and image_y <= (road_img_height / 2) + (screen_size[1] / 2):
                image_x += (road_img_width / 2) - position[0]
                image_y += (road_img_height / 2) - position[1]

                # If so, let's get the color at this pixel on the map
                color = sample_map(int(image_x), int(image_y))
            else:
                color = [0, 0, 250]

            road_modified[x, y] = color

    road_modified = np.rot90(road_modified)

    plt.imshow(road_modified, interpolation='nearest')
    plt.show()

def sample_map(x, y):
    index = (int) (((y - 1) * road_img_width) + x)

    return road_base[index]

for i in range(5):
    affine_renderer(np.array([75, 250 - (i * 80)]), 0, np.array([512, 448]), np.array([0.1, 0.1]), 0.3)

for i in range(5):
    affine_renderer(np.array([75, -70]), i * (-math.pi / 8), np.array([512, 448]), np.array([0.1, 0.1]), 0.3)