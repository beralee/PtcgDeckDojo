# Water Attribute VFX Notes

## Visual Rule

Shared water attacks use one visual language: a clean cyan-blue splash impact with glossy droplets, a compact crown of spray, and a fading ripple/mist residue. The package is impact-only and must not introduce a travel beam.

## Package Scope

- Root package: `assets/textures/vfx/attribute_water`
- Variant folder: `impact_only`
- Shared use case: fallback water attack VFX across the attribute

## Asset Set

- `water_impact_flipbook.png`: main hit bloom
- `water_spray_droplets.png`: glossy droplets and short streaks
- `water_ripple_ring.png`: soft ripple residue
- `water_residue_mist.png`: low-alpha fading mist

## Prompt Set

Prompts are stored in `assets/textures/vfx/attribute_water/prompt_set.json`. They are written to preserve transparency, remove travel, and keep the splash readable in battle.
