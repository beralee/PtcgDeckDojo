# Darkness Attribute VFX Package

This package defines a shared battle VFX language for darkness attacks.

## Visual Rule

Darkness should read as a compact eclipse: a near-black violet core, amethyst rim light, thin shard accents, and smoky residue that stays tight enough to remain readable in battle. The subject should feel premium and restrained, not cloudy or noisy.

## Playback Model

- Default: `impact-only`
- Optional: short charge knot before impact
- Supporting layers: brief shard streaks, residue smoke, and a compact bloom

## Contents

- `manifest.json`: asset inventory and usage notes
- `prompt_set.json`: reusable generation prompts for each role
- `source/`: generated source textures and their import metadata

## Asset Roles

- `charge_core`: pre-hit darkness knot with a small violet pulse
- `impact_bloom`: compact eclipse bloom for contact moments
- `shard_slash`: directional shard streak for fast attacks
- `residue_smoke`: lingering smoke and particle residue after impact

## Usage Notes

- Keep alpha clean; do not bake in a background color.
- Keep the silhouette compact so the effect survives small battle overlays.
- Prefer violet edge light and smoky black mass over pure gray smoke.
- Avoid full-screen rings, large fog banks, or bright magical symbols that fight the attack subject.
