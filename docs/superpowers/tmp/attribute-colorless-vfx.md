# Colorless Attribute VFX Design Note

## Visual Rule

Colorless should read as a polished pearlescent strike: an ivory-white core, brushed-silver body, champagne highlights, and a few feathered neutral fragments. The effect should feel elegant, readable, and battle-ready rather than tied to a specific elemental motif.

## Package Shape

- `impact-first with short charge support`
- one shared neutral language for the attribute
- keep the impact bloom dominant
- use the travel layer only as a restrained motion support
- let residue clean the frame instead of becoming a second subject

## Asset Set

- `charge_glint` - compact pre-strike glint
- `travel_sheen` - directional neutral streak
- `impact_bloom` - primary hit bloom
- `residue_motes` - fading aftermath and cleanup layer

## Guardrails

- stay transparent and isolated
- avoid saturated elemental color casts
- keep the overlay compact enough for live battle readability
- prefer center anchors until a real emit point is validated

## Delivery

The package lives under `assets/textures/vfx/attribute_colorless/` and is intended to be reused across the shared colorless attribute fallback.
