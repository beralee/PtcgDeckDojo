# Charizard ex Flame VFX Assets

This directory stores generated battle VFX assets for `Charizard ex`.

## Variants

- `short_burst`
- `mid_stream`
- `finisher_stream`

Each variant is expected to contain:

- `flame_stream_core.png`
- `impact_bloom_flipbook.png`
- `embers_smoke_flipbook.png`

Each generated image also has a sidecar JSON file with the exact prompt and returned text parts.

## Generation Tool

Run from the repo root:

```powershell
python scripts/tools/generate_charizard_vfx_assets.py --variant mid_stream
```

The tool reads `ZENMUX_API_KEY` from:

1. Process environment
2. Windows user environment
3. Windows machine environment

It uses the ZenMux Vertex-AI-compatible Gemini image endpoint with:

- model: `google/gemini-3.1-flash-image-preview`

## Current Status

- `mid_stream`: generated
- `short_burst`: pending
- `finisher_stream`: pending

## Retired Assets

The old `mouth_charge` and `flame_stream_outer` experiment files are intentionally retired.
The live Charizard ex VFX currently uses only:

- `flame_stream_core.png`
- `impact_bloom_flipbook.png`
- `embers_smoke_flipbook.png`
