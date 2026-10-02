from pathlib import Path
import json
from PIL import Image, ImageDraw

# Native icon matching the simple violet Dot palette; vector shapes are drawn
# at four times the final resolution for smooth edges, with an opaque background.
root = Path(__file__).resolve().parents[1]
size = 4096
image = Image.new("RGB", (size, size), "#e8edff")
draw = ImageDraw.Draw(image)
scale = size / 64
def box(coords):
    return tuple(round(x * scale) for x in coords)
draw.ellipse(box((14, 10, 50, 52)), fill="#778bed")
draw.rounded_rectangle(box((14, 29, 50, 51)), radius=round(9 * scale), fill="#778bed")
draw.ellipse(box((22, 25, 28, 35)), fill="#263360")
draw.ellipse(box((36, 25, 42, 35)), fill="#263360")
draw.arc(box((27, 35, 37, 43)), 15, 165, fill="#263360", width=round(2 * scale))
target = root / "Sources/Assets.xcassets/AppIcon.appiconset"
target.mkdir(parents=True, exist_ok=True)
image.resize((1024, 1024), Image.Resampling.LANCZOS).save(target / "AppIcon.png")
(target / "Contents.json").write_text(json.dumps({"images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": {"author": "xcode", "version": 1}}, indent=2), encoding="utf-8")
(target.parent / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2), encoding="utf-8")
print("Created opaque 1024 x 1024 app icon")
