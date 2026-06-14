from PIL import Image, ImageDraw, ImageFont
import urllib.request
import os

# Download a beautiful open source Kaiti font (TW-Kai)
font_url = "https://github.com/lxgw/LxgwWenKai/releases/download/v1.330/LXGWWenKai-Regular.ttf"
font_path = "Kaiti.ttf"

if not os.path.exists(font_path):
    print("Downloading Kaiti font...")
    urllib.request.urlretrieve(font_url, font_path)

text = "大\n佛\n頂\n首\n楞\n嚴\n經"
font_size = 120 # High resolution

try:
    font = ImageFont.truetype(font_path, font_size)
except:
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Songti.ttc", font_size, index=0)

# Create a transparent image for the text
# Width needs to fit the character size (120) + padding
# Height needs to fit 7 characters + line spacing
width = 160
height = int(120 * 7 * 1.2)
img = Image.new('RGBA', (width, height), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Color: dark red, similar to original but richer #731E19
# RGB: 115, 30, 25
draw.text((20, 20), text, fill=(115, 30, 25, 255), font=font, spacing=10)

img.save('lengyan/Assets.xcassets/sutra_splash.imageset/sutra_text.png', 'PNG')
print("Text image generated successfully.")
