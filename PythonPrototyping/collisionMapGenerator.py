import numpy as np
from PIL import Image
from matplotlib import pyplot as plt
import math

road_base = None
road_img_width = 1
road_img_height = 1

with Image.open("RetroBG_Flat.png") as im:
    road_img_width = im.width
    road_img_height = im.height
    with open('collision_map.txt', 'w') as f:
        for y in range(road_img_height):
            for x in range(road_img_width):
                surface = 0
                color = im.getpixel((x, y))
                if color == (255, 170, 197, 255):
                    surface = 1
                
                f.write(str(surface))
            
            f.write('\n')