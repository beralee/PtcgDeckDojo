# Metal Attribute VFX Notes

## Visual Rule

Forged-steel collision: silver-white core, gunmetal plates, sharp shard edges, and a few hot orange sparks. The fallback is impact-only, compact, and never beam-like.

## Package Shape

- Root package: `assets/textures/vfx/attribute_metal`
- Variant folder: `impact_only`
- Shared use case: fallback metal attack VFX across the attribute

## Asset Set

- `impact_bloom_flipbook.png`: main impact bloom
- `plate_shard_cluster.png`: fractured plate accents
- `spark_residue.png`: hot spark cleanup layer
- `steel_dust_mist.png`: low-alpha metallic fade residue

## Prompt Set

Prompts are stored in `assets/textures/vfx/attribute_metal/prompts.json`. They keep the look compact, premium, and battle-readable while suppressing beam and travel language.
