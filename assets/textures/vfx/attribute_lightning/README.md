# Lightning Attribute VFX Package

This directory stores reusable battle VFX assets for the Lightning attribute.

## Visual Rule

Lightning should read as one hot electric subject with a white-hot core, cyan outer glow, and thin branching arcs. Keep the effect impact-first and readable in battle rather than turning it into a beam-heavy silhouette.

## Playback Model

`impact-first`

Use the charge and travel layers only as support. The impact bloom should stay dominant, with residue acting as cleanup rather than a second subject.

## Assets

- `charge/charge_orb.png` - compact pre-strike orb and sparking ring
- `travel/travel_core.png` - short directional bolt core
- `impact/impact_bloom.png` - target-hit flash and spike bloom
- `residue/residue_sparks.png` - fading afterglow spark cluster

## Package Files

- `manifest.json` - machine-readable package inventory
- `prompts.json` - regeneration prompt set
- `*/**/*.json` - per-asset prompt sidecars

The source textures in this package were generated locally as transparent PNGs and tuned to stay readable on top of battle overlays.
