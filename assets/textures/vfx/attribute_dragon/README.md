# Dragon Attribute VFX Package

This package defines the shared battle VFX language for dragon attacks.

## Visual Rule

Dragon attacks read as a compact draconic burst: a cobalt-violet core, ember-gold rim light, angular scale shards, and tight impact fragments. The subject should feel premium, readable, and battle-ready. No long travel beam, no fog wall, no elemental fireball.

## Playback Model

- Default: `impact-only`
- Optional: short charge knot before impact
- Supporting layers: short fractured slash accent, scale shards, and residue embers

## Contents

- `manifest.json`: asset inventory and usage notes
- `prompt_set.json`: reusable generation prompts for each role
- `source/`: generated source textures and JSON sidecars

## Asset Roles

- `charge_core`: compact pre-hit draconic knot with a slight forward pull
- `impact_bloom`: primary contact bloom and the strongest dragon read
- `scale_slash`: short directional support slash made from fractured scales
- `residue_embers`: lingering ember smoke and broken scale fragments

## Usage Notes

- Keep alpha clean; do not bake in a background color.
- Keep the silhouette compact so the effect survives small battle overlays.
- Prefer cobalt-violet mass and ember-gold edge light over bright fire styling.
- Avoid long beams, full-screen rings, or fog-heavy variants that fight the shared impact-first rule.
