# Fighting Attribute VFX Package

This package defines the shared battle VFX language for fighting-type attacks.

## Visual Rule

Fighting attacks should read as a heavy body-blow impact: a bone-white hit flash, a terracotta-red core, sandy dust fracture, and angular strike shards. The subject should stay compact, grounded, and premium, with no beam language, no fire language, and no lightning-like filaments.

## Playback Model

- `impact-only`
- Shared fallback for all fighting attackers
- No travel segment

## Contents

- `manifest.json` - machine-readable package inventory and asset roles
- `prompt_set.json` - reusable generation prompts for each asset role
- `impact_only/impact_bloom_flipbook.png` - primary 4-frame impact bloom strip
- `impact_only/knuckle_flash.png` - tight pre-hit punch flash
- `impact_only/dust_shatter.png` - angular grit and fracture burst
- `impact_only/residue_grit.png` - fading dust and grit aftermath

## Usage Notes

- Keep the impact bloom as the dominant subject.
- Use the flash, shatter, and residue layers as support rather than competing subjects.
- Preserve transparent alpha and avoid any baked background.
- Keep the silhouette compact so the effect survives small battle overlays.
- Avoid beams, trails, flame tongues, electric filaments, or symbolic aura rings.
