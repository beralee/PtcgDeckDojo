class_name DragapultDusknoirSelfPlayDataExporter
extends RefCounted

## 多龙巴鲁托/夜巡灵卡组自博弈数据收集器。
## 使用 DragapultDusknoirStateEncoder 编码特征，额外记录 teacher_score（手写 evaluate_board 归一化值）。
##
## 训练策略：
## - 只保留赢家视角的记录（输家数据丢弃）
## - 奖励塑形：赢得越快 reward 越高（快赢 > 慢赢 > 平局）
## - winner_only=false 时回退到旧行为（保留双方数据）

const DragapultDusknoirStateEncoderScript = preload("res://scripts/ai/DragapultDusknoirStateEncoder.gd")
const TrainingExportPathScript = preload("res://scripts/ai/TrainingExportPath.gd")

var base_dir: String = "user://training_data/dragapult_dusknoir"

## 可选：传入策略实例用于计算 teacher_score
var deck_strategy: RefCounted = null

## 只保留赢家数据 + 奖励塑形
var winner_only: bool = true

## 奖励塑形参数：reward = 1.0 - (turn / max_turn_for_shaping) * speed_penalty
var max_turn_for_shaping: int = 30
var speed_penalty: float = 0.3

var _records: Array[Dictionary] = []
var _winner_index: int = -1
var _total_turns: int = 0
var _meta: Dictionary = {}


func start_game(meta: Dictionary = {}) -> void:
	_records.clear()
	_winner_index = -1
	_total_turns = 0
	_meta = meta.duplicate(true)


func record_state(game_state: GameState, current_player: int) -> void:
	var features: Array[float] = DragapultDusknoirStateEncoderScript.encode(game_state, current_player)

	var teacher_score: float = 0.5
	if deck_strategy != null and deck_strategy.has_method("evaluate_board"):
		var raw: float = deck_strategy.evaluate_board(game_state, current_player)
		# 归一化到 [0, 1]：evaluate_board 输出范围约 [-2000, 4000]
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


func end_game(winner_index: int) -> void:
	_winner_index = winner_index

	# 奖励塑形：赢得越快分越高
	var shaped_reward: float = 1.0
	if winner_index >= 0 and _total_turns > 0:
		var turn_ratio: float = clampf(float(_total_turns) / float(max_turn_for_shaping), 0.0, 1.0)
		shaped_reward = clampf(1.0 - turn_ratio * speed_penalty, 0.5, 1.0)

	if winner_only:
		# 只保留赢家的记录，丢弃输家和平局数据
		var winner_records: Array[Dictionary] = []
		for record: Dictionary in _records:
			var player: int = int(record.get("player", -1))
			if player == winner_index:
				record["result"] = shaped_reward
				winner_records.append(record)
		_records = winner_records
	else:
		# 旧行为：保留双方数据
		for record: Dictionary in _records:
			var player: int = int(record.get("player", -1))
			if player == winner_index:
				record["result"] = shaped_reward
			elif winner_index >= 0:
				record["result"] = 0.0
			else:
				record["result"] = 0.5


func export_game() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))

	var match_id := str(_meta.get("match_id", ""))
	var path := TrainingExportPathScript.build_unique_user_json_path(base_dir, match_id, "game")

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
		"version": "3.0",
		"encoder": "dragapult_dusknoir",
		"feature_dim": DragapultDusknoirStateEncoderScript.FEATURE_DIM,
		"winner_index": _winner_index,
		"total_turns": _total_turns,
		"records": serializable_records,
	}

	var text: String = JSON.stringify(data)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[DragapultDusknoirSelfPlayDataExporter] 无法写入: %s" % path)
		return ""
	file.store_string(text)
	file.close()
	return path


func get_records() -> Array[Dictionary]:
	return _records
