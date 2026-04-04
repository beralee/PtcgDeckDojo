class_name TestBattleAdviceContextBuilder
extends TestBase

const ContextBuilderPath := "res://scripts/engine/BattleAdviceContextBuilder.gd"
const TEST_ROOT := "user://test_battle_advice_context_builder"


func _cleanup_root() -> void:
	var root_path := ProjectSettings.globalize_path(TEST_ROOT)
	if not DirAccess.dir_exists_absolute(root_path):
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


func _new_builder() -> Variant:
	if not ResourceLoader.exists(ContextBuilderPath):
		return {"ok": false, "error": "BattleAdviceContextBuilder script is missing"}
	var script: GDScript = load(ContextBuilderPath)
	var builder = script.new()
	if builder == null:
		return {"ok": false, "error": "BattleAdviceContextBuilder could not be instantiated"}
	return {"ok": true, "value": builder}


func _sample_match_dir() -> String:
	return TEST_ROOT.path_join("match_a")


func _sample_live_snapshot() -> Dictionary:
	return {
		"turn_number": 5,
		"current_player_index": 0,
		"players": [
			{
				"player_index": 0,
				"hand": [
					{"card_name": "Ultra Ball"},
					{"card_name": "Boss's Orders"},
				],
				"hand_count": 2,
				"discard": [{"card_name": "Rare Candy"}],
				"active": {"pokemon_name": "Pikachu ex", "damage": 30},
				"bench": [{"pokemon_name": "Mew ex"}],
				"prize_count": 4,
				"deck_count": 21,
				"deck_order": ["hidden-a", "hidden-b"],
			},
			{
				"player_index": 1,
				"hand": [
					{"card_name": "Iono"},
					{"card_name": "Nest Ball"},
				],
				"hand_count": 2,
				"discard": [{"card_name": "Ultra Ball"}],
				"active": {"pokemon_name": "Charizard ex", "damage": 0},
				"bench": [{"pokemon_name": "Pidgeot ex"}],
				"prize_count": 3,
				"deck_count": 18,
				"deck_order": ["hidden-x", "hidden-y"],
			},
		],
		"prize_identities": [["card-a"], ["card-b"]],
		"stadium": {"card_name": "Collapsed Stadium"},
	}


func _verbose_live_snapshot() -> Dictionary:
	var snapshot := _sample_live_snapshot().duplicate(true)
	var players: Array = snapshot.get("players", [])
	for player_variant: Variant in players:
		if not (player_variant is Dictionary):
			continue
		var player := player_variant as Dictionary
		player["deck"] = [
			{"card_name": "Hidden Deck Card A", "text": "x".repeat(400)},
			{"card_name": "Hidden Deck Card B", "text": "x".repeat(400)},
		]
		player["prizes"] = [
			{"card_name": "Hidden Prize Card", "text": "x".repeat(400)},
		]
		player["lost_zone"] = [
			{"card_name": "Lost Zone Card", "text": "x".repeat(400)},
		]
		player["discard_pile"] = [
			{"card_name": "Rare Candy", "text": "x".repeat(500)},
			{"card_name": "Ultra Ball", "text": "x".repeat(500)},
		]
		player["active"] = {
			"pokemon_name": "Verbose Active",
			"pokemon_stack": [{"card_name": "Verbose Active", "description": "x".repeat(800)}],
			"attached_energy": [{"card_name": "Psychic Energy", "description": "x".repeat(800)}],
			"attached_tool": {"card_name": "Bravery Charm", "description": "x".repeat(800)},
			"effects": [{"type": "test_effect", "description": "x".repeat(800)}],
			"status_conditions": {"poisoned": true},
			"remaining_hp": 180,
			"max_hp": 220,
			"damage_counters": 4,
		}
	return snapshot


func _sample_initial_snapshot() -> Dictionary:
	return {
		"players": [
			{
				"player_index": 0,
				"decklist": [
					{"card_name": "Pikachu ex", "count": 2},
					{"card_name": "Ultra Ball", "count": 4},
				],
			},
			{
				"player_index": 1,
				"decklist": [
					{"card_name": "Charizard ex", "count": 2},
					{"card_name": "Rare Candy", "count": 4},
				],
			},
		],
	}


func _write_heavy_match_artifacts(match_dir: String) -> void:
	var detail_path := match_dir.path_join("detail.jsonl")
	var summary_path := match_dir.path_join("summary.log")
	var detail_dir := ProjectSettings.globalize_path(match_dir)
	if not DirAccess.dir_exists_absolute(detail_dir):
		DirAccess.make_dir_recursive_absolute(detail_dir)

	var detail_file := FileAccess.open(detail_path, FileAccess.WRITE)
	if detail_file != null:
		for event_index: int in range(1, 181):
			detail_file.store_line(JSON.stringify({
				"event_index": event_index,
				"event_type": "state_snapshot" if event_index % 3 == 0 else ("action_resolved" if event_index % 2 == 0 else "choice_context"),
				"turn_number": 5 + int(event_index / 30),
				"title": "Verbose choice %d" % event_index,
				"description": "Very long diagnostic payload " + "x".repeat(1200),
				"items": ["Option %d" % event_index, "Option %d alt" % event_index],
				"selected_labels": ["Selected %d" % event_index],
				"snapshot_reason": "after_action_resolved",
				"state": {
					"players": [
						{
							"player_index": 0,
							"hand": [{"card_name": "Huge Card", "description": "x".repeat(1400)}],
							"deck": [{"card_name": "Hidden", "description": "x".repeat(1400)}],
						},
					],
				},
			}))
		detail_file.close()

	var summary_file := FileAccess.open(summary_path, FileAccess.WRITE)
	if summary_file != null:
		for line_index: int in range(1, 181):
			summary_file.store_line("Turn %d summary %s" % [line_index, "x".repeat(300)])
		summary_file.close()


func _write_match_artifacts(match_dir: String) -> void:
	var detail_path := match_dir.path_join("detail.jsonl")
	var summary_path := match_dir.path_join("summary.log")
	var detail_dir := ProjectSettings.globalize_path(match_dir)
	if not DirAccess.dir_exists_absolute(detail_dir):
		DirAccess.make_dir_recursive_absolute(detail_dir)

	var detail_file := FileAccess.open(detail_path, FileAccess.WRITE)
	if detail_file != null:
		detail_file.store_line(JSON.stringify({"event_index": 1, "event_type": "choice_context", "turn_number": 4}))
		detail_file.store_line(JSON.stringify({"event_index": 3, "event_type": "action_selected", "turn_number": 4}))
		detail_file.store_line(JSON.stringify({"event_index": 4, "event_type": "action_resolved", "turn_number": 5}))
		detail_file.store_line(JSON.stringify({"event_index": 5, "event_type": "state_snapshot", "turn_number": 5}))
		detail_file.close()

	var summary_file := FileAccess.open(summary_path, FileAccess.WRITE)
	if summary_file != null:
		summary_file.store_line("Turn 4: setup stabilized")
		summary_file.store_line("Turn 5: pressure turn")
		summary_file.close()


func test_build_request_context_hides_opponent_hand_and_shows_decklists() -> String:
	_cleanup_root()
	var builder_result: Variant = _new_builder()
	if builder_result is Dictionary and not bool((builder_result as Dictionary).get("ok", false)):
		return str((builder_result as Dictionary).get("error", "BattleAdviceContextBuilder setup failed"))

	var match_dir := _sample_match_dir()
	_write_match_artifacts(match_dir)
	var builder: Object = (builder_result as Dictionary).get("value") as Object
	if not builder.has_method("build_request_context"):
		return "BattleAdviceContextBuilder is missing build_request_context"

	var context: Variant = builder.call("build_request_context", _sample_live_snapshot(), _sample_initial_snapshot(), match_dir, 0, {"session_id": "match_1", "request_index": 1})
	if not context is Dictionary:
		return "build_request_context should return a Dictionary"

	var current_position: Dictionary = (context as Dictionary).get("current_position", {})
	var players: Array = current_position.get("players", [])
	var opponent := players[1] as Dictionary if players.size() > 1 else {}
	var visibility_rules := (context as Dictionary).get("visibility_rules", {}) as Dictionary
	return run_checks([
		assert_false(opponent.has("hand"), "Opponent hand contents should not be present"),
		assert_true(current_position.has("decklists"), "Both decklists should be included"),
		assert_true(visibility_rules.has("known") and visibility_rules.has("unknown"), "Context should include explicit visibility rules"),
		assert_false(current_position.has("prize_identities"), "Prize identities should not be exposed"),
		assert_false(current_position.has("deck_order"), "Deck order should not be exposed"),
	])


func test_build_request_context_only_includes_unsynced_detail_events() -> String:
	_cleanup_root()
	var builder_result: Variant = _new_builder()
	if builder_result is Dictionary and not bool((builder_result as Dictionary).get("ok", false)):
		return str((builder_result as Dictionary).get("error", "BattleAdviceContextBuilder setup failed"))

	var match_dir := _sample_match_dir()
	_write_match_artifacts(match_dir)
	var builder: Object = (builder_result as Dictionary).get("value") as Object
	var context: Variant = builder.call("build_request_context", _sample_live_snapshot(), _sample_initial_snapshot(), match_dir, 0, {
		"session_id": "match_1",
		"request_index": 2,
		"last_synced_event_index": 3,
	})
	if not context is Dictionary:
		return "build_request_context should return a Dictionary"

	var delta := (context as Dictionary).get("delta_since_last_advice", {}) as Dictionary
	var detail_events: Array = delta.get("detail_events", [])
	return run_checks([
		assert_eq(int(((detail_events[0] as Dictionary).get("event_index", -1)) if not detail_events.is_empty() else -1), 4, "Delta should start at the first unsynced event"),
		assert_eq(detail_events.size(), 2, "Delta should only include events after the synced cursor"),
	])


func test_build_request_context_drops_hidden_live_zones_from_current_position() -> String:
	_cleanup_root()
	var builder_result: Variant = _new_builder()
	if builder_result is Dictionary and not bool((builder_result as Dictionary).get("ok", false)):
		return str((builder_result as Dictionary).get("error", "BattleAdviceContextBuilder setup failed"))

	var match_dir := _sample_match_dir()
	_write_match_artifacts(match_dir)
	var builder: Object = (builder_result as Dictionary).get("value") as Object
	var context: Variant = builder.call("build_request_context", _verbose_live_snapshot(), _sample_initial_snapshot(), match_dir, 0, {
		"session_id": "match_1",
		"request_index": 1,
	})
	if not context is Dictionary:
		return "build_request_context should return a Dictionary"

	var current_position: Dictionary = (context as Dictionary).get("current_position", {})
	var players: Array = current_position.get("players", [])
	var self_player := players[0] as Dictionary if not players.is_empty() else {}
	var opponent := players[1] as Dictionary if players.size() > 1 else {}
	return run_checks([
		assert_false(self_player.has("deck"), "Current position should not expose live deck contents"),
		assert_false(self_player.has("prizes"), "Current position should not expose live prize identities"),
		assert_false(opponent.has("deck"), "Opponent live deck contents should not be exposed"),
		assert_false(opponent.has("prizes"), "Opponent live prize identities should not be exposed"),
		assert_true(current_position.has("decklists"), "Current position should keep public decklists"),
	])


func test_build_request_context_compacts_heavy_logs_for_request_size() -> String:
	_cleanup_root()
	var builder_result: Variant = _new_builder()
	if builder_result is Dictionary and not bool((builder_result as Dictionary).get("ok", false)):
		return str((builder_result as Dictionary).get("error", "BattleAdviceContextBuilder setup failed"))

	var match_dir := TEST_ROOT.path_join("match_heavy")
	_write_heavy_match_artifacts(match_dir)
	var builder: Object = (builder_result as Dictionary).get("value") as Object
	var context: Variant = builder.call("build_request_context", _verbose_live_snapshot(), _sample_initial_snapshot(), match_dir, 0, {
		"session_id": "match_heavy",
		"request_index": 2,
		"last_synced_event_index": 0,
	})
	if not context is Dictionary:
		return "build_request_context should return a Dictionary"

	var delta := (context as Dictionary).get("delta_since_last_advice", {}) as Dictionary
	var detail_events: Array = delta.get("detail_events", [])
	var summary_lines: Array = delta.get("summary_lines", [])
	var serialized := JSON.stringify(context)
	return run_checks([
		assert_true(serialized.length() < 120000, "Advice request context should stay compact even with heavy logs"),
		assert_true(detail_events.size() <= 80, "Advice delta should cap the number of detailed events"),
		assert_true(summary_lines.size() <= 40, "Advice delta should cap summary lines"),
		assert_false(serialized.contains("Very long diagnostic payload"), "Advice context should drop oversized raw event descriptions"),
		assert_false(serialized.contains("\"state\""), "Advice delta should not embed full state snapshots"),
	])
