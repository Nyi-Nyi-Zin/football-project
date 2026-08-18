from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = root / "frontend/assets/cloud9_agent_icon.png"
image = Image.open(source).convert("RGBA")

outputs = {
    root / "frontend/web/favicon.png": 64,
    root / "frontend/web/icons/Icon-192.png": 192,
    root / "frontend/web/icons/Icon-512.png": 512,
    root / "frontend/web/icons/Icon-maskable-192.png": 192,
    root / "frontend/web/icons/Icon-maskable-512.png": 512,
    root / "frontend/android/app/src/main/res/mipmap-mdpi/ic_launcher.png": 48,
    root / "frontend/android/app/src/main/res/mipmap-hdpi/ic_launcher.png": 72,
    root / "frontend/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png": 96,
    root / "frontend/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png": 144,
    root / "frontend/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png": 192,
}

for path, size in outputs.items():
    path.parent.mkdir(parents=True, exist_ok=True)
    resized = image.resize((size, size), Image.Resampling.LANCZOS)
    resized.save(path, format="PNG", optimize=True)
