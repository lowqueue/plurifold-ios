#!/usr/bin/env python3
"""Render the repo's vector icon into the iPhone/iPad asset catalog.

The PNGs are checked in, so normal Xcode and Codemagic builds need no renderer.
The original SVG retains its animation; PNGs capture the visible cursor on white.
To change the icon, edit design/AppIcon.svg, install CairoSVG==2.8.2, and run this.
"""

from __future__ import annotations

from decimal import Decimal
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Plurifold/Resources/Assets.xcassets"
ICON = ASSETS / "AppIcon.appiconset"
SLOTS = (
    ("iphone", "20", (2, 3)),
    ("iphone", "29", (2, 3)),
    ("iphone", "40", (2, 3)),
    ("iphone", "60", (2, 3)),
    ("ipad", "20", (1, 2)),
    ("ipad", "29", (1, 2)),
    ("ipad", "40", (1, 2)),
    ("ipad", "76", (1, 2)),
    ("ipad", "83.5", (2,)),
    ("ios-marketing", "1024", (1,)),
)


def main() -> None:
    try:
        import cairosvg
    except ImportError as error:
        raise SystemExit("For icon regeneration only: python3 -m pip install CairoSVG==2.8.2") from error

    ICON.mkdir(parents=True, exist_ok=True)
    source = (ROOT / "design/AppIcon.svg").read_bytes()
    rendered: set[int] = set()
    images = []
    for idiom, size, scales in SLOTS:
        for scale in scales:
            pixels = int(Decimal(size) * scale)
            filename = f"AppIcon-{pixels}.png"
            if pixels not in rendered:
                png = cairosvg.svg2png(bytestring=source,
                                      output_width=pixels, output_height=pixels,
                                      background_color="#FFFFFF")
                # Write the returned bytes explicitly so the final PNG is fully
                # flushed before this short-lived rendering process exits.
                (ICON / filename).write_bytes(png)
                rendered.add(pixels)
            images.append({"idiom": idiom, "size": f"{size}x{size}",
                           "scale": f"{scale}x", "filename": filename})
    info = {"author": "xcode", "version": 1}
    (ASSETS / "Contents.json").write_text(json.dumps({"info": info}, indent=2) + "\n")
    (ICON / "Contents.json").write_text(json.dumps({"images": images, "info": info}, indent=2) + "\n")
    print(f"Rendered {len(rendered)} opaque icon sizes for {len(images)} iPhone/iPad/App Store slots.")


if __name__ == "__main__":
    main()
