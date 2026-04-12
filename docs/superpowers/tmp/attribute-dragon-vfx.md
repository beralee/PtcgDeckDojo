# Dragon Attribute VFX Notes

## Visual Rule

Dragon attacks read as a compact draconic burst: a cobalt-violet core, ember-gold rim light, angular scale shards, and tight impact fragments. The shared style stays impact-first and deliberately avoids a long travel beam.

## Package Scope

- Root package: `assets/textures/vfx/attribute_dragon`
- Shared use case: fallback dragon attack VFX across the attribute

## Asset Set

- `charge_core.png`: compact pre-hit knot with a slight forward pull
- `impact_bloom.png`: primary contact bloom
- `scale_slash.png`: short fractured support slash
- `residue_embers.png`: lingering embers, smoke, and broken scale fragments

## Prompt Set

Prompts are stored in `assets/textures/vfx/attribute_dragon/prompt_set.json`. They are written to preserve transparency, keep the subject compact, and block long-beam or fireball drift.
