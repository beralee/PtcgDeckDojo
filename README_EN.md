# PtcgDeckDojo

[中文](README.md) | [English](README_EN.md)

A local PTCG practice and rules-simulation project built with Godot 4.6 and GDScript.

This repository is not meant to be an official replacement or a commercial product. The goal is to turn PTCG practice, rules validation, card-effect implementation, and regression testing into an open-source project that can keep evolving.

<p align="center">
  <img src="assets/demo_menu.png" alt="PtcgDeckDojo main menu" width="49%" />
  <img src="assets/demo_ai_card.png" alt="PtcgDeckDojo AI deck analysis" width="49%" />
</p>

## In One Sentence

`PtcgDeckDojo` is a local PTCG practice sandbox for Chinese players, with deck import, local card/cache management, playable battle scenes, and an effect system that is being expanded card by card.

## Current Status

The project is already runnable and has a solid base, but it is still far from a finished product.

Please read the current version with the following expectations:

- It already has a main menu, deck management, battle setup, and a battle scene.
- It already has a rules engine, an effect system, bulk audits, and automated tests.
- Many cards are implemented, but many effects still contain bugs, incomplete interactions, or missing edge-case handling.
- A lot of cards currently "work partially" rather than matching tournament behavior in full detail.
- The repository is evolving through a repeated loop of: find issue -> add test -> fix effect -> verify again.

If you want a polished production-ready client, this repository is not there yet.

If you want a runnable, readable, and extendable PTCG training codebase, it is a good fit.

## Highlights

- Deck import: supports importing from `tcg.mik.moe` deck links or deck IDs
- Local cache: card JSON, card images, and deck data are stored in `user://`
- Battle UI: the main gameplay loop is already playable
- AI assistance: includes deck analysis, in-battle advice, and post-match review
- Rules engine: includes turn flow, damage, status, prize cards, retreat, and other core systems
- Effect system: maps card behavior through reusable effect scripts
- Test coverage: includes semantic regression tests, batch card audits, encoding audits, and UI regressions

## AI Features

- Deck analysis: the deck editor can suggest concrete swaps instead of only giving vague archetype advice
- In-battle coaching: the live advice flow uses the visible board, action history, both decklists, and deck strategy notes to suggest a compact best line for the current turn
- Post-match review: after a match, the AI can identify key turns and generate a Chinese review focused on mistakes, pivots, and swing turns
- Hidden-info guardrails: advice is designed around public information and does not assume the opponent's hidden hand, prize identities, or deck order
- Fast regression loop: functional tests and AI/training tests now use separate runners, so day-to-day gameplay verification stays fast

## Project Structure

```text
assets/      UI resources, icons, screenshots
docs/        Design notes, effect framework docs, development docs
scenes/      Godot scenes and UI scripts
scripts/     Data models, rules engine, effects, network, and utility scripts
tests/       Automated tests, regressions, and batch audit entry points
tools/       Local development tools bundled in the repo
```

The rough layering looks like this:

1. `scenes/` handles UI and player interaction.
2. `scripts/data/` contains cards, decks, players, slots, and related models.
3. `scripts/engine/` drives rules validation, state transitions, damage, and effect scheduling.
4. `scripts/effects/` contains reusable or card-specific effect logic.
5. `scripts/network/` handles deck import and card-image sync.
6. `tests/` protects existing behavior while cards and interactions are expanded.

## Development Direction

The main development loop is not just "add more features". It is primarily:

1. Build a stable gameplay and rules foundation.
2. Keep extending card support on top of a unified effect framework.
3. Use batch audits and regression tests to catch missing cards, wrong effects, and interaction gaps.
4. Fix cards one by one or effect family by effect family until they become verifiable.

That is why this repository contains both:

- stable lower-level systems and tests
- card implementations that are still being filled in and corrected

This is not a contradiction. It is the current reality of the project.

## Running The Project

### Requirements

- Godot `4.6.x`
- Windows environment verified
- Initial deck import or card-image sync requires access to `tcg.mik.moe`

### Run Locally

1. Open `project.godot` in Godot.
2. Run `res://scenes/main_menu/MainMenu.tscn`.
3. Import a deck from Deck Management.
4. Go back to battle setup and start a match.

### Run Tests

The repository includes separate headless Godot test entries:

```powershell
# Functional regression
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FunctionalTestRunner.gd'

# AI / training
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/AITrainingTestRunner.gd'
```

Targeted suite example:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FunctionalTestRunner.gd' -- --suite=RuleValidator,GameStateMachine
```

The compatibility entry `res://tests/TestRunner.tscn` is still available and also supports `--group=functional` / `--group=ai_training`.

## Documentation

- [docs/README.md](docs/README.md): documentation index
- [docs/development_setup.md](docs/development_setup.md): environment setup, run flow, and test entry
- [docs/project_status.md](docs/project_status.md): current capability boundaries and known limitations
- [design_document.md](design_document.md): overall design notes
- [DEVELOPMENT_SPEC.md](DEVELOPMENT_SPEC.md): development and coding rules

## About The Implementation

This repository takes rules consistency, code quality, and testing seriously, but its origin should be understood clearly:

- This is a `100% AI coding` project.
- The author is mainly a PTCG enthusiast.
- The author's best result is a City League championship.
- The author is not a professional game programmer.

So this repository is better understood as a high-effort learning and experimentation project, not as a conventional commercial game product.

That also means:

- issues and pull requests are welcome
- rules bugs, interaction bugs, and architecture problems are useful feedback
- but this repository should not be judged as if it were a fully staffed commercial client

## Copyright And Usage

This project involves Pokemon TCG names, images, and rules expression, so the boundaries should be explicit:

- This repository does not bundle user-local cached card data or card images.
- Runtime card data and images are fetched from `tcg.mik.moe`.
- Pokemon, PTCG, and related card content belong to their respective rights holders.
- This project is for learning, research, and community exchange only.
- It is not for commercialization.
- It does not imply any official authorization.

If you fork or continue development, it is recommended to preserve these boundaries.

## Contributing

Issues and pull requests are welcome.

Before contributing, read:

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [DEVELOPMENT_SPEC.md](DEVELOPMENT_SPEC.md)

This repository is relatively strict about UTF-8 encoding, Chinese copy consistency, rules correctness, and regression verification.

## Security

See [SECURITY.md](SECURITY.md).

## License

This project is licensed under the [Apache License 2.0](LICENSE).
