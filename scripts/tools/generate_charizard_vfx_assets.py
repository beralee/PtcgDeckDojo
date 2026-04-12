from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from google import genai
from google.genai import types
from PIL import Image


MODEL_ID = "google/gemini-3.1-flash-image-preview"
DEFAULT_OUTPUT_ROOT = Path("assets/textures/vfx/charizard_ex")
DEFAULT_VARIANTS = ("short_burst", "mid_stream", "finisher_stream")
API_ENV_NAME = "ZENMUX_API_KEY"


@dataclass(frozen=True)
class AssetJob:
    variant: str
    asset_name: str
    output_path: Path
    prompt: str


EXPECTED_DIRECTION = {
    "flame_stream_core": "right_heavy",
    "impact_bloom_flipbook": "neutral",
    "embers_smoke_flipbook": "neutral",
}


def build_charizard_jobs(output_root: Path, variants: Iterable[str] | None = None) -> list[AssetJob]:
    selected_variants = list(variants or DEFAULT_VARIANTS)
    jobs: list[AssetJob] = []
    for variant in selected_variants:
        jobs.extend(
            [
                AssetJob(variant, "flame_stream_core", output_root / variant / "flame_stream_core.png", _build_prompt(variant, "flame_stream_core")),
                AssetJob(variant, "impact_bloom_flipbook", output_root / variant / "impact_bloom_flipbook.png", _build_prompt(variant, "impact_bloom_flipbook")),
                AssetJob(variant, "embers_smoke_flipbook", output_root / variant / "embers_smoke_flipbook.png", _build_prompt(variant, "embers_smoke_flipbook")),
            ]
        )
    return jobs


def _build_prompt(variant: str, asset_name: str) -> str:
    variant_map = {
        "short_burst": "short concentrated flamethrower burst",
        "mid_stream": "sustained medium-length flamethrower stream",
        "finisher_stream": "heavy finishing flamethrower blast",
    }
    asset_map = {
        "flame_stream_core": "main flame stream core layer, long horizontal fire jet with bright white-yellow center",
        "impact_bloom_flipbook": "4-frame horizontal flipbook sprite sheet of a fiery impact bloom explosion at contact",
        "embers_smoke_flipbook": "4-frame horizontal flipbook sprite sheet of lingering embers and smoke after impact",
    }
    asset_specific = {
        "flame_stream_core": (
            "Asset-specific constraints: must contain real transparent alpha, no baked dark backdrop, no checkerboard, "
            "no gray matte, no fake transparency preview pattern, clean fast flamethrower body with a tapered tip"
        ),
        "impact_bloom_flipbook": (
            "Asset-specific constraints: compact forward-facing impact bloom, transparent RGBA sprite sheet, exactly 4 frames in one horizontal strip, no 2x2 grid, no collage layout, keep frames tightly packed"
        ),
        "embers_smoke_flipbook": (
            "Asset-specific constraints: light embers and smoke only, transparent RGBA sprite sheet, exactly 4 frames in one horizontal strip, no 2x2 grid, no collage layout, no opaque backdrop"
        ),
    }
    return (
        "Use case: stylized-concept\n"
        "Asset type: 2D battle VFX texture for a Pokemon-like attack animation\n"
        f"Primary request: create a {asset_map[asset_name]} for Charizard ex using a {variant_map[variant]}\n"
        "Scene/backdrop: transparent background, isolated effect only, no background\n"
        "Subject: flame effect only, no Pokemon body, no arena, no UI\n"
        "Style/medium: realistic flame structure with animated silhouette and color, polished game VFX asset\n"
        "Composition/framing: right-facing side-view horizontal attack effect, tightly framed around the flame for easy compositing, clean flamethrower stream silhouette\n"
        "Lighting/mood: intense hot core, dramatic high-energy attack, cinematic but clean\n"
        "Color palette: bright white-yellow core, saturated orange-red outer flame, small amount of dark smoke where appropriate\n"
        "Materials/textures: turbulent fire, layered heat, natural combustion detail, crisp edges for compositing\n"
        f"{asset_specific[asset_name]}\n"
        "Constraints: transparent background, no text, no watermark, no Pokemon body, no trainer, no environment, no card frame\n"
        "Avoid: black background, solid backdrop, extra objects, interface elements, logos, checkerboard, transparency preview pattern, cropped-off flame tip\n"
        "Important negative constraints: do not include checkerboard or transparency preview pattern, do not add a giant fireball head unless explicitly requested, keep it as a clean flamethrower stream, avoid decorative aura rings\n"
    )


def _load_api_key() -> str:
    import os

    process_value = os.environ.get(API_ENV_NAME)
    if process_value:
        return process_value

    if sys.platform.startswith("win"):
        import winreg

        for hive, subkey in (
            (winreg.HKEY_CURRENT_USER, r"Environment"),
            (winreg.HKEY_LOCAL_MACHINE, r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment"),
        ):
            try:
                with winreg.OpenKey(hive, subkey) as key:
                    value, _ = winreg.QueryValueEx(key, API_ENV_NAME)
                    if value:
                        return value
            except FileNotFoundError:
                continue
            except OSError:
                continue

    raise RuntimeError("ZENMUX_API_KEY not found in process env or Windows environment registry")


def _make_client(api_key: str) -> genai.Client:
    return genai.Client(
        api_key=api_key,
        vertexai=True,
        http_options=types.HttpOptions(api_version="v1", base_url="https://zenmux.ai/api/vertex-ai"),
    )


def _write_sidecar(job: AssetJob, text_parts: list[str]) -> None:
    sidecar_path = job.output_path.with_suffix(".json")
    sidecar_path.write_text(
        json.dumps(
            {
                "model": MODEL_ID,
                "variant": job.variant,
                "asset_name": job.asset_name,
                "output_path": job.output_path.as_posix(),
                "prompt": job.prompt,
                "text_parts": text_parts,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )


def _coerce_to_pil_image(image: object) -> Image.Image:
    if isinstance(image, Image.Image):
        return image
    pil_image = getattr(image, "_pil_image", None)
    if isinstance(pil_image, Image.Image):
        return pil_image
    raise TypeError(f"Unsupported generated image type: {type(image)!r}")


def _has_real_transparency(image: Image.Image) -> bool:
    alpha = image.convert("RGBA").getchannel("A")
    min_alpha, max_alpha = alpha.getextrema()
    return min_alpha < max_alpha


def _looks_like_horizontal_flipbook(image: Image.Image, frame_count: int) -> bool:
    width, height = image.size
    if width <= 0 or height <= 0 or frame_count <= 1:
        return False
    return (float(width) / float(height)) >= max(2.4, float(frame_count) * 0.7)


def remove_checkerboard_background(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    width, height = image.size
    out = image.copy()
    pixels = out.load()
    bg_samples: list[tuple[int, int, int]] = []
    for x in range(width):
        bg_samples.append(image.getpixel((x, 0))[:3])
        bg_samples.append(image.getpixel((x, height - 1))[:3])
    for y in range(height):
        bg_samples.append(image.getpixel((0, y))[:3])
        bg_samples.append(image.getpixel((width - 1, y))[:3])
    unique = {}
    for rgb in bg_samples:
        unique[rgb] = unique.get(rgb, 0) + 1
    background_colors = [rgb for rgb, _count in sorted(unique.items(), key=lambda item: item[1], reverse=True)[:6]]

    stack = []
    for x in range(width):
        stack.append((x, 0))
        stack.append((x, height - 1))
    for y in range(height):
        stack.append((0, y))
        stack.append((width - 1, y))
    visited = set()
    while stack:
        x, y = stack.pop()
        if (x, y) in visited or x < 0 or y < 0 or x >= width or y >= height:
            continue
        visited.add((x, y))
        r, g, b, a = pixels[x, y]
        if a == 0:
            continue
        if not _looks_like_checker_background((r, g, b), background_colors):
            continue
        pixels[x, y] = (r, g, b, 0)
        stack.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    return out


def normalize_direction_if_needed(image: Image.Image, expected: str) -> Image.Image:
    if expected == "neutral":
        return image
    image = image.convert("RGBA")
    width, height = image.size
    left_weight = 0.0
    right_weight = 0.0
    for y in range(height):
        for x in range(width):
            r, g, b, a = image.getpixel((x, y))
            if a == 0:
                continue
            weight = a + max(0, r - g) * 0.7 + max(0, g - b) * 0.2
            if x < width // 2:
                left_weight += weight
            else:
                right_weight += weight
    if expected == "right_heavy" and left_weight > right_weight:
        return image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    if expected == "left_heavy" and right_weight > left_weight:
        return image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return image


def crop_to_alpha_bounds(image: Image.Image, padding: int = 12, alpha_threshold: int = 24) -> Image.Image:
    image = image.convert("RGBA")
    width, height = image.size
    bg_samples: list[tuple[int, int, int]] = []
    for x in range(width):
        bg_samples.append(image.getpixel((x, 0))[:3])
        bg_samples.append(image.getpixel((x, height - 1))[:3])
    for y in range(height):
        bg_samples.append(image.getpixel((0, y))[:3])
        bg_samples.append(image.getpixel((width - 1, y))[:3])
    unique = {}
    for rgb in bg_samples:
        unique[rgb] = unique.get(rgb, 0) + 1
    background_colors = [rgb for rgb, _count in sorted(unique.items(), key=lambda item: item[1], reverse=True)[:8]]

    left = width
    upper = height
    right = -1
    lower = -1
    row_counts = [0] * height
    col_counts = [0] * width
    for y in range(height):
        for x in range(width):
            r, g, b, a = image.getpixel((x, y))
            if a < alpha_threshold:
                continue
            if _looks_like_checker_background((r, g, b), background_colors):
                continue
            left = min(left, x)
            upper = min(upper, y)
            right = max(right, x)
            lower = max(lower, y)
            row_counts[y] += 1
            col_counts[x] += 1
    bbox = None if right < left or lower < upper else (left, upper, right + 1, lower + 1)
    row_threshold = max(4, int(width * 0.015))
    col_threshold = max(4, int(height * 0.02))
    dense_rows = [index for index, count in enumerate(row_counts) if count >= row_threshold]
    dense_cols = [index for index, count in enumerate(col_counts) if count >= col_threshold]
    if dense_rows and dense_cols:
        bbox = (
            dense_cols[0],
            dense_rows[0],
            dense_cols[-1] + 1,
            dense_rows[-1] + 1,
        )
    if bbox is None:
        alpha = image.getchannel("A")
        mask = alpha.point(lambda value: 255 if value >= alpha_threshold else 0)
        bbox = mask.getbbox()
        if bbox is None:
            bbox = alpha.getbbox()
        if bbox is None:
            return image
    left = max(0, bbox[0] - padding)
    upper = max(0, bbox[1] - padding)
    right = min(image.width, bbox[2] + padding)
    lower = min(image.height, bbox[3] + padding)
    return image.crop((left, upper, right, lower))


def postprocess_asset(image: Image.Image, asset_name: str) -> Image.Image:
    image = remove_checkerboard_background(image)
    image = normalize_direction_if_needed(image, expected=EXPECTED_DIRECTION.get(asset_name, "neutral"))
    image = crop_to_alpha_bounds(image)
    return image


def _looks_like_checker_background(rgb: tuple[int, int, int], background_colors: list[tuple[int, int, int]]) -> bool:
    r, g, b = rgb
    channel_delta = max(abs(r - g), abs(g - b), abs(r - b))
    if channel_delta > 14:
        return False
    luminance = (r + g + b) / 3.0
    if luminance < 40 or luminance > 190:
        return False
    if channel_delta <= 4 and 55 <= luminance <= 165:
        return True
    for bg in background_colors:
        if sum(abs(c - bc) for c, bc in zip(rgb, bg)) <= 28:
            return True
    return False


def generate_job(client: genai.Client, job: AssetJob) -> None:
    job.output_path.parent.mkdir(parents=True, exist_ok=True)
    last_error: Exception | None = None
    prompt = job.prompt
    for attempt in range(3):
        response = client.models.generate_content(
            model=MODEL_ID,
            contents=[prompt],
            config=types.GenerateContentConfig(response_modalities=["TEXT", "IMAGE"]),
        )
        text_parts: list[str] = []
        processed_image: Image.Image | None = None
        for part in response.parts:
            if part.text is not None:
                text_parts.append(part.text)
            elif part.inline_data is not None:
                image = _coerce_to_pil_image(part.as_image())
                processed_image = postprocess_asset(image, job.asset_name)
        if processed_image is None:
            last_error = RuntimeError(f"No image part returned for {job.asset_name} ({job.variant})")
            continue
        if not _has_real_transparency(processed_image):
            last_error = RuntimeError(f"Generated image remained fully opaque for {job.asset_name} ({job.variant})")
            prompt = (
                f"{job.prompt}\n"
                "Retry instruction: previous attempt baked in a dark backdrop. Return a true RGBA asset with real transparent alpha only."
            )
            continue
        if job.asset_name in ("impact_bloom_flipbook", "embers_smoke_flipbook") and not _looks_like_horizontal_flipbook(processed_image, 4):
            last_error = RuntimeError(f"Generated image did not look like a horizontal flipbook for {job.asset_name} ({job.variant})")
            prompt = (
                f"{job.prompt}\n"
                "Retry instruction: previous attempt was not a single horizontal 4-frame strip. Return exactly 4 frames in one horizontal row with transparent RGBA."
            )
            continue
        processed_image.save(job.output_path)
        _write_sidecar(job, text_parts)
        return
    if last_error != None:
        raise last_error
    raise RuntimeError(f"Failed to generate {job.asset_name} ({job.variant})")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Charizard ex flame VFX textures with ZenMux Gemini image API.")
    parser.add_argument("--variant", choices=DEFAULT_VARIANTS, action="append", help="Only generate the selected variant. Repeat to generate more than one.")
    parser.add_argument("--output-root", type=Path, default=DEFAULT_OUTPUT_ROOT)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--postprocess-only", action="store_true", help="Re-run postprocessing for already generated PNGs without calling the API.")
    args = parser.parse_args()

    jobs = build_charizard_jobs(output_root=args.output_root, variants=args.variant)
    if args.dry_run:
        for job in jobs:
            print(job.output_path.as_posix())
            print(job.prompt)
            print("---")
        return 0

    if args.postprocess_only:
        for job in jobs:
            if not job.output_path.exists():
                continue
            img = Image.open(job.output_path)
            processed = postprocess_asset(img, job.asset_name)
            processed.save(job.output_path)
            print(f"[postprocess] {job.variant}/{job.asset_name} -> {job.output_path.as_posix()}")
        return 0

    client = _make_client(_load_api_key())
    for job in jobs:
        print(f"[generate] {job.variant}/{job.asset_name} -> {job.output_path.as_posix()}")
        generate_job(client, job)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
