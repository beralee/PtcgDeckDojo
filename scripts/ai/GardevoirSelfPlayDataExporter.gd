class_name GardevoirSelfPlayDataExporter
extends RefCounted

const GardevoirStateEncoderScript = preload("res://scripts/ai/GardevoirStateEncoder.gd")
const TrainingExportPathScript = preload("res://scripts/ai/TrainingExportPath.gd")

var base_dir: String = "user://training_data/gardevoir"
var deck_strategy: RefCounted = null
var winner_only: bool = false
var max_turn_for_shaping: int = 30
var speed_penalty: float = 0.3

var _records: Array[Dictionary] = []
var _winner_index: int = -1
var _total_turns: int = 0
var _meta: Dictionary = {}
var _failure_reason: String = ""
var _terminated_by_cap: bool = false
var _stalled: bool = false
var _match_quality_weight: float = 1.0


func start_game(meta: Dictionary = {}) -> void:
	_records.clear()
	_winner_index = -1
	_total_turns = 0
	_meta = meta.duplicate(true)
	_failure_reason = ""
	_terminated_by_cap = false
	_stalled = false
	_match_quality_weight = 1.0


func record_state(game_state: GameState, current_player: int) -> void:
	var features: Array[float] = GardevoirStateEncoderScript.encode(game_state, current_player)
	var teacher_score: float = 0.5
	if deck_strategy != null and deck_strategy.has_method("evaluate_board"):
		var raw: float = deck_strategy.evaluate_board(game_state, current_player)
		teacher_score = clampf((raw + 2000.0) / 6000.0, 0.0, 1.0)

	_records.append({
		"turn": game_state.turn_number if game_state != null else 0,
		"player": current_player,
		"features": features,
		"result": 0.5,
		"teacher_score": teacher_score,
	})
	if game_state != null and game_state.turn_number > _total_turns:
		_total_turns = game_state.turn_number


func end_game(result_variant: Variant) -> void:
	var winner_index: int = -1
	if result_variant is Dictionary:
		var result: Dictionary = result_variant
		winner_index = int(result.get("winner_index", -1))
		_failure_reason = str(result.get("failure_reason", ""))
		_terminated_by_cap = bool(result.get("terminated_by_cap", false))
		_stalled = bool(result.get("stalled", false))
		var turn_count: int = int(result.get("turn_count", 0))
		if turn_count > _total_turns:
			_total_turns = turn_count
	else:
		winner_index = int(result_variant)
	_failure_reason = _failure_reason.strip_edges()
	_match_quality_weight = _compute_match_quality_weight()
	_winner_index = winner_index
	var shaped_reward: float = 1.0
	if winner_index >= 0 and _total_turns > 0:
		var turn_ratio: float = clampf(float(_total_turns) / float(max_turn_for_shaping), 0.0, 1.0)
		shaped_reward = clampf(1.0 - turn_ratio * speed_penalty, 0.5, 1.0)

	if winner_only:
		var winner_records: Array[Dictionary] = []
		for record: Dictionary in _records:
			if int(record.get("player", -1)) == winner_index:
				record["result"] = shaped_reward
				winner_records.append(record)
		_records = winner_records
		return

	for record: Dictionary in _records:
		var player: int = int(record.get("player", -1))
		if player == winner_index:
			record["result"] = shaped_reward
		elif winner_index >= 0:
			record["result"] = 0.0
		else:
			record["result"] = 0.5
		record["failure_reason"] = _failure_reason
		record["terminated_by_cap"] = _terminated_by_cap
		record["stalled"] = _stalled
		record["match_quality_weight"] = _match_quality_weight


func export_game() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))

	var match_id := str(_meta.get("match_id", ""))
	var path := TrainingExportPathScript.build_unique_user_json_path(base_dir, match_id, "game")
	var serializable_records: Array = []
	for record: Dictionary in _records:
		var serialized_record := record.duplicate()
		var features: Variant = serialized_record.get("features", [])
		if features is Array:
			var floats: Array = []
			for value: Variant in features:
				floats.append(float(value))
			serialized_record["features"] = floats
		serializable_records.append(serialized_record)

	var payload := {
		"version": "3.0",
		"encoder": "gardevoir",
		"feature_dim": GardevoirStateEncoderScript.FEATURE_DIM,
		"meta": _meta.duplicate(true),
		"winner_index": _winner_index,
		"total_turns": _total_turns,
		"failure_reason": _failure_reason,
		"terminated_by_cap": _terminated_by_cap,
		"stalled": _stalled,
		"match_quality_weight": _match_quality_weight,
		"records": serializable_records,
	}
	var text: String = JSON.stringify(payload)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[GardevoirSelfPlayDataExporter] 无法写入: %s" % path)
		return ""
	file.store_string(text)
	file.close()
	return path


func get_records() -> Array[Dictionary]:
	return _records


func _compute_match_quality_weight() -> float:
	if _terminated_by_cap or _stalled:
		return 0.0
	match _failure_reason:
		"", "normal_game_end":
			return 1.0
		"deck_out":
			return 0.9
		"action_cap_reached", "stalled_no_progress", "unsupported_prompt", "unsupported_interaction_step", "invalid_state_transition":
			return 0.0
	return 0.0
