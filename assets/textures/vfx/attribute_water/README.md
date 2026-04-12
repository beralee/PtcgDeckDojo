# Water Attribute VFX Package

This package defines the shared water attack look for the repo.

## Visual Rule

Water attacks read as a clean cyan-blue splash impact with glossy droplets, a compact crown of spray, and a fading mist/ripple residue. The effect must feel crisp, premium, and battle-readable. No travel beam, no muddy surf, and no heavy foam wall.

## Playback Model

- `impact-only`
- Shared fallback for all water attackers
- No generic travel segment

## Contents

- `impact_only/water_impact_flipbook.png`
- `impact_only/water_spray_droplets.png`
- `impact_only/water_ripple_ring.png`
- `impact_only/water_residue_mist.png`
- `asset_manifest.json`
- `prompt_set.json`

## Notes

- The package is intentionally reusable across the attribute.
- The main subject is the splash impact, not a projectile.
- The textures are transparent RGBA source assets intended for battle compositing.
