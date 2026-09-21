"""Package the approved SEFC artwork as native icons without changing its design.

Run with Python 3 + Pillow on macOS (Apple's iconutil builds the complete ICNS).
"""
from pathlib import Path
from tempfile import TemporaryDirectory
import subprocess

from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "assets" / "branding"


def main():
    source = Image.open(ROOT / "sefc-crest.png").convert("RGBA")
    icon = source.resize((1024, 1024), Image.Resampling.LANCZOS)
    icon.save(ROOT / "sefc-icon.png", optimize=True)
    icon.resize((512, 512), Image.Resampling.LANCZOS).save(
        ROOT / "sefc-splash.png", optimize=True
    )
    icon.save(ROOT / "sefc.ico", format="ICO", sizes=[
        (n, n) for n in (16, 24, 32, 48, 64, 128, 256)
    ])
    with TemporaryDirectory(prefix="sefc-icons-") as temporary:
        iconset = Path(temporary) / "SEFC.iconset"
        iconset.mkdir()
        for size in (16, 32, 128, 256, 512):
            for scale in (1, 2):
                suffix = "@2x" if scale == 2 else ""
                icon.resize((size * scale, size * scale), Image.Resampling.LANCZOS).save(
                    iconset / f"icon_{size}x{size}{suffix}.png"
                )
        subprocess.run(["iconutil", "-c", "icns", "-o", str(ROOT / "sefc.icns"), str(iconset)], check=True)
    print("SEFC PNG, Windows ICO and macOS ICNS icons built.")


if __name__ == "__main__":
    main()
