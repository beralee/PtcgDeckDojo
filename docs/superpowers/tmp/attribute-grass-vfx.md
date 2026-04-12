# Grass Attribute VFX Package

Date: 2026-04-12

## Visual Rule

The shared grass attribute style is an impact-only verdant burst. The subject is a compact emerald bloom with a few leaf shards, pollen haze, and vine-like fracture accents. It is deliberately not a travel effect and does not use beam language.

## Package Shape

- One primary impact flipbook for the burst itself.
- Three support layers for sharper leaf detail, residue haze, and vine fracture accents.
- Transparent-only source assets with readable silhouettes against battle overlays.

## Readability Rules

- Keep the bloom small and concentrated.
- Let the bloom be the dominant subject.
- Use the support layers as accents, not as competing centerpieces.
- Preserve clean alpha and avoid baked backgrounds or preview patterns.

## Asset Inventory

- `verdant_burst/impact_bloom_flipbook.png`
- `verdant_burst/leaf_shard_cluster.png`
- `verdant_burst/pollen_haze.png`
- `verdant_burst/vine_fracture_accents.png`

## Prompt Strategy

All prompts lock the same constraints:

- transparent background
- isolated effect only
- no Pokemon body
- no arena or UI
- no travel segment
- no beam
- no checkerboard or solid backdrop

The only difference between prompts is the support role each image is meant to fill.
