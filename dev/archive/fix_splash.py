from PIL import Image
import numpy as np

# Load original image
img = Image.open('lengyan/Assets.xcassets/fo.imageset/fo.jpg')
arr = np.array(img)
h, w, c = arr.shape

# Target height to be much taller to fill screens
target_h = int(w * 19.5 / 9) # Typical iPhone ratio is ~19.5:9 or 21:9
# target_h for 690 width is ~1495. Let's make it 1600.
new_h = 1600
pad_top = (new_h - h) // 2
pad_bottom = new_h - h - pad_top

new_arr = np.zeros((new_h, w, c), dtype=np.uint8)
new_arr[pad_top:pad_top+h, :, :] = arr

# Sample a clean horizontal strip from the background to pad.
# Top: row 0 is mostly clean sky. Let's average the top 5 rows and replicate.
top_patch = np.mean(arr[0:5, :, :], axis=0, keepdims=True).astype(np.uint8)
for i in range(pad_top):
    new_arr[i:i+1, :, :] = top_patch

# Bottom: row -1 has the lotus! We need to avoid the lotus.
# The lotus is in the middle. Let's find a clean background spot.
# For example, row 1000 (near the bottom), left 100 pixels.
bg_color = np.median(arr[1000:1050, :50, :], axis=(0, 1)).astype(np.uint8)

# Let's create a bottom patch by filling with bg_color
for i in range(pad_top+h, new_h):
    new_arr[i:i+1, :, :] = bg_color

# But wait, a solid color will create a visible hard line if the bottom of the image has gradient.
# Let's blend it!
# Bottom row of the original image has lotus. We need to erase the lotus from the padding.
# Let's take the bottom row, and overwrite the middle 400 pixels with the bg_color.
bottom_row = arr[-1:, :, :].copy()
bottom_row[:, 150:-150, :] = bg_color # middle replaced with bg color

# Now stretch this bottom_row down
for i in range(pad_top+h, new_h):
    new_arr[i:i+1, :, :] = bottom_row

# Save
out = Image.fromarray(new_arr)
# Note: we need to crop the right side to remove the old text?
# The original fo.jpg has text on the right side.
# Let's check where the text is. It's usually on the top right.
# Actually, if we just use fo_clean.jpg... wait, I deleted fo_clean.jpg, but maybe I can just draw over it with bg_color?
# The user already liked the sutra_splash.png I made (minus the 3rd head).
# So my sutra_splash.png has the text already removed!
# Let's just fix the bottom of the CURRENT sutra_splash.png!
