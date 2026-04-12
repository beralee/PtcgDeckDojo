## 密勒顿 vs 沙奈朵快速对战测试（100 局）
## 用法：godot --headless --path . res://scripts/training/quick_matchup_test.tscn
extends Control

const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DeckStrategyMiraidonScript = preload("res://scripts/ai/DeckStrategyMiraidon.gd")
const DeckStrategyGardevoirScript = preload("res://scripts/ai/DeckStrategyGardevoir.gd")

const MIRAIDON_DECK_ID := 575720
const GARDEVOIR_DECK_ID := 578647
const TOTAL_GAMES := 100

var _results: Array[Dictionary] = []
var _miraidon_wins: int = 0
var _gardevoir_wins: int = 0
var _draws: int = 0
var _miraidon_fast_wins: int = 0  # <= 8 回合赢
var _gardevoir_fast_wins: int = 0
var _miraidon_ko_engine_wins: int = 0  # 对手没建立引擎就赢了
var _gardevoir_late_comeback: int = 0  # 10 回合后赢

func _ready() -> void:
	print("===== 密勒顿 v1.3 vs 沙奈朵 v8 Value Net =====")
	print("对局数: %d" % TOTAL_GAMES)
	print("")

	var deck_m: DeckData = CardDatabase.get_deck(MIRAIDON_DECK_ID)
	var deck_g: DeckData = CardDatabase.get_deck(GARDEVOIR_DECK_ID)
	if deck_m == null or deck_g == null:
		print("[错误] 无法加载卡组: miraidon=%s gardevoir=%s" % [str(deck_m != null), str(deck_g != null)])
		get_tree().quit(1)
		return

	var runner := AIBenchmarkRunnerScript.new()
	var start_time := Time.get_ticks_msec()

	for i: int in TOTAL_GAMES:
		var seed_val: int = i + 5000
		# 交替先后手
		var miraidon_player: int = i % 2
		var gsm := GameStateMachine.new()
		# 设置种子
		if gsm.coin_flipper != null:
			var rng: Variant = gsm.coin_flipper.get("_rng")
			if rng is RandomNumberGenerator:
				(rng as RandomNumberGenerator).seed = seed_val
		var ps := PlayerState.new()
		if ps.has_method("set_forced_shuffle_seed"):
			ps.call("set_forced_shuffle_seed", seed_val)

		var p0_deck: DeckData = deck_m if miraidon_player == 0 else deck_g
		var p1_deck: DeckData = deck_g if miraidon_player == 0 else deck_m
		gsm.start_game(p0_deck, p1_deck, 0)

		var p0_ai := _make_ai_for_deck(0, p0_deck)
		var p1_ai := _make_ai_for_deck(1, p1_deck)

		var result: Dictionary = runner.run_headless_duel(p0_ai, p1_ai, gsm, 200)

		if ps.has_method("clear_forced_shuffle_seed"):
			ps.call("clear_forced_shuffle_seed")

		var winner_index: int = int(result.get("winner_index", -1))
		var turn_count: int = int(result.get("turn_count", 0))
		var miraidon_won: bool = winner_index == miraidon_player
		var gardevoir_won: bool = winner_index == (1 - miraidon_player)

		var failure_reason: String = str(result.get("failure_reason", ""))
		if failure_reason == "unsupported_interaction_step" or failure_reason == "unsupported_prompt":
			# 诊断：记录当前场面信息
			var diag: String = ""
			if gsm.game_state != null:
				var cp: int = gsm.game_state.current_player_index
				var p: PlayerState = gsm.game_state.players[cp] if cp >= 0 and cp < gsm.game_state.players.size() else null
				if p != null and p.active_pokemon != null:
					diag = "cp=%d active=%s hand=%d" % [cp, p.active_pokemon.get_pokemon_name(), p.hand.size()]
					# 找 pending 的效果卡
					var bridge_pending: String = ""
					for c: CardInstance in p.hand:
						if c != null and c.card_data != null and c.card_data.card_type == "Supporter":
							bridge_pending += str(c.card_data.name) + ","
					diag += " supporters=[%s]" % bridge_pending
			print("  [FAIL] #%d seed=%d t=%d fr=%s %s" % [i + 1, seed_val, turn_count, failure_reason, diag])
		var entry := {
			"game": i + 1,
			"seed": seed_val,
			"miraidon_player": miraidon_player,
			"winner": "miraidon" if miraidon_won else ("gardevoir" if gardevoir_won else "draw"),
			"turns": turn_count,
			"steps": int(result.get("steps", 0)),
			"stalled": bool(result.get("stalled", false)),
			"terminated_by_cap": bool(result.get("terminated_by_cap", false)),
			"failure_reason": failure_reason,
		}
		_results.append(entry)

		if miraidon_won:
			_miraidon_wins += 1
			if turn_count <= 8:
				_miraidon_fast_wins += 1
		elif gardevoir_won:
			_gardevoir_wins += 1
			if turn_count <= 8:
				_gardevoir_fast_wins += 1
			if turn_count >= 10:
				_gardevoir_late_comeback += 1
		else:
			_draws += 1

		if (i + 1) % 10 == 0:
			print("  进度: %d/%d  密勒顿:%d  沙奈朵:%d  平:%d" % [
				i + 1, TOTAL_GAMES, _miraidon_wins, _gardevoir_wins, _draws])

	var elapsed: float = float(Time.get_ticks_msec() - start_time) / 1000.0
	_print_summary(elapsed)
	_print_detailed_analysis()
	_export_results()
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0)


func _make_ai_for_deck(player_index: int, deck: DeckData) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(player_index, 1)
	var registry := DeckStrategyRegistryScript.new()
	var strategy = registry.apply_strategy_for_deck(ai, deck)
	if strategy != null and strategy.has_method("get_strategy_id") and str(strategy.call("get_strategy_id")) == "gardevoir":
		var vnet_path := "user://ai_agents/gardevoir_value_net.json"
		if strategy.has_method("load_value_net") and strategy.load_value_net(vnet_path):
			ai.use_mcts = false
			var gardevoir_value_net: Variant = strategy.get("gardevoir_value_net")
			if gardevoir_value_net != null:
				ai._mcts_planner.value_net = gardevoir_value_net
			ai._mcts_planner.state_encoder_class = strategy.get_state_encoder_class()
	return ai


func _make_ai(player_index: int, is_miraidon: bool) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(player_index, 1)
	if is_miraidon:
		var strategy := DeckStrategyMiraidonScript.new()
		ai.set_deck_strategy(strategy)
	else:
		var strategy := DeckStrategyGardevoirScript.new()
		ai.set_deck_strategy(strategy)
		# 尝试加载 value net
		var vnet_path := "user://ai_agents/gardevoir_value_net.json"
		if strategy.load_value_net(vnet_path):
			ai.use_mcts = false  # greedy + value net 做评估
			ai._mcts_planner.value_net = strategy.gardevoir_value_net
			ai._mcts_planner.state_encoder_class = strategy.get_state_encoder_class()
	return ai


func _print_summary(elapsed: float) -> void:
	print("")
	print("===== 结果总结 =====")
	print("总局数: %d  耗时: %.1f秒" % [TOTAL_GAMES, elapsed])
	print("")
	print("  密勒顿胜: %d (%.1f%%)" % [_miraidon_wins, float(_miraidon_wins) / float(TOTAL_GAMES) * 100.0])
	print("  沙奈朵胜: %d (%.1f%%)" % [_gardevoir_wins, float(_gardevoir_wins) / float(TOTAL_GAMES) * 100.0])
	print("  平局/超时: %d (%.1f%%)" % [_draws, float(_draws) / float(TOTAL_GAMES) * 100.0])
	print("")


func _print_detailed_analysis() -> void:
	# 回合分布
	var m_turns: Array[int] = []
	var g_turns: Array[int] = []
	for r: Dictionary in _results:
		if str(r.get("winner", "")) == "miraidon":
			m_turns.append(int(r.get("turns", 0)))
		elif str(r.get("winner", "")) == "gardevoir":
			g_turns.append(int(r.get("turns", 0)))

	print("===== 详细分析 =====")
	print("")
	print("--- 速度分析 ---")
	print("  密勒顿速胜 (<=8回合): %d/%d (%.1f%%)" % [
		_miraidon_fast_wins, _miraidon_wins,
		float(_miraidon_fast_wins) / maxf(float(_miraidon_wins), 1.0) * 100.0])
	print("  沙奈朵速胜 (<=8回合): %d/%d (%.1f%%)" % [
		_gardevoir_fast_wins, _gardevoir_wins,
		float(_gardevoir_fast_wins) / maxf(float(_gardevoir_wins), 1.0) * 100.0])
	print("  沙奈朵后期翻盘 (>=10回合赢): %d/%d (%.1f%%)" % [
		_gardevoir_late_comeback, _gardevoir_wins,
		float(_gardevoir_late_comeback) / maxf(float(_gardevoir_wins), 1.0) * 100.0])

	if not m_turns.is_empty():
		m_turns.sort()
		var m_avg: float = 0.0
		for t: int in m_turns:
			m_avg += float(t)
		m_avg /= float(m_turns.size())
		print("  密勒顿赢时平均回合: %.1f  中位数: %d  范围: %d-%d" % [
			m_avg, m_turns[m_turns.size() / 2], m_turns[0], m_turns[-1]])

	if not g_turns.is_empty():
		g_turns.sort()
		var g_avg: float = 0.0
		for t: int in g_turns:
			g_avg += float(t)
		g_avg /= float(g_turns.size())
		print("  沙奈朵赢时平均回合: %.1f  中位数: %d  范围: %d-%d" % [
			g_avg, g_turns[g_turns.size() / 2], g_turns[0], g_turns[-1]])

	# 先后手分析
	var m_win_first: int = 0
	var m_win_second: int = 0
	var g_win_first: int = 0
	var g_win_second: int = 0
	var m_first_total: int = 0
	var m_second_total: int = 0
	for r: Dictionary in _results:
		var mp: int = int(r.get("miraidon_player", 0))
		if mp == 0:
			m_first_total += 1
		else:
			m_second_total += 1
		if str(r.get("winner", "")) == "miraidon":
			if mp == 0:
				m_win_first += 1
			else:
				m_win_second += 1
		elif str(r.get("winner", "")) == "gardevoir":
			if mp == 0:
				g_win_second += 1
			else:
				g_win_first += 1

	print("")
	print("--- 先后手分析 ---")
	print("  密勒顿先攻时胜率: %d/%d (%.1f%%)" % [
		m_win_first, m_first_total,
		float(m_win_first) / maxf(float(m_first_total), 1.0) * 100.0])
	print("  密勒顿后攻时胜率: %d/%d (%.1f%%)" % [
		m_win_second, m_second_total,
		float(m_win_second) / maxf(float(m_second_total), 1.0) * 100.0])

	# 异常对局 + failure_reason 统计
	var stalled_count: int = 0
	var cap_count: int = 0
	var short_games: int = 0
	var long_games: int = 0
	var failure_reasons: Dictionary = {}
	for r: Dictionary in _results:
		if bool(r.get("stalled", false)):
			stalled_count += 1
		if bool(r.get("terminated_by_cap", false)):
			cap_count += 1
		var turns: int = int(r.get("turns", 0))
		if turns <= 4 and turns > 0:
			short_games += 1
		if turns >= 20:
			long_games += 1
		var fr: String = str(r.get("failure_reason", ""))
		if fr != "":
			failure_reasons[fr] = int(failure_reasons.get(fr, 0)) + 1

	print("")
	print("--- 异常对局 ---")
	print("  卡死/超时: %d" % stalled_count)
	print("  步数上限终止: %d" % cap_count)
	print("  极短对局 (<=4回合): %d" % short_games)
	print("  极长对局 (>=20回合): %d" % long_games)
	if not failure_reasons.is_empty():
		print("  失败原因分布:")
		for reason: String in failure_reasons:
			print("    %s: %d" % [reason, int(failure_reasons[reason])])

	# 输出几局样本
	print("")
	print("--- 样本对局 ---")
	var sample_count: int = 0
	for r: Dictionary in _results:
		if sample_count >= 10:
			break
		var turns: int = int(r.get("turns", 0))
		var winner: String = str(r.get("winner", ""))
		# 输出有代表性的对局
		if (turns <= 5 and winner != "draw") or (turns >= 15) or bool(r.get("stalled", false)):
			print("  #%d seed=%d 密勒顿=P%d 赢家=%s 回合=%d 步=%d%s" % [
				int(r.get("game", 0)), int(r.get("seed", 0)),
				int(r.get("miraidon_player", 0)), winner, turns,
				int(r.get("steps", 0)),
				" [卡死]" if bool(r.get("stalled", false)) else ""])
			sample_count += 1
	print("")


func _export_results() -> void:
	var path := "user://matchup_miraidon_vs_gardevoir.json"
	var data := {
		"miraidon_version": DeckStrategyMiraidonScript.VERSION,
		"gardevoir_version": DeckStrategyGardevoirScript.VERSION,
		"total_games": TOTAL_GAMES,
		"miraidon_wins": _miraidon_wins,
		"gardevoir_wins": _gardevoir_wins,
		"draws": _draws,
		"miraidon_win_rate": float(_miraidon_wins) / float(TOTAL_GAMES),
		"results": _results,
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("详细结果已导出: %s" % path)
