from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
VFX_ROOT = ROOT / "assets" / "textures" / "vfx"
CACHE_PATH = VFX_ROOT / "visible_region_cache.json"


def looks_like_generated_background(rgb: tuple[int, int, int], edge_samples: list[tuple[int, int, int]]) -> bool:
    r, g, b = rgb
    delta = max(abs(r - g), abs(g - b), abs(r - b)) / 255.0
    luminance = (r + g + b) / (3.0 * 255.0)
    if delta > 0.08:
        return False
    if luminance < 0.16 or luminance > 0.82:
        return False
    if delta <= 0.02 and 0.22 <= luminance <= 0.66:
        return True
    for sr, sg, sb in edge_samples:
        distance = (abs(r - sr) + abs(g - sg) + abs(b - sb)) / 255.0
        if distance <= 0.16:
            return True
    return False


def compute_region(image_path: Path) -> list[int]:
    image = Image.open(image_path).convert("RGBA")
    width, height = image.size
    pixels = image.load()

    edge_samples: list[tuple[int, int, int]] = []
    for x in range(width):
        edge_samples.append(pixels[x, 0][:3])
        edge_samples.append(pixels[x, height - 1][:3])
    for y in range(height):
        edge_samples.append(pixels[0, y][:3])
        edge_samples.append(pixels[width - 1, y][:3])

    row_counts = [0] * height
    col_counts = [0] * width
    left, upper, right, lower = width, height, -1, -1

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a < int(0.12 * 255):
                continue
            if looks_like_generated_background((r, g, b), edge_samples):
                continue
            left = min(left, x)
            upper = min(upper, y)
            right = max(right, x)
            lower = max(lower, y)
            row_counts[y] += 1
            col_counts[x] += 1

    if right < left or lower < upper:
        return [0, 0, width, height]

    row_threshold = max(4, round(width * 0.015))
    col_threshold = max(4, round(height * 0.02))
    dense_top, dense_bottom = upper, lower
    dense_left, dense_right = left, right

    for y in range(height):
        if row_counts[y] >= row_threshold:
            dense_top = y
            break
    for y in range(height - 1, -1, -1):
        if row_counts[y] >= row_threshold:
            dense_bottom = y
            break
    for x in range(width):
        if col_counts[x] >= col_threshold:
            dense_left = x
            break
    for x in range(width - 1, -1, -1):
        if col_counts[x] >= col_threshold:
            dense_right = x
            break

    x0 = max(0, dense_left - 8)
    y0 = max(0, dense_top - 8)
    x1 = min(width, dense_right + 9)
    y1 = min(height, dense_bottom + 9)
    return [x0, y0, x1 - x0, y1 - y0]


def build_cache() -> dict:
    regions: dict[str, list[int]] = {}
    for image_path in sorted(VFX_ROOT.rglob("*.png")):
        rel = image_path.relative_to(ROOT).as_posix()
        resource_path = f"res://{rel}"
        regions[resource_path] = compute_region(image_path)
    return {
        "schema_version": 1,
        "regions": regions,
    }


def main() -> None:
    payload = build_cache()
    CACHE_PATH.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"wrote {CACHE_PATH}")
    print(f"entries={len(payload['regions'])}")


if __name__ == "__main__":
    main()
