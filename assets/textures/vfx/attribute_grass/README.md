# Grass Attribute VFX Package

This package defines the shared battle VFX language for grass-type attacks.

## Visual Rule

Grass impact is a compact verdant burst: bright emerald core, a few sharp leaf shards, pollen haze, and vine-like fracture accents. It is impact-only. There is no travel segment, no beam, and no fire-style streaking.

## Package Contents

- `manifest.json` - package inventory and asset roles
- `prompts.json` - exact prompt set used to generate the source assets
- `verdant_burst/impact_bloom_flipbook.png` - primary 4-frame impact bloom strip
- `verdant_burst/leaf_shard_cluster.png` - sharp leaf shard accent layer
- `verdant_burst/pollen_haze.png` - soft pollen haze residue layer
- `verdant_burst/vine_fracture_accents.png` - branching vine fracture accent layer

## Usage Notes

- Keep the impact bloom as the dominant subject.
- Use the shard, haze, and fracture layers as support, not as competing subjects.
- Preserve transparent alpha and avoid any baked background.
