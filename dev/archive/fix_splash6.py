import cv2
import numpy as np

img = cv2.imread('lengyan/Assets.xcassets/fo.imageset/fo.jpg')
h, w, c = img.shape

new_h = 1600
pad_top = (new_h - h) // 2
pad_bottom = new_h - h - pad_top

new_img = np.zeros((new_h, w, c), dtype=np.uint8)
new_img[pad_top:pad_top+h, :, :] = img

# Top padding
top_patch = img[0:pad_top, :, :]
top_patch_flipped = cv2.flip(top_patch, 0)
new_img[0:pad_top, :, :] = top_patch_flipped

# Bottom padding - mirror small strips to avoid large objects
# Let's use 20 pixels height. If 20 pixels hits the lotus, it will look like a stretched lotus line. 
# Let's hope the bottom 20 pixels is just paper!
N = 20
bottom_strip = img[h-N:h, :, :]
strip_flipped = cv2.flip(bottom_strip, 0)

current_y = pad_top + h
flip_mode = True

while current_y < new_h:
    remaining = new_h - current_y
    copy_h = min(N, remaining)
    
    if flip_mode:
        new_img[current_y:current_y+copy_h, :, :] = strip_flipped[0:copy_h, :, :]
    else:
        new_img[current_y:current_y+copy_h, :, :] = bottom_strip[0:copy_h, :, :]
        
    current_y += copy_h
    flip_mode = not flip_mode

cv2.imwrite('lengyan/Assets.xcassets/sutra_splash.imageset/sutra_splash.png', new_img)
print("Applied repeat mirroring trick!")
