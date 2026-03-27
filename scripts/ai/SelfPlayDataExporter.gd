class_name SelfPlayDataExporter
extends RefCounted

## 自博弈数据收集器。
## 每回合记录局面特征，对局结束后用胜负结果回填，导出 JSON。

const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")

var base_dir: String = "user://training_data"

var _records: Array[Dictionary] = []
var _winner_index: int = -1
var _total_turns: int = 0


func start_game() -> void:
	_records.clear()
	_winner_index = -1
	_total_turns = 0


func record_state(game_state: GameState, current_player: int) -> void:
	var features: Array[float] = StateEncoderScript.encode(game_state, current_player)
	_records.append({
		"turn": game_state.turn_number if game_state != null else 0,
		"player": current_player,
		"features": features,
		"result": 0.5,
	})
	if game_state != null and game_state.turn_number > _total_turns:
		_total_turns = game_state.turn_number


func end_game(winner_index: int) -> void:
	_winner_index = winner_index
	## 回填结果
	for record: Dictionary in _records:
		var player: int = int(record.get("player", -1))
		if player == winner_index:
			record["result"] = 1.0
		elif winner_index >= 0:
			record["result"] = 0.0
		else:
			record["result"] = 0.5


func export_game() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))

	var timestamp: int = Time.get_unix_time_from_system() as int
	var seed_val: int = randi()
	var filename := "game_%d_%d.json" % [timestamp, seed_val]
	var path := base_dir.path_join(filename)

	## 将 features 数组转为普通 Array 以便 JSON 序列化
	var serializable_records: Array = []
	for record: Dictionary in _records:
		var r := record.duplicate()
		var feats: Variant = r.get("features", [])
		if feats is Array:
			var plain: Array = []
			for f: Variant in feats:
				plain.append(float(f))
			r["features"] = plain
		serializable_records.append(r)

	var data := {
		"version": "1.0",
		"winner_index": _winner_index,
		"total_turns": _total_turns,
		"records": serializable_records,
	}

	var text: String = JSON.stringify(data)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[SelfPlayDataExporter] 无法写入: %s" % path)
		return ""
	file.store_string(text)
	file.close()
	return path
