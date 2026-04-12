# Metal Attribute VFX Package

Date: 2026-04-12

## Visual Rule

Metal attacks read as a forged-steel collision: a bright silver-white impact core, brushed gunmetal plates, sharp shard edges, and a few hot orange sparks. The shared fallback is impact-only and must stay compact, premium, and never beam-like.

## Package Shape

- One primary impact flipbook for the hard contact moment.
- Three support layers for fractured plates, hot sparks, and fading metallic dust.
- Transparent-only source assets with clean alpha and readable silhouettes against battle overlays.

## Asset Inventory

- `impact_only/impact_bloom_flipbook.png`
- `impact_only/plate_shard_cluster.png`
- `impact_only/spark_residue.png`
- `impact_only/steel_dust_mist.png`

## Prompt Strategy

All prompts lock the same constraints:

- transparent background
- isolated effect only
- no Pokemon body
- no arena or UI
- no travel segment
- no beam
- no decorative rune language
- no checkerboard or solid backdrop

The only difference between prompts is the support role each image is meant to fill.
