# Fire Attribute VFX Package

This package defines the shared fire attack look for the repo.

## Visual Rule

Fire attacks read as one hot combustion subject: a white-yellow ignition core, orange-red flame body, ember sparks, and a restrained smoke tail. The impact bloom stays dominant. The travel streak only exists to connect cast to hit. Nothing should collapse into a beam, fireworks, or a fog wall.

## Playback Model

- `cast + travel + impact`
- Shared fallback for all fire attackers
- Center anchors when a precise emit point is unavailable

## Contents

- `source/charge_core.png`
- `source/travel_core.png`
- `source/impact_bloom.png`
- `source/residue_embers.png`
- `manifest.json`
- `prompt_set.json`

## Notes

- The package is intentionally reusable across the attribute.
- The textures are transparent RGBA source assets intended for battle compositing.
- The prompts preserve the charizard/fire lesson of a hot core, but remove hero-specific anatomy and keep the set attribute-wide.
