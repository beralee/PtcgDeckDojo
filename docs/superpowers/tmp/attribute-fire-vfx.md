# Attribute Fire VFX Notes

## Visual Rule

Fire should read as one hot combustion subject: a white-yellow ignition core, orange-red flame body, ember sparks, and a restrained smoke tail. The impact bloom is the hero; the travel streak is only a readable connector.

## Package

- Root package: `assets/textures/vfx/attribute_fire`
- Package id: `attribute_fire_ember_burst`
- Playback model: `cast + travel + impact`

## Source Assets

- `source/charge_core.png`
- `source/travel_core.png`
- `source/impact_bloom.png`
- `source/residue_embers.png`

## Prompt Set

Prompts are stored in `assets/textures/vfx/attribute_fire/prompt_set.json`. They keep the background transparent, remove character and arena elements, and bias the fire toward a clear hot core with controlled smoke.

## Lessons Applied

- Use the charizard/fire lesson of a bright core and readable flame body.
- Remove hero-specific anatomy so the assets stay attribute-wide.
- Keep the impact bloom dominant and avoid fireworks-style clutter.
