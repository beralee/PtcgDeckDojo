# AI Battle Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an in-game AI battle review flow for local two-player matches that lets users manually generate and view a persisted ZenMux-backed review focused on better choices for key turns on both sides.

**Architecture:** Build the feature as a post-match pipeline layered on top of the existing battle recording artifacts. Keep battle recording responsible for capture, then add review-specific extraction, payload building, prompt generation, ZenMux requests, artifact persistence, and a minimal result-screen UI that drives the workflow asynchronously.

**Tech Stack:** GDScript, Godot `HTTPRequest`, existing `BattleRecorder` / `BattleRecordExporter` artifacts, `BattleScene` result dialog flow, focused Godot test suites

---

## File Structure

### New files

- `D:/ai/code/ptcgtrain/scripts/network/ZenMuxClient.gd`
  - Thin HTTP wrapper for ZenMux requests, auth headers, timeout handling, and normalized JSON/error parsing.
- `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewPromptBuilder.gd`
  - Owns stage 1 and stage 2 prompt payload builders plus strict JSON output contracts.
- `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewTurnExtractor.gd`
  - Reads `detail.jsonl`, groups events by turn, and returns per-turn event slices plus before/after snapshots.
- `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewHeuristics.gd`
  - Computes lightweight tags such as prize swing, gust usage, and multi-KO pressure markers.
- `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewContextBuilder.gd`
  - Builds stage 2 per-turn structured review packets from extracted events and snapshots.
- `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewDataBuilder.gd`
  - Builds stage 1 compact payloads and delegates stage 2 packet building.
- `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewArtifactStore.gd`
  - Reads/writes `review.json` and optional request/response debug artifacts under the match review directory.
- `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewService.gd`
  - Orchestrates the two-stage pipeline, caching, partial-success handling, and UI-visible status.
- `D:/ai/code/ptcgtrain/tests/test_zenmux_client.gd`
  - Focused coverage for HTTP success and failure normalization.
- `D:/ai/code/ptcgtrain/tests/test_battle_review_prompt_builder.gd`
  - Focused coverage for stage 1 and stage 2 prompt payload schemas.
- `D:/ai/code/ptcgtrain/tests/test_battle_review_turn_extractor.gd`
  - Focused coverage for turn extraction and snapshot selection.
- `D:/ai/code/ptcgtrain/tests/test_battle_review_context_builder.gd`
  - Focused coverage for stage 2 structured payload shape.
- `D:/ai/code/ptcgtrain/tests/test_battle_review_service.gd`
  - Focused coverage for two-stage orchestration, partial success, and cache writing.

### Existing files to modify

- `D:/ai/code/ptcgtrain/scripts/autoload/GameManager.gd`
  - Add minimal `battle_review_api_config` fields for first-release ZenMux endpoint/model/key configuration.
- `D:/ai/code/ptcgtrain/scripts/engine/BattleRecordExporter.gd`
- `D:/ai/code/ptcgtrain/scripts/engine/BattleRecorder.gd`
  - Add any tiny metadata improvements needed by review payloads, but avoid redesigning current artifacts.
- `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.gd`
  - Replace the current game-over two-option dialog with a result flow that supports `生成AI复盘`, in-progress states, cached review loading, and opening a review viewer.
- `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.tscn`
  - Add the minimal review viewer panel and any extra buttons/labels required by the result flow.
- `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`
  - Add integration coverage for result-screen review states and cached review viewing.
- `D:/ai/code/ptcgtrain/tests/TestRunner.gd`
  - Register new targeted suites.

### Existing artifacts to reference during implementation

- `D:/ai/code/ptcgtrain/scripts/engine/BattleRecorder.gd`
- `D:/ai/code/ptcgtrain/scripts/engine/BattleRecordExporter.gd`
- `D:/ai/code/ptcgtrain/scripts/network/DeckImporter.gd`
- `D:/ai/code/ptcgtrain/docs/superpowers/specs/2026-03-31-ai-battle-review-design.md`

---

### Task 1: Add review config and ZenMux client tests

**Files:**
- Modify: `D:/ai/code/ptcgtrain/scripts/autoload/GameManager.gd`
- Create: `D:/ai/code/ptcgtrain/tests/test_zenmux_client.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/TestRunner.gd`

- [ ] **Step 1: Write the failing ZenMux client tests**

```gdscript
func test_parse_success_response_returns_content_json() -> void:
	var client := ZenMuxClient.new()
	var response := client._parse_chat_response(200, "{\"choices\":[{\"message\":{\"content\":\"{\\\"ok\\\":true}\"}}]}")
	assert_true(response.get("ok", false))


func test_parse_http_failure_returns_error_status() -> void:
	var client := ZenMuxClient.new()
	var response := client._parse_error_response(401, HTTPRequest.RESULT_SUCCESS, "unauthorized")
	assert_eq(response.get("status", ""), "error")
	assert_eq(int(response.get("http_code", 0)), 401)
```

- [ ] **Step 2: Register the new ZenMux client suite in `TestRunner.gd`**

- [ ] **Step 3: Add minimal review config fields to `GameManager.gd`**

```gdscript
var battle_review_api_config: Dictionary = {
	"endpoint": "",
	"api_key": "",
	"model": "",
	"timeout_seconds": 30.0,
}
```

- [ ] **Step 4: Run the focused suite and verify failure**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_zenmux_client.gd
```

Expected:

- the suite loads
- tests fail because `ZenMuxClient.gd` does not exist yet

- [ ] **Step 5: Commit**

```powershell
git add scripts/autoload/GameManager.gd tests/test_zenmux_client.gd tests/TestRunner.gd
git commit -m "test: add ZenMux client coverage"
```

### Task 2: Implement ZenMux client and prompt builder

**Files:**
- Create: `D:/ai/code/ptcgtrain/scripts/network/ZenMuxClient.gd`
- Create: `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewPromptBuilder.gd`
- Create: `D:/ai/code/ptcgtrain/tests/test_battle_review_prompt_builder.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_zenmux_client.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_battle_review_prompt_builder.gd`

- [ ] **Step 1: Implement a thin `ZenMuxClient` around `HTTPRequest` following the request pattern already used in `DeckImporter.gd`**

```gdscript
func request_json(parent: Node, endpoint: String, api_key: String, payload: Dictionary, callback: Callable) -> int:
	var request := HTTPRequest.new()
	request.timeout = _timeout_seconds
	parent.add_child(request)
	request.request_completed.connect(_on_request_completed.bind(request, callback), CONNECT_ONE_SHOT)
	return request.request(
		endpoint,
		PackedStringArray([
			"Content-Type: application/json",
			"Authorization: Bearer %s" % api_key,
		]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
```

- [ ] **Step 2: Add stable response parsing helpers for success, HTTP failure, timeout, and invalid JSON**

- [ ] **Step 3: Implement `BattleReviewPromptBuilder` with stage 1 and stage 2 prompt builders**

```gdscript
func build_stage1_payload(compact_match: Dictionary) -> Dictionary:
	return {
		"system_prompt_version": "battle_review_stage1_v1",
		"response_format": _stage1_schema(),
		"match": compact_match,
	}


func build_stage2_payload(turn_packet: Dictionary) -> Dictionary:
	return {
		"system_prompt_version": "battle_review_stage2_v1",
		"response_format": _stage2_schema(),
		"turn_packet": turn_packet,
	}
```

- [ ] **Step 4: Run the ZenMux client suite until it passes**

- [ ] **Step 4a: Add prompt-builder contract tests before finalizing the implementation**

```gdscript
func test_stage1_payload_contains_version_and_match() -> void:
	var builder := BattleReviewPromptBuilder.new()
	var payload := builder.build_stage1_payload({"winner_index": 0})
	assert_eq(String(payload.get("system_prompt_version", "")), "battle_review_stage1_v1")
	assert_true(payload.has("response_format"))


func test_stage2_payload_contains_turn_packet_and_schema() -> void:
	var builder := BattleReviewPromptBuilder.new()
	var payload := builder.build_stage2_payload({"turn_number": 8})
	assert_eq(String(payload.get("system_prompt_version", "")), "battle_review_stage2_v1")
	assert_true(payload.has("turn_packet"))
```

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_zenmux_client.gd
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_review_prompt_builder.gd
```

Expected:

- PASS for the ZenMux client suite

- [ ] **Step 5: Commit**

```powershell
git add scripts/network/ZenMuxClient.gd scripts/engine/BattleReviewPromptBuilder.gd tests/test_zenmux_client.gd tests/test_battle_review_prompt_builder.gd
git commit -m "feat: add ZenMux review client and prompt builder"
```

### Task 3: Add failing tests and fixture for turn extraction

**Files:**
- Create: `D:/ai/code/ptcgtrain/tests/fixtures/match_review_fixture/`
- Create: `D:/ai/code/ptcgtrain/tests/test_battle_review_turn_extractor.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/TestRunner.gd`

- [ ] **Step 1: Add a minimal recorded-match fixture under `tests/fixtures/match_review_fixture/`**
  - include `match.json`
  - include `turns.json`
  - include `detail.jsonl`
  - keep it small but sufficient to cover one key turn with before/after snapshots

- [ ] **Step 2: Write failing tests for extracting turn slices and snapshots from the recorded match fixture**

```gdscript
func test_extract_turn_returns_only_matching_turn_events() -> void:
	var extractor := BattleReviewTurnExtractor.new()
	var result := extractor.extract_turn("res://tests/fixtures/match_review_fixture", 5)
	assert_eq(int(result.get("turn_number", 0)), 5)
	assert_gt((result.get("events", []) as Array).size(), 0)


func test_extract_turn_includes_before_and_after_snapshots() -> void:
	var extractor := BattleReviewTurnExtractor.new()
	var result := extractor.extract_turn("res://tests/fixtures/match_review_fixture", 5)
	assert_true(result.has("before_snapshot"))
	assert_true(result.has("after_snapshot"))
```

- [ ] **Step 3: Register the new extractor suite in `TestRunner.gd`**

- [ ] **Step 4: Run the focused suite and verify failure**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_review_turn_extractor.gd
```

Expected:

- tests fail because the extractor does not exist yet

- [ ] **Step 5: Commit**

```powershell
git add tests/fixtures/match_review_fixture tests/test_battle_review_turn_extractor.gd tests/TestRunner.gd
git commit -m "test: add battle review turn extraction coverage"
```

### Task 4: Implement turn extractor and heuristics

**Files:**
- Create: `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewTurnExtractor.gd`
- Create: `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewHeuristics.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_battle_review_turn_extractor.gd`

- [ ] **Step 1: Implement `BattleReviewTurnExtractor` to load `match.json` and `detail.jsonl`, then isolate a turn**

```gdscript
func extract_turn(match_dir: String, turn_number: int) -> Dictionary:
	var events := _read_detail_events(match_dir)
	var turn_events := _filter_turn_events(events, turn_number)
	return {
		"turn_number": turn_number,
		"events": turn_events,
		"before_snapshot": _nearest_snapshot_before(events, turn_number),
		"after_snapshot": _nearest_snapshot_after(events, turn_number),
		"previous_turn_summary": _load_turn_summary(match_dir, turn_number - 1),
		"current_turn_summary": _load_turn_summary(match_dir, turn_number),
	}
```

- [ ] **Step 2: Implement lightweight `BattleReviewHeuristics` tags**

```gdscript
func build_turn_tags(turn_slice: Dictionary) -> Array[String]:
	var tags: Array[String] = []
	if _has_prize_swing(turn_slice):
		tags.append("prize_swing")
	if _has_gust_sequence(turn_slice):
		tags.append("gust_used")
	if _has_multi_ko_pressure(turn_slice):
		tags.append("multi_ko_pressure")
	return tags
```

- [ ] **Step 3: Run the extractor suite until it passes**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_review_turn_extractor.gd
```

Expected:

- PASS for the extractor suite

- [ ] **Step 4: Commit**

```powershell
git add scripts/engine/BattleReviewTurnExtractor.gd scripts/engine/BattleReviewHeuristics.gd tests/test_battle_review_turn_extractor.gd
git commit -m "feat: add battle review turn extraction"
```

### Task 5: Add failing tests for stage 2 context packets

**Files:**
- Create: `D:/ai/code/ptcgtrain/tests/test_battle_review_context_builder.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/TestRunner.gd`

- [ ] **Step 1: Write failing tests for stage 2 payload shape**

```gdscript
func test_build_turn_packet_includes_board_zones_and_choices() -> void:
	var builder := BattleReviewContextBuilder.new()
	var packet := builder.build_turn_packet(_fixture_turn_slice())
	assert_true(packet.has("board_before_turn"))
	assert_true(packet.has("zones_before_turn"))
	assert_true(packet.has("actions_and_choices"))
	assert_true(packet.has("legal_choice_contexts"))


func test_build_turn_packet_carries_selected_labels_and_action_order() -> void:
	var builder := BattleReviewContextBuilder.new()
	var packet := builder.build_turn_packet(_fixture_turn_slice())
	var actions: Array = packet.get("actions_and_choices", [])
	assert_gt(actions.size(), 0)
	assert_true(str(JSON.stringify(actions)).contains("selected_labels"))
```

- [ ] **Step 2: Register the new context-builder suite in `TestRunner.gd`**

- [ ] **Step 3: Run the focused suite and verify failure**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_review_context_builder.gd
```

Expected:

- tests fail because the context builder does not exist yet

- [ ] **Step 4: Commit**

```powershell
git add tests/test_battle_review_context_builder.gd tests/TestRunner.gd
git commit -m "test: add battle review context builder coverage"
```

### Task 6: Implement stage 1 and stage 2 data builders

**Files:**
- Create: `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewContextBuilder.gd`
- Create: `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewDataBuilder.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/engine/BattleRecordExporter.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_battle_review_context_builder.gd`

- [ ] **Step 1: Add only the smallest `BattleRecordExporter.gd` metadata enhancements needed for review**
  - Keep this to additive fields only
  - Do not redesign existing artifact shape

- [ ] **Step 2: Implement `BattleReviewContextBuilder` to build the stage 2 packet**

```gdscript
func build_turn_packet(turn_slice: Dictionary, deck_context: Dictionary) -> Dictionary:
	return {
		"turn_number": int(turn_slice.get("turn_number", 0)),
		"player_index": int(_resolve_player_index(turn_slice)),
		"player_role": str(deck_context.get("player_role", "")),
		"board_before_turn": turn_slice.get("before_snapshot", {}).get("state", {}),
		"zones_before_turn": _build_zone_snapshot(turn_slice.get("before_snapshot", {})),
		"actions_and_choices": _ordered_turn_events(turn_slice.get("events", [])),
		"legal_choice_contexts": _choice_contexts(turn_slice.get("events", [])),
		"strategic_context": _strategic_context(turn_slice),
		"deck_context": deck_context,
		"heuristic_tags": turn_slice.get("heuristic_tags", []),
	}
```

- [ ] **Step 3: Implement `BattleReviewDataBuilder` stage 1 payload builder**

```gdscript
func build_stage1_payload(match_dir: String) -> Dictionary:
	return {
		"meta": _read_match_meta(match_dir),
		"opening": _read_llm_digest_opening(match_dir),
		"inflection_points": _read_llm_digest_inflections(match_dir),
		"turn_summaries": _read_turn_summaries(match_dir),
	}
```

- [ ] **Step 4: Implement `BattleReviewDataBuilder` stage 2 payload builder using the extractor and context builder**

- [ ] **Step 5: Run the context-builder suite until it passes**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_review_context_builder.gd
```

Expected:

- PASS for the context-builder suite

- [ ] **Step 6: Commit**

```powershell
git add scripts/engine/BattleReviewContextBuilder.gd scripts/engine/BattleReviewDataBuilder.gd scripts/engine/BattleRecordExporter.gd tests/test_battle_review_context_builder.gd
git commit -m "feat: add battle review payload builders"
```

### Task 7: Add failing tests for review artifact storage and orchestration

**Files:**
- Create: `D:/ai/code/ptcgtrain/tests/test_battle_review_service.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/TestRunner.gd`

- [ ] **Step 1: Write failing tests for `review.json` persistence and two-stage flow**

```gdscript
func test_service_writes_review_json_on_full_success() -> void:
	var service := BattleReviewService.new()
	var result := service._finalize_review(_sample_stage1(), [_sample_stage2()])
	assert_eq(result.get("status", ""), "completed")


func test_service_marks_partial_success_when_one_turn_fails() -> void:
	var service := BattleReviewService.new()
	var result := service._finalize_review(_sample_stage1(), [_sample_stage2(), {"status":"error"}])
	assert_eq(result.get("status", ""), "partial_success")
```

- [ ] **Step 2: Register the new service suite in `TestRunner.gd`**

- [ ] **Step 3: Run the focused suite and verify failure**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_review_service.gd
```

Expected:

- tests fail because the review service and store do not exist yet

- [ ] **Step 4: Commit**

```powershell
git add tests/test_battle_review_service.gd tests/TestRunner.gd
git commit -m "test: add battle review service coverage"
```

### Task 8: Implement review artifact store and service

**Files:**
- Create: `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewArtifactStore.gd`
- Create: `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewService.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_battle_review_service.gd`

- [ ] **Step 1: Implement `BattleReviewArtifactStore`**

```gdscript
func write_review(match_dir: String, review: Dictionary) -> bool:
	return _write_json(_review_dir(match_dir).path_join("review.json"), review)


func read_review(match_dir: String) -> Dictionary:
	return _read_json_or_empty(_review_dir(match_dir).path_join("review.json"))
```

- [ ] **Step 2: Add optional debug artifact writes**

```gdscript
func write_stage_debug(match_dir: String, filename: String, payload: Dictionary) -> bool:
	return _write_json(_review_dir(match_dir).path_join(filename), payload)
```

- [ ] **Step 3: Implement `BattleReviewService` async status flow**

```gdscript
enum Status {
	IDLE,
	SELECTING_TURNS,
	ANALYZING_TURN,
	WRITING_REVIEW,
	COMPLETED,
	FAILED,
}
```

- [ ] **Step 4: Implement stage 1 -> stage 2 orchestration using dependency injection for the client and data builder**

- [ ] **Step 5: Implement full-success, partial-success, and failure review assembly**

- [ ] **Step 6: Run the service suite until it passes**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_review_service.gd
```

Expected:

- PASS for the review service suite

- [ ] **Step 7: Commit**

```powershell
git add scripts/engine/BattleReviewArtifactStore.gd scripts/engine/BattleReviewService.gd tests/test_battle_review_service.gd
git commit -m "feat: add battle review service and artifact store"
```

### Task 9: Add failing UI tests for post-match review flow

**Files:**
- Modify: `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`

- [ ] **Step 1: Write failing UI integration tests for the result flow**

```gdscript
func test_game_over_dialog_offers_generate_ai_review_action() -> void:
	var scene := _build_battle_scene_fixture()
	scene._on_game_over(0, "拿完奖赏卡")
	assert_true(scene._dialog_list.item_count >= 3)


func test_cached_review_switches_result_action_to_view_review() -> void:
	var scene := _build_battle_scene_fixture_with_cached_review()
	scene._on_game_over(0, "拿完奖赏卡")
	assert_true(_dialog_contains(scene, "查看AI复盘"))
```

- [ ] **Step 2: Run the focused UI suite and verify failure**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_ui_features.gd
```

Expected:

- new tests fail because the result flow does not yet expose review actions

- [ ] **Step 3: Commit**

```powershell
git add tests/test_battle_ui_features.gd
git commit -m "test: add battle review UI flow coverage"
```

### Task 10: Implement result-screen generation and review viewer UI

**Files:**
- Modify: `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.gd`
- Modify: `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.tscn`
- Modify: `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`

- [ ] **Step 1: Add review service ownership and match-directory tracking to `BattleScene.gd`**
  - Add a tiny `BattleRecorder` accessor or finalize return value so `BattleScene` can capture the finished match directory from the recorder
  - Reuse it for cache lookup and review generation

- [ ] **Step 2: Replace the current two-option `_on_game_over()` dialog flow with a review-aware result flow**

```gdscript
func _show_match_end_dialog(winner_index: int, reason: String) -> void:
	var options := [_match_end_summary_text(winner_index, reason), "生成AI复盘", "返回对战准备"]
	if _has_cached_review():
		options[1] = "查看AI复盘"
	_show_dialog("游戏结束", options, {"winner": winner_index, "action": "game_over"})
```

- [ ] **Step 3: Add loading state labels for stage 1 and stage 2 progress**

- [ ] **Step 4: Add a minimal review viewer panel in `BattleScene.tscn`**
  - title
  - scrollable review content
  - close button
  - optional `重新生成` button

- [ ] **Step 5: Add handlers for**
  - `生成AI复盘`
  - `查看AI复盘`
  - `重新生成`
  - generation failure message

- [ ] **Step 6: Run the focused UI suite until it passes**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_ui_features.gd
```

Expected:

- PASS for the updated battle UI suite

- [ ] **Step 7: Commit**

```powershell
git add scenes/battle/BattleScene.gd scenes/battle/BattleScene.tscn tests/test_battle_ui_features.gd
git commit -m "feat: add in-game AI battle review flow"
```

### Task 11: Run cross-suite verification and document any fixture needs

**Files:**
- Modify: `D:/ai/code/ptcgtrain/tests/TestRunner.gd` if any suite registration remains
- Optional fixture additions under `D:/ai/code/ptcgtrain/tests/fixtures/` if needed

- [ ] **Step 1: Run all new focused suites back-to-back**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_zenmux_client.gd
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_review_turn_extractor.gd
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_review_context_builder.gd
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_review_service.gd
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_ui_features.gd
```

Expected:

- PASS for all review-related suites

- [ ] **Step 2: Run a broader regression pass if the repo is otherwise green enough**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain res://tests/TestRunner.tscn
```

Expected:

- no new failures introduced by the review feature

- [ ] **Step 3: Commit any final fixture or runner updates**

```powershell
git add tests/TestRunner.gd tests/fixtures
git commit -m "test: verify AI battle review feature"
```

## Notes for the Implementer

- Keep first-release scope tight. Do not add settings UI, provider switching, replay playback, or live coaching.
- Favor dependency injection in `BattleReviewService` so stage 1 and stage 2 logic can be tested without real network calls.
- Keep `BattleScene` thin. Move payload construction and file I/O into dedicated review scripts.
- If you need extra metadata from battle artifacts, prefer additive changes in `BattleRecordExporter.gd` over redesigning the log format.
- Keep `review.json` stable and machine-readable. The UI should consume this file rather than reconstructing the review from scratch.
