import cv2
import numpy as np
from PIL import Image

# 1. Load original
img = cv2.imread('lengyan/Assets.xcassets/fo.imageset/fo.jpg')
h, w, c = img.shape # 1084, 690, 3

# We want target height 1600
new_h = 1600
pad_top = (new_h - h) // 2
pad_bottom = new_h - h - pad_top

new_img = np.zeros((new_h, w, c), dtype=np.uint8)

# Place original in the middle
new_img[pad_top:pad_top+h, :, :] = img

# 2. Top padding: Mirror the top pad_top pixels
# The top pad_top pixels of original image are img[0:pad_top, :, :]
top_patch = img[0:pad_top, :, :]
# Flip vertically
top_patch_flipped = cv2.flip(top_patch, 0)
new_img[0:pad_top, :, :] = top_patch_flipped

# 3. Bottom padding: Mirror the bottom pad_bottom pixels, but remove the lotus first!
bottom_patch = img[h-pad_bottom:h, :, :].copy()

# The lotus is roughly in the middle. Let's find the clean paper on the left side.
# Let's say the left 150 pixels are clean paper.
clean_paper = bottom_patch[:, 0:150, :]

# We want to overwrite the lotus (from x=150 to x=540) with the clean paper.
# We can tile the clean_paper across the patch
for x in range(150, w, 150):
    width_to_copy = min(150, w - x)
    bottom_patch[:, x:x+width_to_copy, :] = clean_paper[:, 0:width_to_copy, :]

# To avoid vertical hard seams where the tiled patches meet, we can slightly blur the bottom patch horizontally
# Or just blend the edges.
# Actually, since it's just paper, it might be fine. But let's add a slight horizontal blur to the stitched areas
bottom_patch = cv2.GaussianBlur(bottom_patch, (31, 3), 0)

# Now wait, we need the very top row of bottom_patch (which touches the original image) to perfectly match the original image's bottom row!
# The blur might have changed the top row of the patch, creating a horizontal seam.
# So we only use the cleaned bottom patch for the *reflection*, flipped vertically.
bottom_patch_flipped = cv2.flip(bottom_patch, 0)

# BUT, the reflection means the top row of `bottom_patch_flipped` is the BOTTOM row of `bottom_patch`.
# So it touches the bottom row of `img`.
# The bottom row of `img` has the lotus! 
# If `bottom_patch_flipped` touches it, and `bottom_patch_flipped` DOES NOT have the lotus, there will be a sudden disappearance of the lotus base!
# Wait! The lotus base in `img` goes all the way to the bottom edge.
# If we just cut it off and suddenly there's paper, it looks like a hard cut.
# We need to smoothly fade the lotus out, or just let it cut off. In the user's screenshot, the lotus is already cut off, which looks okay. The problem was the reflection.
# So a hard cut of the lotus is fine, as long as the paper texture matches the paper color at the edge.
# To make it seamless: The top row of `bottom_patch_flipped` should exactly match the bottom row of `img`... EXCEPT where the lotus is.
# So we just do this:
new_img[pad_top+h:new_h, :, :] = bottom_patch_flipped

# 4. Save
cv2.imwrite('lengyan/Assets.xcassets/sutra_splash.imageset/sutra_splash.png', new_img)
print("Fixed bottom padding seamlessly!")
