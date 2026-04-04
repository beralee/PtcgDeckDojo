class_name MCTSPlanner
extends RefCounted

## MCTS 回合序列搜索器。
## 用 beam search 枚举候选回合序列，对每条序列跑 rollout 评估胜率。

const GameStateClonerScript = preload("res://scripts/ai/GameStateCloner.gd")
const RolloutSimulatorScript = preload("res://scripts/ai/RolloutSimulator.gd")
const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")
const AIHeuristicsScript = preload("res://scripts/ai/AIHeuristics.gd")
const AIFeatureExtractorScript = preload("res://scripts/ai/AIFeatureExtractor.gd")
const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")

const ACTION_SCORER_SUPPORTED_KINDS := {
	"play_trainer": true,
	"use_ability": true,
	"attach_tool": true,
	"attach_energy": true,
	"attack": true,
}
const ACTION_SCORER_SCORE_SCALE: float = 200.0

var _cloner := GameStateClonerScript.new()
var _rollout_sim := RolloutSimulatorScript.new()
var _action_builder := AILegalActionBuilderScript.new()
var _heuristics := AIHeuristicsScript.new()
var _feature_extractor := AIFeatureExtractorScript.new()
var action_scorer: RefCounted = null

## 价值网络（可选）：如果已加载则用于替代 rollout
var value_net: RefCounted = null  # NeuralNetInference
var state_encoder_class: GDScript = null  # StateEncoder

## 默认搜索参数
const DEFAULT_BRANCH_FACTOR: int = 3
const DEFAULT_MAX_ACTIONS: int = 10
const DEFAULT_ROLLOUTS: int = 30
const DEFAULT_ROLLOUT_MAX_STEPS: int = 100
const DEFAULT_TIME_BUDGET_MS: int = 3000
const EXECUTION_FAILURE_SAMPLE_LIMIT: int = 8

var _execution_failure_category_counts: Dictionary = {}
var _execution_failure_kind_counts: Dictionary = {}
var _execution_failure_samples: Array[Dictionary] = []


func plan_turn(gsm: GameStateMachine, player_index: int, config: Dictionary = {}) -> Array:
	if gsm == null or gsm.game_state == null:
		return [{"kind": "end_turn"}]
	clear_execution_failure_diagnostics()

	var branch_factor: int = int(config.get("branch_factor", DEFAULT_BRANCH_FACTOR))
	var max_actions: int = int(config.get("max_actions_per_turn", DEFAULT_MAX_ACTIONS))
	var rollouts: int = int(config.get("rollouts_per_sequence", DEFAULT_ROLLOUTS))
	var rollout_steps: int = int(config.get("rollout_max_steps", DEFAULT_ROLLOUT_MAX_STEPS))
	var time_budget: int = int(config.get("time_budget_ms", DEFAULT_TIME_BUDGET_MS))

	## 第一步：枚举候选序列（在克隆上操作，不修改原始 gsm）
	var sequences: Array = _enumerate_sequences(gsm, player_index, branch_factor, max_actions)
	if sequences.is_empty():
		return [{"kind": "end_turn"}]

	## 第二步：对每条序列跑 rollout 评估
	var best_sequence: Array = sequences[0]
	var best_win_rate: float = -1.0
	var best_action_count: int = 0
	var start_time: int = Time.get_ticks_msec()

	var deadline: int = start_time + time_budget

	_mcts_debug("[MCTS] 候选序列数: %d, rollouts/seq: %d, budget: %dms" % [sequences.size(), rollouts, time_budget])

	for sequence: Array in sequences:
		if Time.get_ticks_msec() > deadline:
			_mcts_debug("[MCTS] 时间预算用尽，已评估部分序列")
			break
		var win_rate: float = _evaluate_sequence(gsm, player_index, sequence, rollouts, rollout_steps, deadline)
		var action_count: int = _count_game_actions(sequence)
		## 胜率更高则替换；胜率相同时，优先选择有更多实际动作的序列
		if win_rate > best_win_rate or (win_rate == best_win_rate and action_count > best_action_count):
			best_win_rate = win_rate
			best_sequence = sequence
			best_action_count = action_count

	return best_sequence


func _enumerate_sequences(
	gsm: GameStateMachine,
	player_index: int,
	branch_factor: int,
	max_depth: int
) -> Array:
	## 用 beam search 枚举候选回合序列
	var results: Array = []
	var initial_clone := _cloner.clone_gsm(gsm)
	_expand_sequences(initial_clone, player_index, [], branch_factor, max_depth, results)
	## 如果没有展开出任何序列，至少返回 end_turn
	if results.is_empty():
		results.append([{"kind": "end_turn"}])
	return results


func _expand_sequences(
	gsm: GameStateMachine,
	player_index: int,
	current_sequence: Array,
	branch_factor: int,
	remaining_depth: int,
	results: Array
) -> void:
	if remaining_depth <= 0:
		var final_seq: Array = current_sequence.duplicate()
		final_seq.append({"kind": "end_turn"})
		results.append(final_seq)
		return

	var actions: Array[Dictionary] = _action_builder.build_actions(gsm, player_index)
	actions = _filter_headless_compatible_actions(actions)
	if current_sequence.is_empty():
		var _action_kinds: Array[String] = []
		for _a: Dictionary in actions:
			_action_kinds.append(str(_a.get("kind", "")))
		_mcts_debug("[MCTS-EXPAND] depth=%d 合法动作(%d): %s" % [remaining_depth, actions.size(), ", ".join(_action_kinds)])
	if actions.is_empty():
		var final_seq: Array = current_sequence.duplicate()
		final_seq.append({"kind": "end_turn"})
		results.append(final_seq)
		return

	## 用 heuristic 评分并取 top-K
	var scored: Array = _score_and_rank_actions(gsm, player_index, actions)
	var top_k: Array = scored.slice(0, mini(branch_factor, scored.size()))
	if current_sequence.is_empty():
		var _top_kinds: Array[String] = []
		for _e: Dictionary in top_k:
			var _ea: Dictionary = _e.get("action", {})
			_top_kinds.append("%s(%.0f)" % [str(_ea.get("kind", "")), float(_e.get("score", 0))])
		_mcts_debug("[MCTS-EXPAND] top-K: %s" % ", ".join(_top_kinds))

	## 始终把 end_turn 作为一个候选分支（不管是否在 top-K 中）
	var has_end_turn_in_top_k: bool = false
	var any_branch_succeeded: bool = false

	for entry: Dictionary in top_k:
		var action: Dictionary = entry.get("action", {})
		var kind: String = str(action.get("kind", ""))

		if kind == "end_turn":
			has_end_turn_in_top_k = true
			var final_seq: Array = current_sequence.duplicate()
			final_seq.append(action)
			results.append(final_seq)
			any_branch_succeeded = true
			continue

		## 对非终结动作：克隆状态、解析引用、执行、递归
		var branch_gsm := _cloner.clone_gsm(gsm)
		var resolved_action := _resolve_action_for_gsm(action, branch_gsm, player_index)
		var executed := _try_execute_action_with_diagnostics(branch_gsm, player_index, action, resolved_action)
		if not executed:
			_mcts_debug("[MCTS-EXPAND] 执行失败: kind=%s" % kind)
			continue

		any_branch_succeeded = true
		## 保存原始 action（带原始 kind 等纯数据字段）到序列
		var next_seq: Array = current_sequence.duplicate()
		next_seq.append(_serialize_action(action))

		## 如果执行后游戏阶段不再是 MAIN 或玩家切换，这条分支结束
		if branch_gsm.game_state.phase != GameState.GamePhase.MAIN \
				or branch_gsm.game_state.current_player_index != player_index:
			results.append(next_seq)
			continue

		_expand_sequences(branch_gsm, player_index, next_seq, branch_factor, remaining_depth - 1, results)

	## 兜底：如果没有 end_turn 在 top-K 中且没有任何分支成功，补一条 end_turn
	if not any_branch_succeeded or (not has_end_turn_in_top_k and current_sequence.size() > 0):
		var fallback_seq: Array = current_sequence.duplicate()
		fallback_seq.append({"kind": "end_turn"})
		if not any_branch_succeeded:
			results.append(fallback_seq)


func _score_and_rank_actions(
	gsm: GameStateMachine,
	player_index: int,
	actions: Array[Dictionary]
) -> Array:
	var scored: Array = []
	var state_features: Array = StateEncoderScript.encode(gsm.game_state, player_index) if gsm != null and gsm.game_state != null else []
	for action: Dictionary in actions:
		var context := {
			"gsm": gsm,
			"game_state": gsm.game_state,
			"player_index": player_index,
			"features": _feature_extractor.build_context(gsm, player_index, action),
		}
		var heuristic_score: float = _heuristics.score_action(action, context)
		var learned_action_score: float = _score_action_with_model(str(action.get("kind", "")), state_features, context.get("features", {}))
		var score: float = heuristic_score + learned_action_score
		scored.append({"action": action, "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	return scored


func _score_action_with_model(action_kind: String, state_features: Array, features: Dictionary) -> float:
	if action_scorer == null or not ACTION_SCORER_SUPPORTED_KINDS.has(action_kind):
		return 0.0
	var action_vector_variant: Variant = features.get("action_vector", [])
	if not (action_vector_variant is Array) or (action_vector_variant as Array).is_empty():
		return 0.0
	if not action_scorer.has_method("score"):
		return 0.0
	var prediction: float = float(action_scorer.call("score", state_features, action_vector_variant))
	return (prediction - 0.5) * ACTION_SCORER_SCORE_SCALE


func _evaluate_sequence(
	gsm: GameStateMachine,
	player_index: int,
	sequence: Array,
	num_rollouts: int,
	max_rollout_steps: int,
	deadline_ms: int = 0
) -> float:
	## 克隆状态、执行整条序列、然后评估
	var sim_gsm := _cloner.clone_gsm(gsm)
	for action: Dictionary in sequence:
		var kind: String = str(action.get("kind", ""))
		if kind == "end_turn":
			if sim_gsm.game_state.phase == GameState.GamePhase.MAIN:
				sim_gsm.end_turn(player_index)
			break
		var resolved := _resolve_action_for_gsm(action, sim_gsm, player_index)
		if not _try_execute_action_with_diagnostics(sim_gsm, player_index, action, resolved):
			return 0.0
		if sim_gsm.game_state.is_game_over():
			break

	if sim_gsm.game_state.is_game_over():
		return 1.0 if sim_gsm.game_state.winner_index == player_index else 0.0

	## 价值网络路径：如果可用，用一次前向推理替代多次 rollout
	if value_net != null and value_net.is_loaded() and state_encoder_class != null:
		var features: Array[float] = state_encoder_class.encode(sim_gsm.game_state, player_index)
		return value_net.predict(features)

	## Rollout 路径（原有逻辑）
	var wins: int = 0
	var completed_rollouts: int = 0
	for _i in num_rollouts:
		if deadline_ms > 0 and Time.get_ticks_msec() > deadline_ms:
			break
		var result: Dictionary = _rollout_sim.run_rollout(sim_gsm, player_index, max_rollout_steps)
		completed_rollouts += 1
		if int(result.get("winner_index", -1)) == player_index:
			wins += 1
	return float(wins) / float(completed_rollouts) if completed_rollouts > 0 else 0.0


func _try_execute_action(gsm: GameStateMachine, player_index: int, action: Dictionary) -> bool:
	## 在克隆的 gsm 上直接执行动作（无 UI）
	var kind: String = str(action.get("kind", ""))
	match kind:
		"attach_energy":
			var target_slot: PokemonSlot = action.get("target_slot")
			var card: CardInstance = action.get("card")
			if card == null or target_slot == null:
				return false
			return gsm.attach_energy(player_index, card, target_slot)
		"attach_tool":
			var tool_target_slot: PokemonSlot = action.get("target_slot")
			var tool_card: CardInstance = action.get("card")
			if tool_card == null or tool_target_slot == null:
				return false
			return gsm.attach_tool(player_index, tool_card, tool_target_slot)
		"play_basic_to_bench":
			var card: CardInstance = action.get("card")
			if card == null:
				return false
			return gsm.play_basic_to_bench(player_index, card)
		"evolve":
			var card: CardInstance = action.get("card")
			var target_slot: PokemonSlot = action.get("target_slot")
			if card == null or target_slot == null:
				return false
			return gsm.evolve_pokemon(player_index, card, target_slot)
		"play_trainer":
			if bool(action.get("requires_interaction", false)):
				return false
			var card: CardInstance = action.get("card")
			if card == null:
				return false
			return gsm.play_trainer(player_index, card, action.get("targets", []))
		"play_stadium":
			if bool(action.get("requires_interaction", false)):
				return false
			var card: CardInstance = action.get("card")
			if card == null:
				return false
			return gsm.play_stadium(player_index, card, action.get("targets", []))
		"use_ability":
			if bool(action.get("requires_interaction", false)):
				return false
			var source_slot: PokemonSlot = action.get("source_slot")
			if source_slot == null:
				return false
			return gsm.use_ability(player_index, source_slot, int(action.get("ability_index", 0)), action.get("targets", []))
		"attack":
			if bool(action.get("requires_interaction", false)):
				return false
			return gsm.use_attack(player_index, int(action.get("attack_index", -1)), action.get("targets", []))
		"retreat":
			var energy_to_discard: Variant = action.get("energy_to_discard", [])
			var bench_target: PokemonSlot = action.get("bench_target")
			if bench_target == null:
				return false
			var typed_discard: Array[CardInstance] = []
			if energy_to_discard is Array:
				for e: Variant in energy_to_discard:
					if e is CardInstance:
						typed_discard.append(e)
			return gsm.retreat(player_index, typed_discard, bench_target)
		"end_turn":
			gsm.end_turn(player_index)
			return true
	return false


func _try_execute_action_with_diagnostics(
	gsm: GameStateMachine,
	player_index: int,
	planned_action: Dictionary,
	resolved_action: Dictionary
) -> bool:
	if resolved_action.is_empty():
		_record_execution_failure("action_resolution_mismatch", planned_action, resolved_action, gsm, player_index)
		return false
	var executed: bool = _try_execute_action(gsm, player_index, resolved_action)
	if not executed:
		var failure_category: String = _classify_execution_failure(gsm, player_index, planned_action, resolved_action)
		_record_execution_failure(failure_category, planned_action, resolved_action, gsm, player_index)
	return executed


func clear_execution_failure_diagnostics() -> void:
	_execution_failure_category_counts.clear()
	_execution_failure_kind_counts.clear()
	_execution_failure_samples.clear()


func get_execution_failure_diagnostics() -> Dictionary:
	return {
		"mcts_failure_category_counts": _execution_failure_category_counts.duplicate(true),
		"mcts_failure_kind_counts": _execution_failure_kind_counts.duplicate(true),
		"mcts_failure_samples": _execution_failure_samples.duplicate(true),
	}


func _classify_execution_failure(
	gsm: GameStateMachine,
	player_index: int,
	planned_action: Dictionary,
	resolved_action: Dictionary
) -> String:
	if resolved_action.is_empty():
		return "action_resolution_mismatch"

	var kind: String = str(planned_action.get("kind", resolved_action.get("kind", "")))
	if _action_requires_headless_interaction(gsm, planned_action, resolved_action):
		return "headless_interaction_required"
	if _action_has_missing_reference(kind, resolved_action):
		return "action_missing_reference"
	match kind:
		"play_trainer":
			var trainer_card: CardInstance = resolved_action.get("card")
			if trainer_card != null and trainer_card.card_data != null:
				if trainer_card.card_data.card_type == "Supporter" and gsm != null and gsm.game_state != null and gsm.game_state.supporter_used_this_turn:
					return "rule_reject_supporter_used"
				var trainer_effect: BaseEffect = null if gsm == null else gsm.effect_processor.get_effect(trainer_card.card_data.effect_id)
				if trainer_effect != null and not trainer_effect.can_execute(trainer_card, gsm.game_state):
					return "trainer_effect_cannot_execute"
			return "trainer_effect_execution_failed"
		"attack":
			if gsm != null and not gsm.can_use_attack(player_index, int(resolved_action.get("attack_index", -1))):
				return "rule_reject_attack_not_ready"
			return "attack_execution_failed"
		"use_ability":
			var source_slot: PokemonSlot = resolved_action.get("source_slot")
			if gsm != null and source_slot != null and not gsm.effect_processor.can_use_ability(source_slot, gsm.game_state, int(resolved_action.get("ability_index", 0))):
				return "rule_reject_ability_unavailable"
			return "ability_effect_execution_failed"
	return "system_execution_error"


func _action_requires_headless_interaction(
	gsm: GameStateMachine,
	planned_action: Dictionary,
	resolved_action: Dictionary
) -> bool:
	if bool(planned_action.get("requires_interaction", resolved_action.get("requires_interaction", false))):
		return true
	if gsm == null or gsm.game_state == null:
		return false
	var kind: String = str(planned_action.get("kind", resolved_action.get("kind", "")))
	match kind:
		"play_trainer":
			var trainer_card: CardInstance = resolved_action.get("card")
			if trainer_card == null or trainer_card.card_data == null:
				return false
			var trainer_effect: BaseEffect = gsm.effect_processor.get_effect(trainer_card.card_data.effect_id)
			return trainer_effect != null and not trainer_effect.get_interaction_steps(trainer_card, gsm.game_state).is_empty()
		"play_stadium":
			var stadium_card: CardInstance = resolved_action.get("card")
			if stadium_card == null or stadium_card.card_data == null:
				return false
			var stadium_effect: BaseEffect = gsm.effect_processor.get_effect(stadium_card.card_data.effect_id)
			return stadium_effect != null and not stadium_effect.get_on_play_interaction_steps(stadium_card, gsm.game_state).is_empty()
		"use_ability":
			var source_slot: PokemonSlot = resolved_action.get("source_slot")
			if source_slot == null:
				return false
			var ability_index: int = int(resolved_action.get("ability_index", 0))
			var source_card: CardInstance = gsm.effect_processor.get_ability_source_card(source_slot, ability_index, gsm.game_state)
			var ability_effect: BaseEffect = gsm.effect_processor.get_ability_effect(source_slot, ability_index, gsm.game_state)
			return source_card != null and ability_effect != null and not ability_effect.get_interaction_steps(source_card, gsm.game_state).is_empty()
		"attack":
			return bool(resolved_action.get("requires_interaction", false))
	return false


func _action_has_missing_reference(kind: String, resolved_action: Dictionary) -> bool:
	match kind:
		"attach_energy":
			return resolved_action.get("card") == null or resolved_action.get("target_slot") == null
		"play_basic_to_bench":
			return resolved_action.get("card") == null
		"evolve":
			return resolved_action.get("card") == null or resolved_action.get("target_slot") == null
		"play_trainer", "play_stadium":
			return resolved_action.get("card") == null
		"use_ability":
			return resolved_action.get("source_slot") == null
		"retreat":
			return resolved_action.get("bench_target") == null
	return false


func _record_execution_failure(
	category: String,
	planned_action: Dictionary,
	resolved_action: Dictionary,
	gsm: GameStateMachine,
	player_index: int
) -> void:
	if category == "":
		category = "system_execution_error"
	var kind: String = str(planned_action.get("kind", resolved_action.get("kind", "")))
	_execution_failure_category_counts[category] = int(_execution_failure_category_counts.get(category, 0)) + 1
	if kind != "":
		_execution_failure_kind_counts[kind] = int(_execution_failure_kind_counts.get(kind, 0)) + 1
	if _execution_failure_samples.size() >= EXECUTION_FAILURE_SAMPLE_LIMIT:
		return
	var sample := {
		"category": category,
		"kind": kind,
		"turn_number": -1 if gsm == null or gsm.game_state == null else int(gsm.game_state.turn_number),
		"step_index": _execution_failure_samples.size() + 1,
		"requires_interaction": bool(planned_action.get("requires_interaction", resolved_action.get("requires_interaction", false))),
	}
	var card: CardInstance = resolved_action.get("card", planned_action.get("card"))
	if card != null and card.card_data != null:
		sample["card_name"] = card.card_data.name
		sample["effect_id"] = card.card_data.effect_id
	var source_slot: PokemonSlot = resolved_action.get("source_slot", planned_action.get("source_slot"))
	if source_slot != null and source_slot.get_top_card() != null:
		sample["source_pokemon_name"] = source_slot.get_pokemon_name()
		var source_card: CardInstance = source_slot.get_top_card()
		if source_card != null and source_card.card_data != null:
			sample["effect_id"] = source_card.card_data.effect_id
	var ability_index: int = int(resolved_action.get("ability_index", planned_action.get("ability_index", -1)))
	if ability_index >= 0:
		sample["ability_index"] = ability_index
		if gsm != null and source_slot != null:
			var ability_name: String = gsm.effect_processor.get_ability_name(source_slot, ability_index, gsm.game_state)
			if ability_name != "":
				sample["ability_name"] = ability_name
	var attack_index: int = int(resolved_action.get("attack_index", planned_action.get("attack_index", -1)))
	if attack_index >= 0:
		sample["attack_index"] = attack_index
		if gsm != null:
			var attack_reason: String = gsm.get_attack_unusable_reason(player_index, attack_index)
			if attack_reason != "":
				sample["attack_unusable_reason"] = attack_reason
	if category == "action_missing_reference":
		var missing_fields: Array[String] = []
		match kind:
			"attach_energy", "evolve":
				if resolved_action.get("card") == null:
					missing_fields.append("card")
				if resolved_action.get("target_slot") == null:
					missing_fields.append("target_slot")
			"play_basic_to_bench", "play_trainer", "play_stadium":
				if resolved_action.get("card") == null:
					missing_fields.append("card")
			"use_ability":
				if resolved_action.get("source_slot") == null:
					missing_fields.append("source_slot")
			"retreat":
				if resolved_action.get("bench_target") == null:
					missing_fields.append("bench_target")
		if not missing_fields.is_empty():
			sample["missing_fields"] = missing_fields
	_execution_failure_samples.append(sample)


## 计算序列中非 end_turn 的实际游戏动作数量
func _count_game_actions(sequence: Array) -> int:
	var count: int = 0
	for action: Dictionary in sequence:
		if str(action.get("kind", "")) != "end_turn":
			count += 1
	return count


func _filter_headless_compatible_actions(actions: Array[Dictionary]) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for action: Dictionary in actions:
		if bool(action.get("requires_interaction", false)):
			continue
		filtered.append(action)
	return filtered


## 将动作中的对象引用解析到目标 gsm 的对应对象上。
## 因为克隆后 CardInstance 和 PokemonSlot 是新对象，
## 必须通过 instance_id / 位置索引找到克隆体中的对应对象。
func _resolve_action_for_gsm(action: Dictionary, gsm: GameStateMachine, player_index: int) -> Dictionary:
	var resolved := action.duplicate()
	var kind: String = str(action.get("kind", ""))
	if player_index < 0 or player_index >= gsm.game_state.players.size():
		return resolved
	var player: PlayerState = gsm.game_state.players[player_index]

	## 解析手牌中的 card 引用
	if action.has("card_instance_id"):
		var card_instance_id: int = int(action.get("card_instance_id", -1))
		if card_instance_id >= 0:
			resolved["card"] = _find_card_in_hand_by_instance_id(player, card_instance_id)
	elif action.has("card") and action.get("card") is CardInstance:
		var original_card: CardInstance = action.get("card")
		resolved["card"] = _find_card_in_hand(player, original_card)

	## 解析 target_slot 引用
	if action.has("target_slot_card_id"):
		var target_slot_card_id: int = int(action.get("target_slot_card_id", -1))
		if target_slot_card_id >= 0:
			resolved["target_slot"] = _find_matching_slot_by_top_card_id(player, target_slot_card_id)
	elif action.has("target_slot") and action.get("target_slot") is PokemonSlot:
		var original_slot: PokemonSlot = action.get("target_slot")
		resolved["target_slot"] = _find_matching_slot(player, original_slot)

	## 解析 source_slot 引用（特性来源）
	if action.has("source_slot_card_id"):
		var source_slot_card_id: int = int(action.get("source_slot_card_id", -1))
		if source_slot_card_id >= 0:
			resolved["source_slot"] = _find_matching_slot_by_top_card_id(player, source_slot_card_id)
	elif action.has("source_slot") and action.get("source_slot") is PokemonSlot:
		var original_slot: PokemonSlot = action.get("source_slot")
		resolved["source_slot"] = _find_matching_slot(player, original_slot)

	if action.has("bench_target_card_id"):
		var bench_target_card_id: int = int(action.get("bench_target_card_id", -1))
		if bench_target_card_id >= 0:
			resolved["bench_target"] = _find_bench_slot_by_top_card_id(player, bench_target_card_id)

	if action.has("energy_to_discard_ids") and action.get("energy_to_discard_ids") is PackedInt32Array:
		var discard_ids: PackedInt32Array = action.get("energy_to_discard_ids")
		var resolved_discard_ids: Array[CardInstance] = []
		if player.active_pokemon != null:
			for discard_id: int in discard_ids:
				var found_by_id: CardInstance = _find_card_by_instance_id(player.active_pokemon.attached_energy, discard_id)
				if found_by_id != null:
					resolved_discard_ids.append(found_by_id)
		resolved["energy_to_discard"] = resolved_discard_ids

	## 解析 bench_target 引用（撤退目标）
	if action.has("bench_target") and action.get("bench_target") is PokemonSlot:
		var original_slot: PokemonSlot = action.get("bench_target")
		resolved["bench_target"] = _find_bench_slot(player, original_slot)

	## 解析 energy_to_discard 引用（撤退弃能）
	if action.has("energy_to_discard") and action.get("energy_to_discard") is Array:
		var original_energies: Array = action.get("energy_to_discard")
		var resolved_energies: Array[CardInstance] = []
		if player.active_pokemon != null:
			for orig_energy: Variant in original_energies:
				if orig_energy is CardInstance:
					var found := _find_card_by_id(player.active_pokemon.attached_energy, orig_energy)
					if found != null:
						resolved_energies.append(found)
		resolved["energy_to_discard"] = resolved_energies

	if action.has("targets") and action.get("targets") is Array:
		resolved["targets"] = _resolve_targets_for_gsm(action.get("targets"), gsm, player_index)

	return resolved


## 在手牌中按 instance_id 查找对应卡牌
func _find_card_in_hand(player: PlayerState, original: CardInstance) -> CardInstance:
	if original == null:
		return null
	for card: CardInstance in player.hand:
		if card != null and card.instance_id == original.instance_id:
			return card
	return null


func _find_card_in_hand_by_instance_id(player: PlayerState, instance_id: int) -> CardInstance:
	if instance_id < 0:
		return null
	for card: CardInstance in player.hand:
		if card != null and card.instance_id == instance_id:
			return card
	return null


## 在玩家所有槽位中查找匹配的 PokemonSlot（通过顶层卡牌 instance_id）
func _find_matching_slot(player: PlayerState, original_slot: PokemonSlot) -> PokemonSlot:
	if original_slot == null:
		return null
	var orig_top: CardInstance = original_slot.get_top_card()
	if orig_top == null:
		return null
	## 先检查前场
	if player.active_pokemon != null:
		var top: CardInstance = player.active_pokemon.get_top_card()
		if top != null and top.instance_id == orig_top.instance_id:
			return player.active_pokemon
	## 再检查后备
	for slot: PokemonSlot in player.bench:
		if slot == null:
			continue
		var top: CardInstance = slot.get_top_card()
		if top != null and top.instance_id == orig_top.instance_id:
			return slot
	return null


func _find_matching_slot_by_top_card_id(player: PlayerState, top_card_id: int) -> PokemonSlot:
	if top_card_id < 0:
		return null
	if player.active_pokemon != null:
		var active_top: CardInstance = player.active_pokemon.get_top_card()
		if active_top != null and active_top.instance_id == top_card_id:
			return player.active_pokemon
	for slot: PokemonSlot in player.bench:
		if slot == null:
			continue
		var top: CardInstance = slot.get_top_card()
		if top != null and top.instance_id == top_card_id:
			return slot
	return null


## 在后备区查找匹配的 PokemonSlot
func _find_bench_slot(player: PlayerState, original_slot: PokemonSlot) -> PokemonSlot:
	if original_slot == null:
		return null
	var orig_top: CardInstance = original_slot.get_top_card()
	if orig_top == null:
		return null
	for slot: PokemonSlot in player.bench:
		if slot == null:
			continue
		var top: CardInstance = slot.get_top_card()
		if top != null and top.instance_id == orig_top.instance_id:
			return slot
	return null


func _find_bench_slot_by_top_card_id(player: PlayerState, top_card_id: int) -> PokemonSlot:
	if top_card_id < 0:
		return null
	for slot: PokemonSlot in player.bench:
		if slot == null:
			continue
		var top: CardInstance = slot.get_top_card()
		if top != null and top.instance_id == top_card_id:
			return slot
	return null


## 在卡牌数组中按 instance_id 查找
func _find_card_by_id(cards: Array[CardInstance], original: CardInstance) -> CardInstance:
	if original == null:
		return null
	for card: CardInstance in cards:
		if card != null and card.instance_id == original.instance_id:
			return card
	return null


func _find_card_by_instance_id(cards: Array[CardInstance], instance_id: int) -> CardInstance:
	if instance_id < 0:
		return null
	for card: CardInstance in cards:
		if card != null and card.instance_id == instance_id:
			return card
	return null


func _resolve_targets_for_gsm(targets: Array, gsm: GameStateMachine, player_index: int) -> Array:
	var resolved_targets: Array = []
	for target: Variant in targets:
		resolved_targets.append(_resolve_target_value(target, gsm, player_index))
	return resolved_targets


func _resolve_target_value(value: Variant, gsm: GameStateMachine, player_index: int) -> Variant:
	if value is Dictionary:
		var value_dict: Dictionary = value
		if str(value_dict.get("__type", "")) == "card_ref":
			return _find_card_anywhere_by_instance_id(gsm, int(value_dict.get("instance_id", -1)))
		if str(value_dict.get("__type", "")) == "slot_ref":
			return _find_slot_anywhere_by_top_card_id(gsm, int(value_dict.get("top_card_id", -1)), player_index)
		var resolved_dict := {}
		for key: Variant in value_dict.keys():
			resolved_dict[key] = _resolve_target_value(value_dict[key], gsm, player_index)
		return resolved_dict
	if value is Array:
		var resolved_array: Array = []
		for item: Variant in value:
			resolved_array.append(_resolve_target_value(item, gsm, player_index))
		return resolved_array
	if value is CardInstance:
		return _find_card_anywhere(gsm, value)
	if value is PokemonSlot:
		return _find_slot_anywhere(gsm, value, player_index)
	return value


func _find_card_anywhere(gsm: GameStateMachine, original: CardInstance) -> CardInstance:
	if gsm == null or gsm.game_state == null or original == null:
		return null
	for player: PlayerState in gsm.game_state.players:
		var found: CardInstance = _find_card_by_id(player.hand, original)
		if found != null:
			return found
		found = _find_card_by_id(player.deck, original)
		if found != null:
			return found
		found = _find_card_by_id(player.discard_pile, original)
		if found != null:
			return found
		found = _find_card_by_id(player.prizes, original)
		if found != null:
			return found
		found = _find_card_by_id(player.lost_zone, original)
		if found != null:
			return found
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot == null:
				continue
			found = _find_card_by_id(slot.pokemon_stack, original)
			if found != null:
				return found
			found = _find_card_by_id(slot.attached_energy, original)
			if found != null:
				return found
			if slot.attached_tool != null and slot.attached_tool.instance_id == original.instance_id:
				return slot.attached_tool
	if gsm.game_state.stadium_card != null and gsm.game_state.stadium_card.instance_id == original.instance_id:
		return gsm.game_state.stadium_card
	return null


func _find_card_anywhere_by_instance_id(gsm: GameStateMachine, instance_id: int) -> CardInstance:
	if gsm == null or gsm.game_state == null or instance_id < 0:
		return null
	for player: PlayerState in gsm.game_state.players:
		var found: CardInstance = _find_card_by_instance_id(player.hand, instance_id)
		if found != null:
			return found
		found = _find_card_by_instance_id(player.deck, instance_id)
		if found != null:
			return found
		found = _find_card_by_instance_id(player.discard_pile, instance_id)
		if found != null:
			return found
		found = _find_card_by_instance_id(player.prizes, instance_id)
		if found != null:
			return found
		found = _find_card_by_instance_id(player.lost_zone, instance_id)
		if found != null:
			return found
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot == null:
				continue
			found = _find_card_by_instance_id(slot.pokemon_stack, instance_id)
			if found != null:
				return found
			found = _find_card_by_instance_id(slot.attached_energy, instance_id)
			if found != null:
				return found
			if slot.attached_tool != null and slot.attached_tool.instance_id == instance_id:
				return slot.attached_tool
	if gsm.game_state.stadium_card != null and gsm.game_state.stadium_card.instance_id == instance_id:
		return gsm.game_state.stadium_card
	return null


func _find_slot_anywhere(gsm: GameStateMachine, original_slot: PokemonSlot, player_index: int) -> PokemonSlot:
	if gsm == null or gsm.game_state == null or original_slot == null:
		return null
	if player_index >= 0 and player_index < gsm.game_state.players.size():
		var own_player: PlayerState = gsm.game_state.players[player_index]
		var own_match: PokemonSlot = _find_matching_slot(own_player, original_slot)
		if own_match != null:
			return own_match
		var own_bench_match: PokemonSlot = _find_bench_slot(own_player, original_slot)
		if own_bench_match != null:
			return own_bench_match
	for player: PlayerState in gsm.game_state.players:
		var slot_match: PokemonSlot = _find_matching_slot(player, original_slot)
		if slot_match != null:
			return slot_match
		slot_match = _find_bench_slot(player, original_slot)
		if slot_match != null:
			return slot_match
	return null


func _find_slot_anywhere_by_top_card_id(gsm: GameStateMachine, top_card_id: int, player_index: int) -> PokemonSlot:
	if gsm == null or gsm.game_state == null or top_card_id < 0:
		return null
	if player_index >= 0 and player_index < gsm.game_state.players.size():
		var own_player: PlayerState = gsm.game_state.players[player_index]
		var own_match: PokemonSlot = _find_matching_slot_by_top_card_id(own_player, top_card_id)
		if own_match != null:
			return own_match
		var own_bench_match: PokemonSlot = _find_bench_slot_by_top_card_id(own_player, top_card_id)
		if own_bench_match != null:
			return own_bench_match
	for player: PlayerState in gsm.game_state.players:
		var slot_match: PokemonSlot = _find_matching_slot_by_top_card_id(player, top_card_id)
		if slot_match != null:
			return slot_match
		slot_match = _find_bench_slot_by_top_card_id(player, top_card_id)
		if slot_match != null:
			return slot_match
	return null


## 将 action 序列化为纯数据字典（去除对象引用，保留用于重放的标识信息）
func _serialize_action(action: Dictionary) -> Dictionary:
	var serialized := {}
	serialized["kind"] = action.get("kind", "")
	if action.has("attack_index"):
		serialized["attack_index"] = action.get("attack_index")
	if action.has("ability_index"):
		serialized["ability_index"] = action.get("ability_index")
	if action.has("requires_interaction"):
		serialized["requires_interaction"] = action.get("requires_interaction")
	if action.has("card") and action.get("card") is CardInstance:
		var card: CardInstance = action.get("card")
		serialized["card_instance_id"] = card.instance_id
		if card.card_data != null:
			serialized["card_name"] = card.card_data.name
	if action.has("target_slot") and action.get("target_slot") is PokemonSlot:
		var target_slot: PokemonSlot = action.get("target_slot")
		if target_slot.get_top_card() != null:
			serialized["target_slot_card_id"] = target_slot.get_top_card().instance_id
	if action.has("source_slot") and action.get("source_slot") is PokemonSlot:
		var source_slot: PokemonSlot = action.get("source_slot")
		if source_slot.get_top_card() != null:
			serialized["source_slot_card_id"] = source_slot.get_top_card().instance_id
	if action.has("bench_target") and action.get("bench_target") is PokemonSlot:
		var bench_slot: PokemonSlot = action.get("bench_target")
		if bench_slot.get_top_card() != null:
			serialized["bench_target_card_id"] = bench_slot.get_top_card().instance_id
	if action.has("energy_to_discard") and action.get("energy_to_discard") is Array:
		var discard_ids := PackedInt32Array()
		for energy_variant: Variant in action.get("energy_to_discard", []):
			if energy_variant is CardInstance:
				discard_ids.append((energy_variant as CardInstance).instance_id)
		serialized["energy_to_discard_ids"] = discard_ids
	if action.has("targets"):
		serialized["targets"] = _serialize_target_value(action.get("targets"))
	return serialized

	serialized["kind"] = action.get("kind", "")

	## 保留标量字段
	if action.has("attack_index"):
		serialized["attack_index"] = action.get("attack_index")
	if action.has("ability_index"):
		serialized["ability_index"] = action.get("ability_index")
	if action.has("requires_interaction"):
		serialized["requires_interaction"] = action.get("requires_interaction")

	## 保留卡牌 instance_id（用于在目标 gsm 中重新查找）
	if action.has("card") and action.get("card") is CardInstance:
		var card: CardInstance = action.get("card")
		serialized["card_instance_id"] = card.instance_id
		serialized["card"] = card  # 也保留原始引用便于 resolve

	## 保留槽位标识（通过顶层卡牌 id）
	if action.has("target_slot") and action.get("target_slot") is PokemonSlot:
		var slot: PokemonSlot = action.get("target_slot")
		serialized["target_slot"] = slot
		if slot.get_top_card() != null:
			serialized["target_slot_card_id"] = slot.get_top_card().instance_id

	if action.has("source_slot") and action.get("source_slot") is PokemonSlot:
		var slot: PokemonSlot = action.get("source_slot")
		serialized["source_slot"] = slot
		if slot.get_top_card() != null:
			serialized["source_slot_card_id"] = slot.get_top_card().instance_id

	if action.has("bench_target") and action.get("bench_target") is PokemonSlot:
		var slot: PokemonSlot = action.get("bench_target")
		serialized["bench_target"] = slot
		if slot.get_top_card() != null:
			serialized["bench_target_card_id"] = slot.get_top_card().instance_id

	if action.has("energy_to_discard"):
		serialized["energy_to_discard"] = action.get("energy_to_discard")

	if action.has("targets"):
		serialized["targets"] = action.get("targets")

	return serialized


func _serialize_target_value(value: Variant) -> Variant:
	if value is CardInstance:
		var card: CardInstance = value
		return {
			"__type": "card_ref",
			"instance_id": card.instance_id,
			"owner_index": card.owner_index,
		}
	if value is PokemonSlot:
		var slot: PokemonSlot = value
		var top_card: CardInstance = slot.get_top_card()
		return {
			"__type": "slot_ref",
			"top_card_id": -1 if top_card == null else top_card.instance_id,
		}
	if value is Array:
		var serialized_array: Array = []
		for item: Variant in value:
			serialized_array.append(_serialize_target_value(item))
		return serialized_array
	if value is Dictionary:
		var value_dict: Dictionary = value
		var serialized_dict := {}
		for key: Variant in value_dict.keys():
			serialized_dict[key] = _serialize_target_value(value_dict[key])
		return serialized_dict
	return value


func _mcts_debug(msg: String) -> void:
	print(msg)
	var file := FileAccess.open("user://mcts_debug.log", FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open("user://mcts_debug.log", FileAccess.WRITE)
	if file != null:
		file.seek_end()
		file.store_line(msg)
		file.close()
