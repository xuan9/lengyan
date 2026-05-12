from PIL import Image
import numpy as np

# Load current splash image
img = Image.open('lengyan/Assets.xcassets/sutra_splash.imageset/sutra_splash.png')
arr = np.array(img)
h, w, c = arr.shape

# h is 1200, w is 510. The bottom 118 pixels are mirrored.
# Wait, let's just take the row at y = 1000 (which is above the lotus reflection, or maybe the lotus itself?)
# Let's see: original was 964. I mirrored the bottom 118 pixels.
# So the original bottom was at y = 1082 (118 to 1082 was the original image).
# Let's take the row at y = 1081 (the very bottom of the original image).
# The lotus is in the center. We want to erase the lotus from the extended padding.
# So for all rows from 1082 to 1200:
bg_color = np.median(arr[1000:1050, :50, :], axis=(0, 1)).astype(np.uint8)

for y in range(1082, 1200):
    arr[y, :, :] = bg_color

# But wait, what if the lotus starts above 1082 and reflects?
# Yes, the lotus is at the bottom of the original image (y=1082).
# If we just fill the bottom with bg_color, there will be a hard seam between the lotus and the solid color.
# That's actually fine, the lotus base sits on the ground. A solid color below it looks like the ground/margin.
# We can also add some noise to make it look like paper.
noise = np.random.normal(0, 3, (118, w, c)).astype(np.float32)
arr[1082:1200, :, :] = np.clip(arr[1082:1200, :, :].astype(np.float32) + noise, 0, 255).astype(np.uint8)

out = Image.fromarray(arr)
out.save('lengyan/Assets.xcassets/sutra_splash.imageset/sutra_splash.png')
print("Fixed bottom padding!")
