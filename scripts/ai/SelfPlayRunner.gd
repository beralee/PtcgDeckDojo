class_name SelfPlayRunner
extends RefCounted

## 批量自博弈执行器。
## 接收两个 agent config，在多组卡组对上跑 N 局 headless 对战，输出结构化结果。

const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const AIHeuristicsScript = preload("res://scripts/ai/AIHeuristics.gd")
const AIDecisionSampleExporterScript = preload("res://scripts/ai/AIDecisionSampleExporter.gd")
const SelfPlayDataExporterScript = preload("res://scripts/ai/SelfPlayDataExporter.gd")
const GardevoirSelfPlayDataExporterScript = preload("res://scripts/ai/GardevoirSelfPlayDataExporter.gd")
const MiraidonSelfPlayDataExporterScript = preload("res://scripts/ai/MiraidonSelfPlayDataExporter.gd")
const ArceusGiratinaSelfPlayDataExporterScript = preload("res://scripts/ai/ArceusGiratinaSelfPlayDataExporter.gd")
const DragapultDusknoirSelfPlayDataExporterScript = preload("res://scripts/ai/DragapultDusknoirSelfPlayDataExporter.gd")
const DragapultCharizardSelfPlayDataExporterScript = preload("res://scripts/ai/DragapultCharizardSelfPlayDataExporter.gd")
const DeckStrategyGardevoirScript = preload("res://scripts/ai/DeckStrategyGardevoir.gd")
const DeckStrategyMiraidonScript = preload("res://scripts/ai/DeckStrategyMiraidon.gd")
const DeckStrategyArceusGiratinaScript = preload("res://scripts/ai/DeckStrategyArceusGiratina.gd")
const DeckStrategyDragapultDusknoirScript = preload("res://scripts/ai/DeckStrategyDragapultDusknoir.gd")
const DeckStrategyDragapultCharizardScript = preload("res://scripts/ai/DeckStrategyDragapultCharizard.gd")
const TrainingExportPathScript = preload("res://scripts/ai/TrainingExportPath.gd")
const AutoloadResolverScript = preload("res://scripts/engine/AutoloadResolver.gd")


func run_batch(
	agent_a_config: Dictionary,
	agent_b_config: Dictionary,
	deck_pairings: Array,
	seeds: Array,
	max_steps_per_match: int = 200,
	export_training_data: bool = false,
	export_action_training_data: bool = false,
	gardevoir_exporter: bool = false,
	miraidon_exporter: bool = false,
	encoder_id: String = "",
	training_data_dir: String = "",
	action_data_dir: String = "",
	pipeline_name: String = "",
) -> Dictionary:
	var runner := AIBenchmarkRunnerScript.new()
	var total_matches: int = 0
	var agent_a_wins: int = 0
	var agent_b_wins: int = 0
	var draws: int = 0
	var match_results: Array[Dictionary] = []

	for pairing: Variant in deck_pairings:
		if not pairing is Array or (pairing as Array).size() < 2:
			continue
		var deck_a_id: int = int((pairing as Array)[0])
		var deck_b_id: int = int((pairing as Array)[1])
		var card_database = AutoloadResolverScript.get_card_database()
		if card_database == null:
			print("[SelfPlay] CardDatabase autoload unavailable")
			break
		var deck_a: DeckData = card_database.get_deck(deck_a_id)
		var deck_b: DeckData = card_database.get_deck(deck_b_id)
		if deck_a == null or deck_b == null:
			print("[SelfPlay] 跳过无法加载的卡组对: %d vs %d" % [deck_a_id, deck_b_id])
			continue

		for seed_value: Variant in seeds:
			var sv: int = int(seed_value)
			var match_id_a0 := _build_self_play_match_id(sv, "a0", deck_a_id, deck_b_id)
			## agent_a 做 player 0
			var exporter_a0 = null
			var decision_exporter_a0 = null
			if export_training_data:
				exporter_a0 = _create_exporter(encoder_id, gardevoir_exporter, miraidon_exporter, training_data_dir)
			if export_action_training_data:
				decision_exporter_a0 = AIDecisionSampleExporterScript.new()
				if action_data_dir != "":
					decision_exporter_a0.base_dir = action_data_dir
			var result_a0 := _run_one_match(
				runner, agent_a_config, agent_b_config,
				deck_a, deck_b, sv, max_steps_per_match, exporter_a0, export_training_data,
				decision_exporter_a0, _build_decision_meta(match_id_a0, deck_a_id, deck_b_id, pipeline_name if pipeline_name != "" else "agent_a")
			)
			var match_entry_a0 := _build_match_entry(result_a0, sv, deck_a_id, deck_b_id, 0)
			match_results.append(match_entry_a0)
			total_matches += 1
			var winner_a0: int = int(result_a0.get("winner_index", -1))
			if winner_a0 == 0:
				agent_a_wins += 1
			elif winner_a0 == 1:
				agent_b_wins += 1
			else:
				draws += 1

			## agent_a 做 player 1
			var match_id_a1 := _build_self_play_match_id(sv + 10000, "a1", deck_a_id, deck_b_id)
			var exporter_a1 = null
			var decision_exporter_a1 = null
			if export_training_data:
				exporter_a1 = _create_exporter(encoder_id, gardevoir_exporter, miraidon_exporter, training_data_dir)
			if export_action_training_data:
				decision_exporter_a1 = AIDecisionSampleExporterScript.new()
				if action_data_dir != "":
					decision_exporter_a1.base_dir = action_data_dir
			var result_a1 := _run_one_match(
				runner, agent_b_config, agent_a_config,
				deck_a, deck_b, sv + 10000, max_steps_per_match, exporter_a1, export_training_data,
				decision_exporter_a1, _build_decision_meta(match_id_a1, deck_a_id, deck_b_id, pipeline_name if pipeline_name != "" else "agent_a")
			)
			var match_entry_a1 := _build_match_entry(result_a1, sv + 10000, deck_a_id, deck_b_id, 1)
			match_results.append(match_entry_a1)
			total_matches += 1
			var winner_a1: int = int(result_a1.get("winner_index", -1))
			if winner_a1 == 1:
				agent_a_wins += 1
			elif winner_a1 == 0:
				agent_b_wins += 1
			else:
				draws += 1

	var win_rate: float = 0.0 if total_matches == 0 else float(agent_a_wins) / float(total_matches)
	return {
		"total_matches": total_matches,
		"agent_a_wins": agent_a_wins,
		"agent_b_wins": agent_b_wins,
		"draws": draws,
		"agent_a_win_rate": win_rate,
		"match_results": match_results,
	}


func _run_one_match(
	runner: AIBenchmarkRunner,
	p0_config: Dictionary,
	p1_config: Dictionary,
	deck_a: DeckData,
	deck_b: DeckData,
	seed_value: int,
	max_steps: int,
	exporter = null,
	_export_training_data: bool = false,
	decision_exporter = null,
	decision_meta: Dictionary = {},
) -> Dictionary:
	## 进化搜索始终使用轻量 MCTS 加速对局评估
	var p0_ai := _make_agent(0, p0_config, true)
	var p1_ai := _make_agent(1, p1_config, true)
	if decision_exporter != null:
		if p0_ai.has_method("set_decision_exporter"):
			p0_ai.set_decision_exporter(decision_exporter)
		if p1_ai.has_method("set_decision_exporter"):
			p1_ai.set_decision_exporter(decision_exporter)

	var gsm := GameStateMachine.new()
	_apply_seed(gsm, seed_value)
	_set_forced_shuffle_seed(seed_value)
	gsm.start_game(deck_a, deck_b, 0)

	var step_cb := Callable()
	if exporter != null:
		exporter.start_game(decision_meta)
		## 记录初始状态
		exporter.record_state(gsm.game_state, 0)
		exporter.record_state(gsm.game_state, 1)
		## 用回调在每步后检查回合变化并记录
		var tracker := {"last_turn": gsm.game_state.turn_number, "last_player": gsm.game_state.current_player_index}
		step_cb = func(step_gsm: GameStateMachine) -> void:
			if step_gsm == null or step_gsm.game_state == null:
				return
			var tn: int = step_gsm.game_state.turn_number
			var cp: int = step_gsm.game_state.current_player_index
			if tn != tracker["last_turn"] or cp != tracker["last_player"]:
				tracker["last_turn"] = tn
				tracker["last_player"] = cp
				exporter.record_state(step_gsm.game_state, 0)
				exporter.record_state(step_gsm.game_state, 1)
	if decision_exporter != null:
		decision_exporter.start_game(decision_meta)

	var result: Dictionary = runner.run_headless_duel(p0_ai, p1_ai, gsm, max_steps, step_cb, decision_exporter)

	if exporter != null:
		exporter.end_game(result)
		exporter.export_game()
	if decision_exporter != null:
		decision_exporter.end_game(result)
		decision_exporter.export_game()

	_clear_forced_shuffle_seed()
	return result


func _build_decision_meta(match_id: String, deck_a_id: int, deck_b_id: int, pipeline_name: String) -> Dictionary:
	return {
		"run_id": match_id,
		"match_id": match_id,
		"pipeline_name": pipeline_name,
		"deck_identity": str(deck_a_id),
		"opponent_deck_identity": str(deck_b_id),
	}


func _build_self_play_match_id(seed_value: int, seat_tag: String, deck_a_id: int, deck_b_id: int) -> String:
	return TrainingExportPathScript.build_match_id(deck_a_id, deck_b_id, seed_value, seat_tag)


func _make_agent(player_index: int, config: Dictionary, fast_mode: bool = false) -> AIOpponent:
	var agent := AIOpponentScript.new()
	agent.configure(player_index, 1)
	var weights: Variant = config.get("heuristic_weights", {})
	if weights is Dictionary and not (weights as Dictionary).is_empty():
		agent.heuristic_weights = (weights as Dictionary).duplicate(true)
	var mcts: Variant = config.get("mcts_config", {})
	if mcts is Dictionary and not (mcts as Dictionary).is_empty():
		agent.use_mcts = true
		if fast_mode:
			## 数据导出模式：用极轻量 MCTS 加速对局同时保留交互处理能力
			agent.mcts_config = {
				"branch_factor": 2,
				"rollouts_per_sequence": 3,
				"rollout_max_steps": 30,
				"time_budget_ms": 500,
			}
		else:
			agent.mcts_config = (mcts as Dictionary).duplicate(true)
	var vn_path: Variant = config.get("value_net_path", "")
	if vn_path is String and (vn_path as String) != "":
		agent.value_net_path = vn_path as String
	var action_scorer_path: Variant = config.get("action_scorer_path", "")
	if action_scorer_path is String and (action_scorer_path as String) != "":
		agent.action_scorer_path = action_scorer_path as String
	var interaction_scorer_path: Variant = config.get("interaction_scorer_path", "")
	if interaction_scorer_path is String and (interaction_scorer_path as String) != "":
		agent.interaction_scorer_path = interaction_scorer_path as String
	return agent


func _build_match_entry(result: Dictionary, seed_value: int, deck_a_id: int, deck_b_id: int, agent_a_player_index: int) -> Dictionary:
	return {
		"winner_index": int(result.get("winner_index", -1)),
		"turn_count": int(result.get("turn_count", 0)),
		"steps": int(result.get("steps", 0)),
		"seed": seed_value,
		"deck_a_id": deck_a_id,
		"deck_b_id": deck_b_id,
		"agent_a_player_index": agent_a_player_index,
		"failure_reason": str(result.get("failure_reason", "")),
		"terminated_by_cap": bool(result.get("terminated_by_cap", false)),
		"stalled": bool(result.get("stalled", false)),
		"event_counters": result.get("event_counters", {}),
	}


func _apply_seed(gsm: GameStateMachine, seed_value: int) -> void:
	if gsm == null or gsm.coin_flipper == null:
		return
	var rng: Variant = gsm.coin_flipper.get("_rng")
	if rng is RandomNumberGenerator:
		(rng as RandomNumberGenerator).seed = seed_value


func _set_forced_shuffle_seed(seed_value: int) -> void:
	var ps := PlayerState.new()
	if ps.has_method("set_forced_shuffle_seed"):
		ps.call("set_forced_shuffle_seed", seed_value)


func _clear_forced_shuffle_seed() -> void:
	var ps := PlayerState.new()
	if ps.has_method("clear_forced_shuffle_seed"):
		ps.call("clear_forced_shuffle_seed")


func _create_exporter(encoder_id: String, gardevoir_flag: bool, miraidon_flag: bool, training_data_dir: String = "") -> RefCounted:
	## 统一导出器工厂：优先用 encoder_id，兼容旧 bool 标志
	var eid: String = encoder_id
	if eid == "" and gardevoir_flag:
		eid = "gardevoir"
	if eid == "" and miraidon_flag:
		eid = "miraidon"
	match eid:
		"gardevoir":
			var exp := GardevoirSelfPlayDataExporterScript.new()
			exp.deck_strategy = DeckStrategyGardevoirScript.new()
			if training_data_dir != "":
				exp.base_dir = training_data_dir
			return exp
		"miraidon":
			var exp := MiraidonSelfPlayDataExporterScript.new()
			exp.deck_strategy = DeckStrategyMiraidonScript.new()
			if training_data_dir != "":
				exp.base_dir = training_data_dir
			return exp
		"arceus_giratina":
			var exp := ArceusGiratinaSelfPlayDataExporterScript.new()
			exp.deck_strategy = DeckStrategyArceusGiratinaScript.new()
			if training_data_dir != "":
				exp.base_dir = training_data_dir
			return exp
		"dragapult_dusknoir":
			var exp := DragapultDusknoirSelfPlayDataExporterScript.new()
			exp.deck_strategy = DeckStrategyDragapultDusknoirScript.new()
			if training_data_dir != "":
				exp.base_dir = training_data_dir
			return exp
		"dragapult_charizard":
			var exp := DragapultCharizardSelfPlayDataExporterScript.new()
			exp.deck_strategy = DeckStrategyDragapultCharizardScript.new()
			if training_data_dir != "":
				exp.base_dir = training_data_dir
			return exp
	var fallback := SelfPlayDataExporterScript.new()
	if training_data_dir != "":
		fallback.base_dir = training_data_dir
	return fallback
