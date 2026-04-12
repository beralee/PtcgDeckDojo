# Colorless Attribute VFX Package

This directory stores reusable battle VFX assets for the Colorless attribute.

## Visual Rule

Colorless should read as a polished pearlescent strike: an ivory-white core, brushed-silver body, champagne highlights, and a few feathered neutral fragments. Keep the effect elegant, readable, and battle-ready rather than leaning into a specific elemental motif.

## Playback Model

`impact-first with short charge support`

The impact bloom is the hero layer. The charge and travel assets should stay restrained support pieces, and residue should clean up the frame without introducing a second subject.

## Assets

- `source/charge_glint.png` - compact pre-strike glint
- `source/travel_sheen.png` - directional neutral streak
- `source/impact_bloom.png` - primary hit bloom
- `source/residue_motes.png` - fading aftermath and cleanup layer

## Package Files

- `manifest.json` - machine-readable package inventory
- `prompt_set.json` - regeneration prompt set
- `source/*.json` - per-asset metadata and prompt sidecars

The source textures in this package are transparent PNGs generated locally to stay readable on top of battle overlays.
