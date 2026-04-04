class_name TestBattleReviewService
extends TestBase

const ArtifactStorePath := "res://scripts/engine/BattleReviewArtifactStore.gd"
const ServicePath := "res://scripts/engine/BattleReviewService.gd"
const TEST_ROOT := "user://test_battle_review_service"


class FakeZenMuxClient:
	extends RefCounted

	var responses: Array[Dictionary] = []
	var recorded_payloads: Array[Dictionary] = []

	func request_json(_parent: Node, _endpoint: String, _api_key: String, payload: Dictionary, callback: Callable) -> int:
		recorded_payloads.append(payload.duplicate(true))
		var response: Dictionary = responses.pop_front() if not responses.is_empty() else {"status": "error", "message": "missing fake response"}
		callback.call(response)
		return OK


class FakeReviewDataBuilder:
	extends RefCounted

	var stage1_payload: Dictionary = {
		"meta": {"match_id": "fixture"},
		"turn_summaries": [
			{"turn_number": 5},
			{"turn_number": 6},
		],
	}
	var turn_packets: Dictionary = {}
	var requested_turns: Array[int] = []

	func build_stage1_payload(_match_dir: String) -> Dictionary:
		return stage1_payload.duplicate(true)

	func build_turn_packet(_match_dir: String, turn_number: int) -> Dictionary:
		requested_turns.append(turn_number)
		return (turn_packets.get(turn_number, {}) as Dictionary).duplicate(true)


func _cleanup_root() -> void:
	var root_path := ProjectSettings.globalize_path(TEST_ROOT)
	if not DirAccess.dir_exists_absolute(root_path):
		if FileAccess.file_exists(root_path):
			DirAccess.remove_absolute(root_path)
		return
	_remove_dir_recursive(root_path)
	DirAccess.remove_absolute(root_path)


func _remove_dir_recursive(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var child_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			_remove_dir_recursive(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _new_artifact_store() -> Variant:
	if not ResourceLoader.exists(ArtifactStorePath):
		return {"ok": false, "error": "BattleReviewArtifactStore script is missing"}
	var script: GDScript = load(ArtifactStorePath)
	var store = script.new()
	if store == null:
		return {"ok": false, "error": "BattleReviewArtifactStore could not be instantiated"}
	return {"ok": true, "value": store}


func _new_service(store: Object, client: RefCounted, data_builder: RefCounted) -> Variant:
	if not ResourceLoader.exists(ServicePath):
		return {"ok": false, "error": "BattleReviewService script is missing"}
	var script: GDScript = load(ServicePath)
	var service = script.new()
	if service == null:
		return {"ok": false, "error": "BattleReviewService could not be instantiated"}
	if not service.has_method("configure_dependencies"):
		return {"ok": false, "error": "BattleReviewService is missing configure_dependencies"}
	service.call("configure_dependencies", client, data_builder, store)
	return {"ok": true, "value": service}


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func test_generate_review_writes_completed_review_for_two_stage_success() -> String:
	_cleanup_root()
	var store_result: Variant = _new_artifact_store()
	if store_result is Dictionary and not bool((store_result as Dictionary).get("ok", false)):
		return str((store_result as Dictionary).get("error", "Artifact store setup failed"))

	var client := FakeZenMuxClient.new()
	client.responses = [
		{
			"winner_index": 0,
			"loser_index": 1,
			"winner_turns": [{"turn_number": 5, "reason": "winner swing"}],
			"loser_turns": [{"turn_number": 6, "reason": "loser stumble"}],
		},
		{
			"turn_number": 5,
			"player_index": 0,
			"judgment": "suboptimal",
			"why_current_line_falls_short": ["winner issue"],
			"better_line": {"goal": "win cleaner", "steps": ["step a"]},
			"why_better": ["safer"],
			"confidence": "medium",
		},
		{
			"turn_number": 6,
			"player_index": 1,
			"judgment": "suboptimal",
			"why_current_line_falls_short": ["loser issue"],
			"better_line": {"goal": "stabilize", "steps": ["step b"]},
			"why_better": ["better survival"],
			"confidence": "medium",
		},
	]

	var data_builder := FakeReviewDataBuilder.new()
	data_builder.turn_packets = {
		5: {"turn_number": 5, "player_index": 0},
		6: {"turn_number": 6, "player_index": 1},
	}

	var service_result: Variant = _new_service((store_result as Dictionary).get("value") as Object, client, data_builder)
	if service_result is Dictionary and not bool((service_result as Dictionary).get("ok", false)):
		return str((service_result as Dictionary).get("error", "BattleReviewService setup failed"))

	var service: Object = (service_result as Dictionary).get("value") as Object
	var host := Node.new()
	var result: Variant = service.call("generate_review", host, TEST_ROOT.path_join("match_a"), {
		"endpoint": "https://example.invalid",
		"api_key": "test-key",
		"model": "test-model",
	})
	host.free()
	if not result is Dictionary:
		return "generate_review should return a Dictionary"

	var review_path := ProjectSettings.globalize_path(TEST_ROOT.path_join("match_a/review/review.json"))
	var persisted := _read_json(review_path)
	var key_turns: Array = (result as Dictionary).get("selected_turns", [])
	return run_checks([
		assert_eq(String((result as Dictionary).get("status", "")), "completed", "Successful two-stage analysis should complete"),
		assert_eq(key_turns.size(), 2, "Successful review should persist both selected turns"),
		assert_eq(((result as Dictionary).get("turn_reviews", []) as Array).size(), 2, "Successful review should include both turn reviews"),
		assert_eq(client.recorded_payloads.size(), 3, "Successful review should make one stage 1 call and two stage 2 calls"),
		assert_eq(String(persisted.get("status", "")), "completed", "Successful review should be written to review.json"),
	])


func test_generate_review_marks_partial_success_when_a_turn_analysis_fails() -> String:
	_cleanup_root()
	var store_result: Variant = _new_artifact_store()
	if store_result is Dictionary and not bool((store_result as Dictionary).get("ok", false)):
		return str((store_result as Dictionary).get("error", "Artifact store setup failed"))

	var client := FakeZenMuxClient.new()
	client.responses = [
		{
			"winner_index": 0,
			"loser_index": 1,
			"winner_turns": [{"turn_number": 5, "reason": "winner swing"}],
			"loser_turns": [{"turn_number": 6, "reason": "loser stumble"}],
		},
		{
			"turn_number": 5,
			"player_index": 0,
			"judgment": "suboptimal",
			"why_current_line_falls_short": ["winner issue"],
			"better_line": {"goal": "win cleaner", "steps": ["step a"]},
			"why_better": ["safer"],
			"confidence": "medium",
		},
		{
			"status": "error",
			"message": "turn analysis failed"
		},
	]

	var data_builder := FakeReviewDataBuilder.new()
	data_builder.turn_packets = {
		5: {"turn_number": 5, "player_index": 0},
		6: {"turn_number": 6, "player_index": 1},
	}

	var service_result: Variant = _new_service((store_result as Dictionary).get("value") as Object, client, data_builder)
	if service_result is Dictionary and not bool((service_result as Dictionary).get("ok", false)):
		return str((service_result as Dictionary).get("error", "BattleReviewService setup failed"))

	var service: Object = (service_result as Dictionary).get("value") as Object
	var host := Node.new()
	var result: Variant = service.call("generate_review", host, TEST_ROOT.path_join("match_b"), {
		"endpoint": "https://example.invalid",
		"api_key": "test-key",
		"model": "test-model",
	})
	host.free()
	if not result is Dictionary:
		return "generate_review should return a Dictionary"

	return run_checks([
		assert_eq(String((result as Dictionary).get("status", "")), "partial_success", "Single stage 2 failures should degrade to partial_success"),
		assert_eq((((result as Dictionary).get("turn_reviews", []) as Array).size()), 1, "Partial success should keep successful turn reviews"),
		assert_eq((((result as Dictionary).get("errors", []) as Array).size()), 1, "Partial success should record one error"),
		assert_eq(data_builder.requested_turns, [5, 6], "Service should still request each selected turn packet"),
	])


func test_generate_review_fails_when_stage1_selects_nonexistent_turn() -> String:
	_cleanup_root()
	var store_result: Variant = _new_artifact_store()
	if store_result is Dictionary and not bool((store_result as Dictionary).get("ok", false)):
		return str((store_result as Dictionary).get("error", "Artifact store setup failed"))

	var client := FakeZenMuxClient.new()
	client.responses = [{
		"winner_index": 0,
		"loser_index": 1,
		"winner_turns": [{"turn_number": 99, "reason": "imaginary turn"}],
		"loser_turns": [],
	}]

	var data_builder := FakeReviewDataBuilder.new()
	var service_result: Variant = _new_service((store_result as Dictionary).get("value") as Object, client, data_builder)
	if service_result is Dictionary and not bool((service_result as Dictionary).get("ok", false)):
		return str((service_result as Dictionary).get("error", "BattleReviewService setup failed"))

	var service: Object = (service_result as Dictionary).get("value") as Object
	var host := Node.new()
	var result: Variant = service.call("generate_review", host, TEST_ROOT.path_join("match_invalid_turn"), {
		"endpoint": "https://example.invalid",
		"api_key": "test-key",
		"model": "test-model",
	})
	host.free()
	if not result is Dictionary:
		return "generate_review should return a Dictionary"

	return run_checks([
		assert_eq(String((result as Dictionary).get("status", "")), "failed", "Nonexistent stage 1 turns should fail the review"),
		assert_eq((((result as Dictionary).get("turn_reviews", []) as Array).size()), 0, "Invalid turn selection should not produce turn reviews"),
		assert_eq(data_builder.requested_turns, [], "Invalid turn selection should not request any turn packet"),
		assert_eq(String((((result as Dictionary).get("errors", []) as Array)[0] as Dictionary).get("stage", "")) if not ((result as Dictionary).get("errors", []) as Array).is_empty() else "", "stage1", "Invalid turn selection should be reported as a stage1 error"),
	])


func test_generate_review_clamps_stage1_to_one_turn_per_side() -> String:
	_cleanup_root()
	var store_result: Variant = _new_artifact_store()
	if store_result is Dictionary and not bool((store_result as Dictionary).get("ok", false)):
		return str((store_result as Dictionary).get("error", "Artifact store setup failed"))

	var client := FakeZenMuxClient.new()
	client.responses = [
		{
			"winner_index": 0,
			"loser_index": 1,
			"winner_turns": [
				{"turn_number": 5, "reason": "winner swing"},
				{"turn_number": 6, "reason": "winner extra"},
			],
			"loser_turns": [
				{"turn_number": 6, "reason": "loser stumble"},
				{"turn_number": 5, "reason": "loser extra"},
			],
		},
		{
			"turn_number": 5,
			"player_index": 0,
			"judgment": "close_to_optimal",
			"turn_goal": "Press the lead",
			"timing_window": {"earliest_opponent_pressure_turn": 7, "assessment": "No clean punish before turn 7."},
			"why_current_line_falls_short": ["winner issue"],
			"best_line": {"summary": "Keep the line tight", "steps": ["Attack", "Hold the gust card"]},
			"coach_takeaway": "Convert the prize map without overextending.",
			"confidence": "high",
		},
		{
			"turn_number": 6,
			"player_index": 1,
			"judgment": "suboptimal",
			"turn_goal": "Stabilize the board",
			"timing_window": {"earliest_opponent_pressure_turn": 8, "assessment": "The opponent still needs a setup turn."},
			"why_current_line_falls_short": ["loser issue"],
			"best_line": {"summary": "Rebuild one threat", "steps": ["Bench the attacker", "Keep the supporter for next turn"]},
			"coach_takeaway": "Spend resources only on the line that survives the next swing.",
			"confidence": "medium",
		},
	]

	var data_builder := FakeReviewDataBuilder.new()
	data_builder.turn_packets = {
		5: {"turn_number": 5, "player_index": 0},
		6: {"turn_number": 6, "player_index": 1},
	}

	var service_result: Variant = _new_service((store_result as Dictionary).get("value") as Object, client, data_builder)
	if service_result is Dictionary and not bool((service_result as Dictionary).get("ok", false)):
		return str((service_result as Dictionary).get("error", "BattleReviewService setup failed"))

	var service: Object = (service_result as Dictionary).get("value") as Object
	var host := Node.new()
	var result: Variant = service.call("generate_review", host, TEST_ROOT.path_join("match_clamped"), {
		"endpoint": "https://example.invalid",
		"api_key": "test-key",
		"model": "test-model",
	})
	host.free()
	if not result is Dictionary:
		return "generate_review should return a Dictionary"

	return run_checks([
		assert_eq((((result as Dictionary).get("selected_turns", []) as Array).size()), 2, "Service should keep only one selected turn per side"),
		assert_eq(data_builder.requested_turns, [5, 6], "Service should only request the first winner and loser turns"),
		assert_eq(client.recorded_payloads.size(), 3, "Clamped review should still make one stage 1 call and two stage 2 calls"),
	])
