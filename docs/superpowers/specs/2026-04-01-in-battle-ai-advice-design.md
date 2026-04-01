# In-Battle AI Advice Design

## Goal

Add an in-match `AI Advice` feature for local human-vs-human battles that can coach the current turn player during the game.

The feature should sit in the existing top-right action area, immediately to the left of `Zeus Help`, and send the current player view of the match plus both full 60-card decklists to ZenMux-backed AI analysis.

The AI should return:

- the recommended main line for the rest of the current turn
- conditional branches when draw, search, or other uncertain outcomes change the best line
- longer-horizon prize-trade guidance and resource planning
- concrete explanations for why the line is best

The tone target is high-level competitive coaching: specific, disciplined, and practical, not generic filler.

## Canonical Names

Use ASCII identifiers for planning, persistence, and tests. UI copy can be localized separately.

- feature id: `in_battle_ai_advice`
- scene button node: `BtnAiAdvice`
- service class: `BattleAdviceService`
- session store class: `BattleAdviceSessionStore`
- context builder class: `BattleAdviceContextBuilder`
- prompt builder class: `BattleAdvicePromptBuilder`
- overlay title id: `ai_advice_overlay`
- docked panel id: `ai_advice_panel`

Exact localized UI strings for the first release, stored as escaped Unicode literals to keep the spec unambiguous in ASCII-only tooling:

- advice button text: `"\u0041\u0049\u5efa\u8bae"` (localized AI Advice button)
- overlay title: `"\u0041\u0049\u5efa\u8bae"` (localized AI Advice title)
- overlay action rerun: `"\u91cd\u65b0\u5206\u6790"` (localized rerun action)
- overlay action pin: `"\u56fa\u5b9a\u5230\u4fa7\u8fb9"` (localized pin action)
- overlay action close: `"\u5173\u95ed"` (localized close action)
- docked panel title: `"\u0041\u0049\u5efa\u8bae"` (localized AI Advice panel title)

## Scope

This design covers:

- a new `AI Advice` button in local two-player battles
- in-match AI analysis generation during an active match
- a match-long persistent AI advice session
- incremental context sync using existing battle recording artifacts
- structured advice output shown in an overlay and a dockable side panel
- persisted advice artifacts under the current match directory

This design does not cover:

- automatic advice generation every turn
- advice for `VS_AI`, self-play, benchmark, or tuner modes
- local best-line search or exhaustive simulation
- model/provider selection UI
- replacing the existing post-match AI review feature

## Product Decisions

- supported mode: local human-vs-human only
- trigger: manual button press, repeatable at any point in the match
- session scope: one ZenMux-backed advice session per match, not per turn
- hidden information policy:
  - include both full 60-card decklists
  - include only information visible to the current turn player
  - do not reveal opponent hand contents
  - do not reveal prize card identities
  - do not reveal deck order
- output structure:
  - `current_turn_main_line`
  - `conditional_branches`
  - `prize_plan`
  - `why_this_line`
  - `risk_watchouts`
  - `confidence`
- UI pattern:
  - first show the result in an overlay
  - optionally pin the latest advice into a docked side panel

## Existing Context

The repository already has the building blocks needed for this feature:

- `BattleScene` already owns the top-right battle actions and in-battle overlays
- `BattleRecorder` already writes `summary.log`, `detail.jsonl`, `match.json`, `turns.json`, and `llm_digest.json`
- `ZenMuxClient` already provides a thin JSON request wrapper
- the recent post-match `BattleReviewService` pipeline already establishes a pattern for prompt builders, data builders, artifact storage, and UI integration

The main design constraint is to reuse those pieces and avoid changes to battle rules or action-resolution logic.

## Problem

The project can already record enough structured battle data to support strong AI coaching, but the player cannot ask for advice during a live human-vs-human game.

Today, a player who wants help with:

- how to sequence the rest of the turn
- which resource to conserve
- whether to chase a short KO line or preserve a better prize map
- how to plan for the next one to two turns

has no in-game assistant flow.

The missing pieces are:

- an in-battle entry point
- a match-long advice session model
- an incremental context builder that reuses existing logs
- a UI presentation that fits the current battle screen

## Design

### 1. Add a parallel advice pipeline

Do not mix the new feature into battle rules, legal action generation, or effect resolution.

Add a parallel read-only advice pipeline:

- `BattleScene`
  - owns the button, overlay, and docked panel
  - triggers advice generation
- `BattleAdviceService`
  - orchestrates the advice request lifecycle
- `BattleAdviceContextBuilder`
  - builds the current request payload from the live battle state and recorded artifacts
- `BattleAdvicePromptBuilder`
  - owns prompt instructions and JSON output contracts
- `BattleAdviceSessionStore`
  - persists match-long session state and advice artifacts
- `ZenMuxClient`
  - remains the only network boundary

This keeps the advice feature isolated and testable.

### 2. Reuse one advice session for the whole match

The feature should create one advice session per match, stored under that match's recording directory.

The session should survive repeated button presses during the same match and maintain:

- a stable `session_id`
- how many requests have already been sent
- which detailed events have already been synchronized
- the most recent advice summary
- the most recent player-view context marker

This session is not a provider-specific chat transcript mirror. It is the game's stable local record of what has already been synchronized and what the latest strategic framing was.

### 3. Build requests from current player visibility plus decklists

Every advice request must combine four context layers.

#### Layer A: session envelope

- `session_id`
- `request_index`
- `last_advice_summary`
- `current_player_index`

#### Layer B: visibility rules

Explicitly tell the model what is and is not known:

- known:
  - current board state
  - both discard piles
  - both active and benched Pokemon details
  - public stadium / lost zone / VSTAR usage state
  - the acting player's hand
  - both full decklists
- unknown:
  - opponent hand contents
  - prize identities
  - deck order

This prevents the model from quietly assuming hidden information.

#### Layer C: current position

Build a fresh full snapshot at request time using existing battle-state serialization patterns:

- turn number
- phase
- current player index
- public board state
- public zone state
- acting player's hand
- both decklists
- action-use flags such as supporter / energy / stadium / retreat usage

This layer should be generated from live state, not reconstructed from stale logs.

#### Layer D: delta since last advice

Reuse the existing recording outputs instead of inventing a second logging system.

Primary sources:

- `summary.log` for compact human-readable turn flow
- `detail.jsonl` for exact action and choice events

For repeated button presses, only include:

- detail events with `event_index > last_synced_event_index`
- a compact summary of the newest coarse-log lines
- a current full snapshot so the model always sees the latest board

This keeps later requests smaller while preserving continuity.

### 4. Persist advice artifacts under the match directory

Store advice outputs under:

- `user://match_records/<match_id>/advice/session.json`
- `user://match_records/<match_id>/advice/latest_advice.json`
- `user://match_records/<match_id>/advice/latest_success.json`
- `user://match_records/<match_id>/advice/advice_request_001.json`
- `user://match_records/<match_id>/advice/advice_response_001.json`

and so on for later requests.

#### `session.json`

Canonical local session state:

```json
{
  "session_id": "match_20260401_001",
  "created_at": "2026-04-01 23:10:00",
  "updated_at": "2026-04-01 23:18:20",
  "request_count": 2,
  "last_synced_event_index": 184,
  "last_synced_turn_number": 7,
  "last_advice_summary": "This turn should prioritize stabilizing the prize race with Boss pressure next turn.",
  "last_player_view_index": 0
}
```

#### `latest_advice.json`

Canonical record of the newest completed advice attempt, whether it succeeded or failed.

It should contain:

- status
- generated timestamp
- session id
- request index
- turn number
- player index
- structured advice sections, if successful
- errors, if any

#### `latest_success.json`

Canonical UI-facing result for the newest successful advice response.

Rules:

- on success:
  - write both `latest_advice.json` and `latest_success.json`
- on failure:
  - write only `latest_advice.json`
  - preserve the existing `latest_success.json` unchanged

This removes ambiguity between "latest attempt" and "latest usable advice".

`session.json` should also expose:

- `latest_attempt_status`
- `latest_attempt_request_index`
- `latest_success_request_index`

If a request fails, the session file should remain valid and the last successful advice remains available through `latest_success.json`.

### 5. Keep the output structure strict and layered

The AI response should be structured JSON, then formatted by the client into the overlay and side panel.

Required logical sections:

- `strategic_thesis`
  - one-sentence statement of the turn's real job
- `current_turn_main_line`
  - ordered step objects for the rest of this turn
- `conditional_branches`
  - conditional branch objects for uncertain outcomes
- `prize_plan`
  - prize-plan objects for the next one to two turns
- `why_this_line`
  - concrete reasons tied to board state, resources, and sequencing
- `risk_watchouts`
  - risk objects describing what can go wrong and how to hedge
- `confidence`
  - low / medium / high
- `summary_for_next_request`
  - a compact assistant summary to persist into the next advice request

The most important design rule is that the model must not blend future speculation into `current_turn_main_line`. That section is for the best executable line from the current position. Uncertain follow-ups belong in `conditional_branches`.

Fixed item shapes for first-release planning and tests:

- `current_turn_main_line`: `[{ "step": 1, "action": "string", "why": "string" }]`
- `conditional_branches`: `[{ "if": "string", "then": ["string"] }]`
- `prize_plan`: `[{ "horizon": "this_turn|next_turn|next_two_turns", "goal": "string" }]`
- `why_this_line`: `["string"]`
- `risk_watchouts`: `[{ "risk": "string", "mitigation": "string" }]`

First-release localized section headings in the UI:

- `current_turn_main_line` -> `"\u672c\u56de\u5408\u4e3b\u7ebf"` (localized current-turn heading)
- `conditional_branches` -> `"\u6761\u4ef6\u5206\u652f"` (localized branches heading)
- `prize_plan` -> `"\u62ff\u5956\u8282\u594f\u5224\u65ad"` (localized prize-plan heading)
- `why_this_line` -> `"\u539f\u56e0\u8bf4\u660e"` (localized explanation heading)
- `risk_watchouts` -> `"\u98ce\u9669\u63d0\u9192"` (localized risk heading)
- `confidence` -> `"\u7f6e\u4fe1\u5ea6"` (localized confidence heading)

### 6. UI flow

#### Button placement

Add the `BtnAiAdvice` button immediately to the left of the existing `BtnZeusHelp` button in the battle top bar.

#### Overlay flow

When pressed:

1. Open an advice overlay.
2. Show a loading state while advice generation is running.
3. Replace loading with the structured advice result.
4. Expose actions:
   - re-run analysis
   - pin to side panel
   - close

The overlay is the first-read surface and should reuse the style language of the existing review overlay where practical.

#### In-flight behavior

Repeated requests are allowed across the match, but not while a request is already running.

Concurrency rule for the first release:

- if `latest_attempt_status == "running"`:
  - disable the `BtnAiAdvice` button
  - disable the overlay rerun action
  - ignore extra press events
  - do not queue, cancel, or start a parallel request
- when the request completes:
  - re-enable the button and rerun action

This keeps `request_count`, sync cursors, and network behavior deterministic.

#### Docked side panel

If the player selects the pin action, show a dockable advice panel beside the existing right-side information area.

The panel should:

- show the latest advice result
- support collapse / expand
- preserve the latest content while the player continues playing
- update when a later advice request finishes

The existing battle log stays in place. The advice panel is additive, not a replacement.

### 7. Failure handling

Failures must never interrupt the battle itself.

If a request fails:

- show the failure state in the overlay and docked panel
- preserve the last successful advice result
- do not advance `last_synced_event_index`
- allow immediate retry

If session files are missing or corrupted:

- rebuild a new local advice session for the current match
- keep the battle playable
- surface a user-visible but non-fatal error

If ZenMux returns malformed JSON:

- store the raw response in the per-request artifact
- mark the request as failed
- leave the session resumable

### 8. Explicit persistence and payload contracts

To keep planning and testing unambiguous, the first implementation plan should treat these file contracts as fixed.

#### `session.json`

```json
{
  "session_id": "string",
  "created_at": "string",
  "updated_at": "string",
  "request_count": 0,
  "last_synced_event_index": 0,
  "last_synced_turn_number": 0,
  "last_advice_summary": "string",
  "last_player_view_index": 0,
  "latest_attempt_status": "idle|running|completed|failed",
  "latest_attempt_request_index": 0,
  "latest_success_request_index": 0
}
```

#### `latest_advice.json`

```json
{
  "status": "completed|failed",
  "session_id": "string",
  "request_index": 0,
  "turn_number": 0,
  "player_index": 0,
  "generated_at": "string",
  "advice": {},
  "errors": []
}
```

#### `latest_success.json`

Same shape as `latest_advice.json`, but only written after successful requests.

#### advice request envelope

```json
{
  "schema_version": "battle_advice_v1",
  "session": {
    "session_id": "string",
    "request_index": 0,
    "last_advice_summary": "string",
    "current_player_index": 0
  },
  "visibility_rules": {
    "known": [],
    "unknown": []
  },
  "current_position": {},
  "delta_since_last_advice": {
    "summary_lines": [],
    "detail_events": []
  }
}
```

#### advice response payload

```json
{
  "schema_version": "battle_advice_v1",
  "strategic_thesis": "string",
  "current_turn_main_line": [
    { "step": 1, "action": "string", "why": "string" }
  ],
  "conditional_branches": [
    { "if": "string", "then": ["string"] }
  ],
  "prize_plan": [
    { "horizon": "this_turn|next_turn|next_two_turns", "goal": "string" }
  ],
  "why_this_line": [],
  "risk_watchouts": [
    { "risk": "string", "mitigation": "string" }
  ],
  "confidence": "low|medium|high",
  "summary_for_next_request": "string"
}
```

#### failed attempt envelope

For failed requests, `latest_advice.json` should use this normalized structure:

```json
{
  "status": "failed",
  "session_id": "string",
  "request_index": 0,
  "turn_number": 0,
  "player_index": 0,
  "generated_at": "string",
  "advice": {},
  "errors": [
    {
      "stage": "request|parse|response",
      "error_type": "string",
      "message": "string",
      "http_code": 0
    }
  ],
  "raw_provider_response": "string"
}
```

Per-request debug artifacts should mirror this rule:

- `advice_request_<n>.json`: exact request envelope sent to ZenMux
- `advice_response_<n>.json`: normalized successful response or normalized failed envelope, including raw provider response when available

### 9. Prompting and model guidance

Prompting should live only in `BattleAdvicePromptBuilder`.

The first release should define:

- request schema version: `battle_advice_v1`
- response schema version: `battle_advice_v1`
- prompt builder constant: `BATTLE_ADVICE_SCHEMA_VERSION = "battle_advice_v1"`

The prompt must explicitly instruct the model to:

- use only the provided data
- honor the declared hidden-information limits
- focus on competitive sequencing and prize mapping
- avoid generic filler
- explain recommendations concretely
- separate executable turn steps from uncertain branches
- return JSON only with fixed keys

The response schema should be strict enough that the UI never needs to parse freeform prose blobs.

### 10. Testing

#### UI coverage

- the top bar includes `BtnAiAdvice` immediately left of `BtnZeusHelp`
- pressing the button opens the advice overlay
- loading, success, failure, and retry states render correctly
- the localized pin action shows and updates the docked panel

#### Session coverage

- a match creates at most one advice session
- repeated requests increment `request_count` and reuse `session_id`
- later requests only include unsynced events plus a fresh snapshot
- failed requests do not advance the sync cursor

#### Context-builder coverage

- acting player hand is included
- opponent hand contents are excluded
- full 60-card decklists are included
- prize identities and deck order are excluded
- current board state and public zones are included

#### Prompt / client coverage

- prompt payload uses `battle_advice_v1`
- ZenMux responses normalize into the structured advice contract
- malformed provider responses surface as non-fatal failures

#### Regression coverage

- two-player handover flow still works
- existing battle recording output still works
- existing post-match AI review flow still works
- `VS_AI` mode does not expose or enable the new advice flow

## Non-Goals

- automatically popping advice each turn
- turning the feature into a rules engine
- building a local search planner in this release
- adding account-level or cloud-synced long-term sessions
- merging this feature into the post-match review pipeline

## Recommended Implementation Shape

To minimize risk, implement in this order:

1. session store and payload builders
2. prompt builder and service orchestration
3. overlay flow
4. docked side panel
5. regression and integration tests

That order reuses the already-established review architecture while keeping battle logic untouched.
