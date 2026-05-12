import cv2
import numpy as np

img = cv2.imread('lengyan/Assets.xcassets/fo.imageset/fo.jpg')
h, w, c = img.shape # 1084, 690, 3

new_h = 1600
pad_top = (new_h - h) // 2
pad_bottom = new_h - h - pad_top

new_img = np.zeros((new_h, w, c), dtype=np.uint8)
new_img[pad_top:pad_top+h, :, :] = img

# Top padding: mirror the top pad_top pixels
top_patch = img[0:pad_top, :, :]
top_patch_flipped = cv2.flip(top_patch, 0)
new_img[0:pad_top, :, :] = top_patch_flipped

# Bottom padding: User suggests: "use the same trick as the top. but not too much hight, 50% the hight and repeat, then it would not get the '第三个佛头' or some object."
# Let's say we take the bottom N pixels. Let's find an N that avoids the lotus.
# But wait, if the lotus is AT the bottom, any N will hit it.
# Let's assume the lotus does not reach the absolute bottom. Let's try N=20.
N = 20
bottom_strip = img[h-N:h, :, :] # The very bottom 20 pixels

# We need to fill pad_bottom (118 pixels).
# If we flip and repeat this strip:
strip_flipped = cv2.flip(bottom_patch, 0) # Wait, this is wrong.
strip_flipped = cv2.flip(bottom_strip, 0)

# Repeat this flipped strip and the normal strip to fill pad_bottom
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
