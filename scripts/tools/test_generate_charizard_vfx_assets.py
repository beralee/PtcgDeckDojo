import unittest
from pathlib import Path

from PIL import Image

from scripts.tools.generate_charizard_vfx_assets import (
    _coerce_to_pil_image,
    _has_real_transparency,
    _looks_like_horizontal_flipbook,
    build_charizard_jobs,
    crop_to_alpha_bounds,
    normalize_direction_if_needed,
    remove_checkerboard_background,
)


class GenerateCharizardVfxAssetsTests(unittest.TestCase):
    def test_build_mid_stream_jobs_uses_expected_output_layout(self) -> None:
        output_root = Path("assets/textures/vfx/charizard_ex")
        jobs = build_charizard_jobs(output_root=output_root, variants=["mid_stream"])

        self.assertEqual(len(jobs), 3)
        self.assertEqual(
            [job.output_path.as_posix() for job in jobs],
            [
                "assets/textures/vfx/charizard_ex/mid_stream/flame_stream_core.png",
                "assets/textures/vfx/charizard_ex/mid_stream/impact_bloom_flipbook.png",
                "assets/textures/vfx/charizard_ex/mid_stream/embers_smoke_flipbook.png",
            ],
        )

    def test_prompts_lock_transparent_realistic_fire_constraints(self) -> None:
        jobs = build_charizard_jobs(output_root=Path("assets/textures/vfx/charizard_ex"), variants=["mid_stream"])
        combined = "\n".join(job.prompt for job in jobs)
        prompt_by_name = {job.asset_name: job.prompt for job in jobs}

        self.assertIn("transparent background", combined)
        self.assertIn("realistic flame structure", combined)
        self.assertIn("animated silhouette and color", combined)
        self.assertIn("no background", combined)
        self.assertIn("no Pokemon body", combined)
        self.assertIn("right-facing", combined)
        self.assertIn("do not include checkerboard", combined)
        self.assertIn("do not add a giant fireball head unless explicitly requested", combined)
        self.assertIn("clean flamethrower stream silhouette", combined)
        self.assertIn("must contain real transparent alpha", prompt_by_name["flame_stream_core"])
        self.assertIn("no baked dark backdrop", prompt_by_name["flame_stream_core"])
        self.assertIn("exactly 4 frames in one horizontal strip", prompt_by_name["impact_bloom_flipbook"])
        self.assertIn("no 2x2 grid", prompt_by_name["impact_bloom_flipbook"])
        self.assertIn("exactly 4 frames in one horizontal strip", prompt_by_name["embers_smoke_flipbook"])

    def test_remove_checkerboard_background_creates_real_alpha(self) -> None:
        img = Image.new("RGBA", (8, 8), (0, 0, 0, 255))
        for y in range(8):
            for x in range(8):
                base = 70 if (x + y) % 2 == 0 else 130
                img.putpixel((x, y), (base, base, base, 255))
        for y in range(2, 6):
            for x in range(2, 6):
                img.putpixel((x, y), (255, 120, 20, 255))

        out = remove_checkerboard_background(img)

        self.assertEqual(out.getpixel((0, 0))[3], 0)
        self.assertEqual(out.getpixel((1, 1))[3], 0)
        self.assertGreater(out.getpixel((3, 3))[3], 0)

    def test_remove_checkerboard_background_scans_all_border_pixels_not_just_corners(self) -> None:
        img = Image.new("RGBA", (8, 8), (255, 120, 20, 255))
        for x in range(8):
            base = 70 if x % 2 == 0 else 130
            img.putpixel((x, 0), (base, base, base, 255))
            img.putpixel((x, 7), (base, base, base, 255))
        for y in range(8):
            base = 70 if y % 2 == 0 else 130
            img.putpixel((0, y), (255, 120, 20, 255))
            img.putpixel((7, y), (base, base, base, 255))

        out = remove_checkerboard_background(img)

        self.assertEqual(out.getpixel((7, 3))[3], 0)
        self.assertEqual(out.getpixel((4, 0))[3], 0)

    def test_normalize_direction_flips_left_heavy_fire_stream(self) -> None:
        img = Image.new("RGBA", (10, 4), (0, 0, 0, 0))
        for x in range(0, 4):
            for y in range(4):
                img.putpixel((x, y), (255, 180, 40, 255))

        out = normalize_direction_if_needed(img, expected="right_heavy")

        left_alpha = sum(out.getpixel((x, 1))[3] for x in range(0, 5))
        right_alpha = sum(out.getpixel((x, 1))[3] for x in range(5, 10))
        self.assertGreater(right_alpha, left_alpha)

    def test_crop_to_alpha_bounds_ignores_faint_border_haze(self) -> None:
        img = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
        for x in range(12):
            img.putpixel((x, 0), (255, 120, 20, 8))
            img.putpixel((x, 11), (255, 120, 20, 8))
        for y in range(12):
            img.putpixel((0, y), (255, 120, 20, 8))
            img.putpixel((11, y), (255, 120, 20, 8))
        for y in range(3, 9):
            for x in range(4, 10):
                img.putpixel((x, y), (255, 160, 40, 255))

        cropped = crop_to_alpha_bounds(img, padding=0, alpha_threshold=24)

        self.assertEqual(cropped.size, (6, 6))

    def test_crop_to_alpha_bounds_ignores_sparse_edge_strays(self) -> None:
        img = Image.new("RGBA", (40, 20), (0, 0, 0, 0))
        for y in range(5, 15):
            for x in range(8, 28):
                img.putpixel((x, y), (255, 160, 40, 255))
        for x in (0, 39):
            img.putpixel((x, 10), (255, 160, 40, 255))
        for y in (0, 19):
            img.putpixel((20, y), (255, 160, 40, 255))

        cropped = crop_to_alpha_bounds(img, padding=0, alpha_threshold=24)

        self.assertEqual(cropped.size, (20, 10))

    def test_coerce_to_pil_image_accepts_sdk_wrapper_with__pil_image(self) -> None:
        pil_img = Image.new("RGBA", (4, 3), (255, 120, 20, 255))

        class _FakeGeneratedImage:
            def __init__(self, wrapped):
                self._pil_image = wrapped

        coerced = _coerce_to_pil_image(_FakeGeneratedImage(pil_img))

        self.assertEqual(coerced.size, (4, 3))

    def test_has_real_transparency_rejects_fully_opaque_image(self) -> None:
        opaque = Image.new("RGBA", (6, 4), (20, 20, 20, 255))
        transparent = Image.new("RGBA", (6, 4), (20, 20, 20, 0))
        transparent.putpixel((3, 2), (255, 120, 20, 255))

        self.assertFalse(_has_real_transparency(opaque))
        self.assertTrue(_has_real_transparency(transparent))

    def test_looks_like_horizontal_flipbook_rejects_grid_like_layout(self) -> None:
        horizontal = Image.new("RGBA", (1200, 250), (0, 0, 0, 0))
        grid_like = Image.new("RGBA", (800, 600), (0, 0, 0, 0))

        self.assertTrue(_looks_like_horizontal_flipbook(horizontal, frame_count=4))
        self.assertFalse(_looks_like_horizontal_flipbook(grid_like, frame_count=4))


if __name__ == "__main__":
    unittest.main()
