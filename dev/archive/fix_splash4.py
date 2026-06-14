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

# Bottom padding: mirror the bottom pad_bottom pixels
bottom_patch = img[h-pad_bottom:h, :, :].copy()
# We want to remove the lotus from bottom_patch.
# Let's create a mask for the lotus. The lotus is roughly from x=100 to x=590.
mask = np.zeros((pad_bottom, w), dtype=np.uint8)
mask[:, 100:590] = 255 # Mask out the middle part containing the lotus

# Use cv2.inpaint to fill the masked area based on the surrounding paper texture!
# INPAINT_TELEA is good for textures.
inpaint_radius = 50
bottom_patch_inpainted = cv2.inpaint(bottom_patch, mask, inpaint_radius, cv2.INPAINT_TELEA)

# Now we have a perfectly clean paper texture for the bottom patch!
# Flip it vertically so it mirrors seamlessly with the bottom of the original image
bottom_patch_flipped = cv2.flip(bottom_patch_inpainted, 0)
new_img[pad_top+h:new_h, :, :] = bottom_patch_flipped

cv2.imwrite('lengyan/Assets.xcassets/sutra_splash.imageset/sutra_splash.png', new_img)
print("Inpainting successful!")
