## 批量对战：所有卡组 vs 密勒顿 各10局
## 用法：godot --headless --path . --quit-after 9999 res://scripts/training/batch_vs_miraidon.tscn
extends Control

const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")

const ANCHOR_DECK_ID := 575720  # 密勒顿
const GAMES_PER_MATCHUP := 10
const CHALLENGER_DECK_IDS: Array[int] = [
	561444, 569061, 575479, 575620, 575653,
	575657, 575716, 575718, 575723, 579502,
	579577, 580445, 581056, 581614, 582754,
]

var _registry := DeckStrategyRegistryScript.new()


func _ready() -> void:
	var anchor_deck: DeckData = CardDatabase.get_deck(ANCHOR_DECK_ID)
	if anchor_deck == null:
		print("[错误] 无法加载密勒顿卡组 %d" % ANCHOR_DECK_ID)
		_quit(1)
		return

	print("===== 15 套卡组 vs 密勒顿 (各 %d 局) =====" % GAMES_PER_MATCHUP)
	var all_results: Array[Dictionary] = []
	var start_time := Time.get_ticks_msec()

	for deck_id: int in CHALLENGER_DECK_IDS:
		var challenger_deck: DeckData = CardDatabase.get_deck(deck_id)
		if challenger_deck == null:
			print("  [跳过] 卡组 %d 加载失败" % deck_id)
			all_results.append({"deck_id": deck_id, "error": "load_failed"})
			continue
		var result: Dictionary = _run_matchup(anchor_deck, challenger_deck, deck_id)
		all_results.append(result)
		print("  %d %s: %dW-%dL-%dD (%.0f%%) avg_turns=%.0f" % [
			deck_id, str(result.get("strategy_id", "?")),
			int(result.get("wins", 0)), int(result.get("losses", 0)), int(result.get("draws", 0)),
			float(result.get("win_rate", 0)) * 100.0,
			float(result.get("avg_turns", 0)),
		])

	var elapsed: float = float(Time.get_ticks_msec() - start_time) / 1000.0
	print("\n===== 完成 (%.1f秒) =====" % elapsed)

	# 按胜率排序输出
	all_results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("win_rate", 0)) > float(b.get("win_rate", 0))
	)
	print("\n--- 胜率排名（挑战者 vs 密勒顿）---")
	for r: Dictionary in all_results:
		if r.has("error"):
			print("  %d: 错误 - %s" % [int(r.get("deck_id", 0)), str(r.get("error", ""))])
			continue
		print("  %3.0f%%: %d %s (%dW-%dL-%dD)" % [
			float(r.get("win_rate", 0)) * 100.0,
			int(r.get("deck_id", 0)),
			str(r.get("strategy_id", "?")),
			int(r.get("wins", 0)), int(r.get("losses", 0)), int(r.get("draws", 0)),
		])

	_export_results(all_results)
	_quit(0)


func _run_matchup(anchor_deck: DeckData, challenger_deck: DeckData, challenger_id: int) -> Dictionary:
	var runner := AIBenchmarkRunnerScript.new()
	var wins: int = 0
	var losses: int = 0
	var draws: int = 0
	var total_turns: int = 0
	var failure_reasons: Dictionary = {}

	for i: int in GAMES_PER_MATCHUP:
		var seed_val: int = challenger_id + i * 1000
		var challenger_player: int = i % 2  # 交替先后手
		var gsm := GameStateMachine.new()
		if gsm.coin_flipper != null:
			var rng: Variant = gsm.coin_flipper.get("_rng")
			if rng is RandomNumberGenerator:
				(rng as RandomNumberGenerator).seed = seed_val
		var ps := PlayerState.new()
		if ps.has_method("set_forced_shuffle_seed"):
			ps.call("set_forced_shuffle_seed", seed_val)

		var p0_deck: DeckData = challenger_deck if challenger_player == 0 else anchor_deck
		var p1_deck: DeckData = anchor_deck if challenger_player == 0 else challenger_deck
		gsm.start_game(p0_deck, p1_deck, 0)

		var p0_ai := _make_ai(0, gsm, challenger_player == 0)
		var p1_ai := _make_ai(1, gsm, challenger_player == 1)

		var result: Dictionary = runner.run_headless_duel(p0_ai, p1_ai, gsm, 200)

		if ps.has_method("clear_forced_shuffle_seed"):
			ps.call("clear_forced_shuffle_seed")

		var winner: int = int(result.get("winner_index", -1))
		var turns: int = int(result.get("turn_count", 0))
		total_turns += turns

		if winner == challenger_player:
			wins += 1
		elif winner >= 0:
			losses += 1
		else:
			draws += 1

		var fr: String = str(result.get("failure_reason", ""))
		if fr != "":
			failure_reasons[fr] = int(failure_reasons.get(fr, 0)) + 1

	# 检测策略名（从 deck 的卡名推断）
	var strategy_id: String = _detect_strategy_from_deck(challenger_deck)

	return {
		"deck_id": challenger_id,
		"strategy_id": strategy_id,
		"wins": wins,
		"losses": losses,
		"draws": draws,
		"win_rate": float(wins) / float(GAMES_PER_MATCHUP),
		"avg_turns": float(total_turns) / float(GAMES_PER_MATCHUP),
		"failure_reasons": failure_reasons,
	}


func _make_ai(player_index: int, gsm: GameStateMachine, is_challenger: bool) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(player_index, 1)
	# 让 registry 自动检测策略
	var player: PlayerState = gsm.game_state.players[player_index] if gsm.game_state != null else null
	if player != null:
		var strategy: RefCounted = _registry.create_strategy_for_player(player)
		if strategy != null:
			ai.set_deck_strategy(strategy)
	return ai


func _detect_strategy_from_deck(deck: DeckData) -> String:
	if deck == null:
		return ""
	return _registry.resolve_strategy_id_for_deck(deck)


func _export_results(results: Array[Dictionary]) -> void:
	var path := "user://batch_vs_miraidon_after_name_fix.json"
	var data := {
		"anchor_deck_id": ANCHOR_DECK_ID,
		"games_per_matchup": GAMES_PER_MATCHUP,
		"timestamp": Time.get_datetime_string_from_system(),
		"results": results,
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("\n结果导出: %s" % path)


func _quit(code: int) -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(code)
