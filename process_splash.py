from PIL import Image, ImageDraw, ImageFont
import numpy as np

# 1. Extend the background image
img = Image.open('lengyan/Assets.xcassets/sutra_splash.imageset/sutra_splash.png').convert('RGB')
arr = np.array(img)
h, w, c = arr.shape

# Target height: iPhone 15 Pro Max ratio is ~2.16 (2796/1290). 
# For w=510, target_h = 510 * 2.16 = 1101. Let's make it 1200 to be safe.
target_h = 1200
pad_top = (target_h - h) // 2
pad_bottom = target_h - h - pad_top

# We want to replicate/reflect the top and bottom to make it look natural.
# Let's take the top 100 pixels and mirror them upwards repeatedly
top_patch = arr[:100, :, :]
bottom_patch = arr[-100:, :, :]

new_arr = np.zeros((target_h, w, c), dtype=np.uint8)
new_arr[pad_top:pad_top+h, :, :] = arr

# Fill top
current_y = pad_top
while current_y > 0:
    chunk_h = min(100, current_y)
    # Mirror the patch
    new_arr[current_y-chunk_h:current_y, :, :] = top_patch[:chunk_h][::-1]
    current_y -= chunk_h
    top_patch = top_patch[::-1] # flip for next iteration to tile seamlessly

# Fill bottom
current_y = pad_top + h
while current_y < target_h:
    chunk_h = min(100, target_h - current_y)
    new_arr[current_y:current_y+chunk_h, :, :] = bottom_patch[-chunk_h:][::-1]
    current_y += chunk_h
    bottom_patch = bottom_patch[::-1]

bg_img = Image.fromarray(new_arr)
bg_img.save('lengyan/Assets.xcassets/sutra_splash.imageset/sutra_splash.png', 'PNG')

print("Background extended successfully.")
