# Raging Bolt LLM 20-Game Iteration Report

Date: 2026-04-26

## Scope

Implemented and used a headless batch loop for `LLMRagingBoltDuelTool`:

- 10 games: LLM Raging Bolt vs LLM Raging Bolt.
- 10 games: LLM Raging Bolt vs rules Miraidon.
- Each game recorded match logs under `res://tmp/llm_duels/...`.
- Each game was reviewed first for LLM takeover health, then for gameplay symptoms.

## Critical Finding

The current headless environment did not produce any successful LLM response in these 20 games.

- Mirror run: every player had `requests=1, successes=0, failures=1`.
- Miraidon run: Raging Bolt had `requests=1, successes=0, failures=1` in every game.
- Therefore these games are valid for tool stability and fallback behavior, but they are not valid evidence for prompt quality or LLM strategic strength.

The original unattended 10-game mirror run exceeded 1 hour because each game kept waiting for repeated failed LLM requests. I added a failure budget to the duel tool so unattended runs can degrade to rules after repeated failed LLM calls.

## Implemented Tooling Fix

- `scripts/ai/LLMRagingBoltDuelTool.gd`
  - Added `llm_max_failures_per_strategy`.
  - Default is 2 failures per strategy.
  - If a strategy has no successes and reaches the failure budget, the tool stops requesting LLM for that strategy in the current game and runs rules fallback.
  - Added aggregate `llm_health` to batch reports: total requests, successes, failures, skips, takeover rate, and `all_requests_failed`.

- `scripts/tools/run_llm_raging_bolt_duel.gd`
  - Added `--mode=self_play|miraidon`.
  - Added `--json-output=...`.
  - Added `--llm-max-failures=...`.
  - Reused the existing `LLMRagingBoltDuelTool` instead of creating another incompatible runner.

## Results

Mirror, `seed=202604300`, 10 games:

- Player 0 wins: 6
- Player 1 wins: 4
- Failed/action-cap games: 0
- LLM successful turns: 0

Raging Bolt LLM vs rules Miraidon, `seed=202604400`, 10 games:

- Rules Miraidon wins: 6
- Raging Bolt wins: 4
- Failed/action-cap games: 0
- LLM successful turns: 0

## Per-Game Reflections

| Game | Mode | Seed | Winner | Reflection |
| --- | --- | ---: | ---: | --- |
| 1 | Mirror | 202604300 | P1 | LLM failed before taking over. Fallback completed game by deck-out; do not infer prompt quality. |
| 2 | Mirror | 202604301 | P1 | LLM failed before taking over. Deck-out again suggests fallback over-churn remains an issue. |
| 3 | Mirror | 202604302 | P0 | LLM failed before taking over. Mirror outcome is seed/turn-order noise, not LLM learning signal. |
| 4 | Mirror | 202604303 | P0 | LLM failed before taking over. Long game to turn 22 indicates fallback can loop resource churn too long. |
| 5 | Mirror | 202604304 | P0 | LLM failed before taking over. Use as fallback regression only. |
| 6 | Mirror | 202604305 | P1 | LLM failed before taking over. Deck-out still dominates end condition. |
| 7 | Mirror | 202604306 | P0 | LLM failed before taking over; one local-rule skip happened. Check skip reason only after LLM connectivity is fixed. |
| 8 | Mirror | 202604307 | P0 | LLM failed before taking over. No prompt conclusion. |
| 9 | Mirror | 202604308 | P0 | LLM failed before taking over. No prompt conclusion. |
| 10 | Mirror | 202604309 | P1 | LLM failed before taking over. No prompt conclusion. |
| 11 | Miraidon | 202604400 | Miraidon | LLM failed before taking over. Raging Bolt loss is fallback-vs-Miraidon data. |
| 12 | Miraidon | 202604401 | Miraidon | LLM failed before taking over. Fallback did not convert by turn 18. |
| 13 | Miraidon | 202604402 | Miraidon | LLM failed before taking over. Prize-race loss, not LLM strategy evidence. |
| 14 | Miraidon | 202604403 | Miraidon | LLM failed before taking over. Long game shows fallback can play but not close consistently. |
| 15 | Miraidon | 202604404 | Raging Bolt | LLM failed before taking over. Win came from fallback rules. |
| 16 | Miraidon | 202604405 | Raging Bolt | LLM failed before taking over. Win came from fallback rules. |
| 17 | Miraidon | 202604406 | Miraidon | LLM failed before taking over. Fast loss is a good future replay seed after LLM connectivity is fixed. |
| 18 | Miraidon | 202604407 | Raging Bolt | LLM failed before taking over. Long fallback win. |
| 19 | Miraidon | 202604408 | Miraidon | LLM failed before taking over. Fast enough to inspect after connectivity fix. |
| 20 | Miraidon | 202604409 | Raging Bolt | LLM failed before taking over. Opponent no-Pokemon win; not strategic evidence. |

## Next High-Value Work

1. Fix headless LLM connectivity before any prompt tuning.
   - The tool shows requests were attempted, but every request failed.
   - Check ZenMux/API config availability in headless, certificate handling, and whether `user://logs/llm_decisions_*.jsonl` is writable in this execution mode.

2. Only after LLM success is nonzero, re-run the same 20-game loop and inspect:
   - Whether selected decision-tree branches are rich enough.
   - Whether attack is terminal.
   - Whether route order preserves `setup + charge + attack`.
   - Whether queue execution matches selected tree.

3. Preserve the failure-budget behavior.
   - It prevents one broken LLM endpoint from making long unattended sweeps unusable.

## Commands Used

```powershell
D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe --headless --disable-crash-handler --log-file "D:/ai/code/ptcgtrain/.godot_llm_self_play_10_budgeted.log" --path "D:/ai/code/ptcgtrain" -s res://scripts/tools/run_llm_raging_bolt_duel.gd -- --mode=self_play --games=10 --seed=202604300 --max-steps=260 --llm-wait-timeout-seconds=8 --llm-max-failures=1 --output-root=res://tmp/llm_duels/self_play_budgeted --json-output=res://tmp/llm_duels/self_play_budgeted_summary.json
```

```powershell
D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe --headless --disable-crash-handler --log-file "D:/ai/code/ptcgtrain/.godot_llm_vs_miraidon_10_budgeted.log" --path "D:/ai/code/ptcgtrain" -s res://scripts/tools/run_llm_raging_bolt_duel.gd -- --mode=miraidon --games=10 --seed=202604400 --max-steps=260 --llm-wait-timeout-seconds=8 --llm-max-failures=1 --output-root=res://tmp/llm_duels/vs_miraidon_budgeted --json-output=res://tmp/llm_duels/vs_miraidon_budgeted_summary.json
```
