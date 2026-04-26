## 通用卡组 vs 密勒顿基准测试
## 用法：
##   godot --headless --path . res://scripts/training/run_deck_benchmark.tscn -- \
##     --deck-id=578647 --games=100 --seed-base=5000 --json-output=user://benchmark_result.json
##
## 参数：
##   --deck-id=N          必填，被测卡组 ID
##   --anchor-id=N        可选，对手卡组 ID（默认密勒顿 575720）
##   --games=N            可选，对局数（默认 100）
##   --seed-base=N        可选，种子起始值（默认 5000）
##   --max-steps=N        可选，每局最大步数（默认 200）
##   --json-output=PATH   可选，结果 JSON 输出路径
##   --decision-mode=MODE 可选，rules_only / rules_plus_learned / heuristic_only
extends Control

const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")

const DEFAULT_ANCHOR_ID := 575720
const DEFAULT_GAMES := 100
const DEFAULT_SEED_BASE := 5000
const DEFAULT_MAX_STEPS := 200


func _ready() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	var deck_id: int = int(options.get("deck_id", 0))
	var anchor_id: int = int(options.get("anchor_id", DEFAULT_ANCHOR_ID))
	var games: int = int(options.get("games", DEFAULT_GAMES))
	var seed_base: int = int(options.get("seed_base", DEFAULT_SEED_BASE))
	var max_steps: int = int(options.get("max_steps", DEFAULT_MAX_STEPS))
	var json_output: String = str(options.get("json_output", ""))
	var decision_mode: String = str(options.get("decision_mode", ""))

	if deck_id <= 0:
		print("[错误] 缺少 --deck-id 参数")
		_quit(1)
		return

	var deck: DeckData = CardDatabase.get_deck(deck_id)
	var anchor_deck: DeckData = CardDatabase.get_deck(anchor_id)
	if deck == null:
		print("[错误] 无法加载卡组 %d" % deck_id)
		_quit(1)
		return
	if anchor_deck == null:
		print("[错误] 无法加载锚定卡组 %d" % anchor_id)
		_quit(1)
		return

	print("===== 卡组基准测试 =====")
	print("被测卡组: %s (%d)" % [deck.deck_name, deck_id])
	print("对手卡组: %s (%d)" % [anchor_deck.deck_name, anchor_id])
	print("对局数: %d  种子起始: %d  最大步数: %d" % [games, seed_base, max_steps])
	if decision_mode != "":
		print("决策模式: %s" % decision_mode)
	print("")

	var runner := AIBenchmarkRunnerScript.new()
	var start_time := Time.get_ticks_msec()

	var wins: int = 0
	var losses: int = 0
	var draws: int = 0
	var total_turns: int = 0
	var failure_reasons: Dictionary = {}
	var per_game: Array[Dictionary] = []
	var turn_list_wins: Array[int] = []
	var turn_list_losses: Array[int] = []

	for i: int in games:
		var seed_val: int = seed_base + i
		var tracked_player: int = i % 2
		var gsm := GameStateMachine.new()
		if gsm.coin_flipper != null:
			var rng: Variant = gsm.coin_flipper.get("_rng")
			if rng is RandomNumberGenerator:
				(rng as RandomNumberGenerator).seed = seed_val
		var ps := PlayerState.new()
		if ps.has_method("set_forced_shuffle_seed"):
			ps.call("set_forced_shuffle_seed", seed_val)

		var p0_deck: DeckData = deck if tracked_player == 0 else anchor_deck
		var p1_deck: DeckData = anchor_deck if tracked_player == 0 else deck
		gsm.start_game(p0_deck, p1_deck, 0)

		var p0_ai := _make_ai(0, p0_deck, decision_mode if tracked_player == 0 else "")
		var p1_ai := _make_ai(1, p1_deck, decision_mode if tracked_player == 1 else "")

		var result: Dictionary = runner.run_headless_duel(p0_ai, p1_ai, gsm, max_steps)

		if ps.has_method("clear_forced_shuffle_seed"):
			ps.call("clear_forced_shuffle_seed")

		var winner_index: int = int(result.get("winner_index", -1))
		var turn_count: int = int(result.get("turn_count", 0))
		total_turns += turn_count

		var outcome: String = "draw"
		if winner_index == tracked_player:
			wins += 1
			outcome = "win"
			turn_list_wins.append(turn_count)
		elif winner_index >= 0:
			losses += 1
			outcome = "loss"
			turn_list_losses.append(turn_count)
		else:
			draws += 1

		var fr: String = str(result.get("failure_reason", ""))
		if fr != "":
			failure_reasons[fr] = int(failure_reasons.get(fr, 0)) + 1

		per_game.append({
			"game": i + 1,
			"seed": seed_val,
			"tracked_player": tracked_player,
			"outcome": outcome,
			"turns": turn_count,
			"steps": int(result.get("steps", 0)),
			"failure_reason": fr,
			"stalled": bool(result.get("stalled", false)),
			"terminated_by_cap": bool(result.get("terminated_by_cap", false)),
		})

		if (i + 1) % 10 == 0:
			print("  进度: %d/%d  胜:%d  负:%d  平:%d" % [i + 1, games, wins, losses, draws])

	var elapsed: float = float(Time.get_ticks_msec() - start_time) / 1000.0
	var total: int = maxi(games, 1)
	var win_rate: float = float(wins) / float(total)
	var avg_turns: float = float(total_turns) / float(total)

	# 判定基准是否干净
	var is_clean: bool = true
	var dirty_reasons: Array[String] = []
	for dirty_key: String in ["unsupported_prompt", "unsupported_interaction_step", "action_cap_reached", "stalled_no_progress"]:
		if int(failure_reasons.get(dirty_key, 0)) > 0:
			is_clean = false
			dirty_reasons.append("%s:%d" % [dirty_key, int(failure_reasons[dirty_key])])

	print("")
	print("===== 结果 =====")
	print("胜: %d (%.1f%%)  负: %d (%.1f%%)  平: %d (%.1f%%)" % [
		wins, win_rate * 100.0,
		losses, float(losses) / float(total) * 100.0,
		draws, float(draws) / float(total) * 100.0])
	print("平均回合: %.1f  耗时: %.1f秒" % [avg_turns, elapsed])
	if not turn_list_wins.is_empty():
		turn_list_wins.sort()
		print("胜局回合: 中位数=%d 范围=%d-%d" % [
			turn_list_wins[turn_list_wins.size() / 2],
			turn_list_wins[0], turn_list_wins[-1]])
	if not turn_list_losses.is_empty():
		turn_list_losses.sort()
		print("败局回合: 中位数=%d 范围=%d-%d" % [
			turn_list_losses[turn_list_losses.size() / 2],
			turn_list_losses[0], turn_list_losses[-1]])
	if not failure_reasons.is_empty():
		print("失败原因: %s" % JSON.stringify(failure_reasons))
	print("基准干净: %s%s" % ["是" if is_clean else "否", (" (%s)" % ", ".join(dirty_reasons)) if not dirty_reasons.is_empty() else ""])

	# 导出 JSON
	var report := {
		"deck_id": deck_id,
		"deck_name": deck.deck_name,
		"anchor_id": anchor_id,
		"anchor_name": anchor_deck.deck_name,
		"games": games,
		"seed_base": seed_base,
		"decision_mode": decision_mode,
		"wins": wins,
		"losses": losses,
		"draws": draws,
		"win_rate": win_rate,
		"avg_turns": avg_turns,
		"is_clean": is_clean,
		"failure_reasons": failure_reasons,
		"elapsed_seconds": elapsed,
		"timestamp": Time.get_datetime_string_from_system(),
		"per_game": per_game,
	}

	if json_output != "":
		var file := FileAccess.open(json_output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
			print("结果导出: %s" % json_output)
		else:
			print("[警告] 无法写入 %s" % json_output)

	_quit(0)


func _make_ai(player_index: int, deck: DeckData, decision_mode_override: String = "") -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(player_index, 1)
	var registry := DeckStrategyRegistryScript.new()
	var strategy = registry.apply_strategy_for_deck(ai, deck)
	if strategy != null and strategy.has_method("get_strategy_id"):
		# 尝试加载 value net
		var strategy_id: String = str(strategy.call("get_strategy_id"))
		var vnet_path := "user://ai_agents/%s_value_net.json" % strategy_id
		if strategy.has_method("load_value_net"):
			if strategy.load_value_net(vnet_path):
				var vnet = strategy.get_value_net() if strategy.has_method("get_value_net") else null
				if vnet != null:
					ai._mcts_planner.value_net = vnet
				var encoder_class = strategy.get_state_encoder_class() if strategy.has_method("get_state_encoder_class") else null
				if encoder_class != null:
					ai._mcts_planner.state_encoder_class = encoder_class
	if decision_mode_override != "":
		ai.decision_runtime_mode = decision_mode_override
	return ai


func _parse_args(args: PackedStringArray) -> Dictionary:
	var parsed := {
		"deck_id": 0,
		"anchor_id": DEFAULT_ANCHOR_ID,
		"games": DEFAULT_GAMES,
		"seed_base": DEFAULT_SEED_BASE,
		"max_steps": DEFAULT_MAX_STEPS,
		"json_output": "",
		"decision_mode": "",
	}
	for arg: String in args:
		if arg.begins_with("--deck-id="):
			parsed["deck_id"] = int(arg.split("=")[1])
		elif arg.begins_with("--anchor-id="):
			parsed["anchor_id"] = int(arg.split("=")[1])
		elif arg.begins_with("--games="):
			parsed["games"] = max(1, int(arg.split("=")[1]))
		elif arg.begins_with("--seed-base="):
			parsed["seed_base"] = int(arg.split("=")[1])
		elif arg.begins_with("--max-steps="):
			parsed["max_steps"] = max(1, int(arg.split("=")[1]))
		elif arg.begins_with("--json-output="):
			parsed["json_output"] = arg.split("=")[1]
		elif arg.begins_with("--decision-mode="):
			parsed["decision_mode"] = arg.split("=")[1]
	return parsed


func _quit(code: int) -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(code)
