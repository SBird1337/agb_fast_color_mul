#!/bin/env python3

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np

COLORS_PER_HOUR = 60
color_day = '#FFFFFF'
color_evening = '#E0B5B5'
color_night = '#7D7DE2'
color_morning = '#E2FAD0'

# courtesy of https://stackoverflow.com/questions/25668828/how-to-create-colour-gradient-in-python
def colorFader(c1,c2,mix=0): #fade (linear interpolate) from color c1 (at mix=0) to c2 (mix=1)
    c1=np.array(mpl.colors.to_rgb(c1))
    c2=np.array(mpl.colors.to_rgb(c2))
    return mpl.colors.to_hex((1-mix)*c1 + mix*c2)

def generateFade(c1,c2, hours):
    colors = []
    n = hours * COLORS_PER_HOUR
    for x in range(n):
        color = colorFader(c1,c2, x / n)
        r = color[1:3]
        g = color[3:5]
        b = color[5:7]
        colors.append((int(r,16),int(g,16),int(b,16)))
    
    return colors

dnColors = []
dnColors += generateFade(color_day, color_evening, 5)
dnColors += generateFade(color_evening, color_night, 3)
dnColors += generateFade(color_night, color_morning, 10)
dnColors += generateFade(color_morning, color_day, 6)

for i in range(COLORS_PER_HOUR * 24):
    r = dnColors[i][0]
    g = dnColors[i][1]
    b = dnColors[i][2]
    r = int(r / 8)
    g = int(g / 8)
    b = int(b / 8)
    color = r | (g << 5) | (b << 10)
    print(f"    .hword {hex(color)}")