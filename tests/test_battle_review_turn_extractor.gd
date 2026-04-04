class_name TestBattleReviewTurnExtractor
extends TestBase

const FixturePath := "res://tests/fixtures/match_review_fixture"
const ExtractorPath := "res://scripts/engine/BattleReviewTurnExtractor.gd"


func _load_extractor_script() -> Variant:
	if not ResourceLoader.exists(ExtractorPath):
		return null
	return load(ExtractorPath)


func _new_extractor() -> Variant:
	var script: Variant = _load_extractor_script()
	if script == null:
		return {"ok": false, "error": "BattleReviewTurnExtractor script is missing"}

	var extractor = (script as GDScript).new()
	if extractor == null:
		return {"ok": false, "error": "BattleReviewTurnExtractor could not be instantiated"}

	return {"ok": true, "value": extractor}


func test_extract_turn_returns_only_matching_turn_events() -> String:
	var extractor_result: Variant = _new_extractor()
	if extractor_result is Dictionary and not bool((extractor_result as Dictionary).get("ok", false)):
		return str((extractor_result as Dictionary).get("error", "BattleReviewTurnExtractor setup failed"))

	var extractor: Object = (extractor_result as Dictionary).get("value") as Object
	if not extractor.has_method("extract_turn"):
		return "BattleReviewTurnExtractor is missing extract_turn"

	var result: Variant = extractor.call("extract_turn", FixturePath, 5)
	if not result is Dictionary:
		return "extract_turn should return a Dictionary"

	var events: Array = (result as Dictionary).get("events", [])
	for event_variant: Variant in events:
		if not event_variant is Dictionary:
			return "extract_turn should only return event dictionaries"

	return run_checks([
		assert_eq(int((result as Dictionary).get("turn_number", 0)), 5, "extract_turn should preserve the requested turn number"),
		assert_gt(events.size(), 0, "extract_turn should return events for the requested turn"),
		assert_true(events.all(func(event: Variant) -> bool: return int((event as Dictionary).get("turn_number", 0)) == 5), "extract_turn should only include events from the requested turn"),
	])


func test_extract_turn_includes_before_and_after_snapshots() -> String:
	var extractor_result: Variant = _new_extractor()
	if extractor_result is Dictionary and not bool((extractor_result as Dictionary).get("ok", false)):
		return str((extractor_result as Dictionary).get("error", "BattleReviewTurnExtractor setup failed"))

	var extractor: Object = (extractor_result as Dictionary).get("value") as Object
	if not extractor.has_method("extract_turn"):
		return "BattleReviewTurnExtractor is missing extract_turn"

	var result: Variant = extractor.call("extract_turn", FixturePath, 5)
	if not result is Dictionary:
		return "extract_turn should return a Dictionary"

	var before_snapshot: Dictionary = (result as Dictionary).get("before_snapshot", {})
	var after_snapshot: Dictionary = (result as Dictionary).get("after_snapshot", {})
	return run_checks([
		assert_true((result as Dictionary).has("before_snapshot"), "extract_turn should include a before_snapshot"),
		assert_true((result as Dictionary).has("after_snapshot"), "extract_turn should include an after_snapshot"),
		assert_eq(String(before_snapshot.get("snapshot_reason", "")), "turn_start", "before_snapshot should come from the latest prior snapshot"),
		assert_eq(String(after_snapshot.get("snapshot_reason", "")), "post_action", "after_snapshot should come from the turn-ending snapshot"),
		assert_eq(int(((result as Dictionary).get("previous_turn_summary", {}) as Dictionary).get("turn_number", 0)), 4, "extract_turn should expose the previous turn summary"),
		assert_eq(int(((result as Dictionary).get("current_turn_summary", {}) as Dictionary).get("turn_number", 0)), 5, "extract_turn should expose the current turn summary"),
	])
