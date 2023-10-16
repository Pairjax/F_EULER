import numpy as np
from PIL import Image
from matplotlib import pyplot as plt
import math
from decimal import *

def decimal_converter(num): 
    while num > 1:
        num /= 10
    return num

angleList = []

EIGHTPLACES = Decimal(2) ** -8

for i in range(90):
    angle = i * 4
    angle /= 180
    angle *= math.pi
    sineResult = math.sin(angle)
    
    binaryString = ''

    for x in range(12):
        divider = 1 / (2 ** (x + 1))

        sineResult -= divider

        if (sineResult < 0):
            sineResult += divider
            binaryString += '0'
        else:
            binaryString += '1'

    hstr = '%0*X' % ((len(binaryString) + 3) // 4, int(binaryString, 2))
    print(binaryString)

    print(hstr)