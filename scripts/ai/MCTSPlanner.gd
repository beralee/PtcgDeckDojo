class_name MCTSPlanner
extends RefCounted

## MCTS 回合序列搜索器。
## 用 beam search 枚举候选回合序列，对每条序列跑 rollout 评估胜率。

const GameStateClonerScript = preload("res://scripts/ai/GameStateCloner.gd")
const RolloutSimulatorScript = preload("res://scripts/ai/RolloutSimulator.gd")
const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")
const AIHeuristicsScript = preload("res://scripts/ai/AIHeuristics.gd")
const AIFeatureExtractorScript = preload("res://scripts/ai/AIFeatureExtractor.gd")

var _cloner := GameStateClonerScript.new()
var _rollout_sim := RolloutSimulatorScript.new()
var _action_builder := AILegalActionBuilderScript.new()
var _heuristics := AIHeuristicsScript.new()
var _feature_extractor := AIFeatureExtractorScript.new()

## 默认搜索参数
const DEFAULT_BRANCH_FACTOR: int = 3
const DEFAULT_MAX_ACTIONS: int = 10
const DEFAULT_ROLLOUTS: int = 30
const DEFAULT_ROLLOUT_MAX_STEPS: int = 100
const DEFAULT_TIME_BUDGET_MS: int = 3000


func plan_turn(gsm: GameStateMachine, player_index: int, config: Dictionary = {}) -> Array:
	if gsm == null or gsm.game_state == null:
		return [{"kind": "end_turn"}]

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

	for sequence: Array in sequences:
		if Time.get_ticks_msec() - start_time > time_budget:
			break
		var win_rate: float = _evaluate_sequence(gsm, player_index, sequence, rollouts, rollout_steps)
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
	if actions.is_empty():
		var final_seq: Array = current_sequence.duplicate()
		final_seq.append({"kind": "end_turn"})
		results.append(final_seq)
		return

	## 用 heuristic 评分并取 top-K
	var scored: Array = _score_and_rank_actions(gsm, player_index, actions)
	var top_k: Array = scored.slice(0, mini(branch_factor, scored.size()))

	for entry: Dictionary in top_k:
		var action: Dictionary = entry.get("action", {})
		var kind: String = str(action.get("kind", ""))

		if kind == "end_turn":
			var final_seq: Array = current_sequence.duplicate()
			final_seq.append(action)
			results.append(final_seq)
			continue

		## 对非终结动作：克隆状态、解析引用、执行、递归
		var branch_gsm := _cloner.clone_gsm(gsm)
		var resolved_action := _resolve_action_for_gsm(action, branch_gsm, player_index)
		var executed := _try_execute_action(branch_gsm, player_index, resolved_action)
		if not executed:
			continue

		## 保存原始 action（带原始 kind 等纯数据字段）到序列
		var next_seq: Array = current_sequence.duplicate()
		next_seq.append(_serialize_action(action))

		## 如果执行后游戏阶段不再是 MAIN 或玩家切换，这条分支结束
		if branch_gsm.game_state.phase != GameState.GamePhase.MAIN \
				or branch_gsm.game_state.current_player_index != player_index:
			results.append(next_seq)
			continue

		_expand_sequences(branch_gsm, player_index, next_seq, branch_factor, remaining_depth - 1, results)


func _score_and_rank_actions(
	gsm: GameStateMachine,
	player_index: int,
	actions: Array[Dictionary]
) -> Array:
	var scored: Array = []
	for action: Dictionary in actions:
		var context := {
			"gsm": gsm,
			"game_state": gsm.game_state,
			"player_index": player_index,
			"features": _feature_extractor.build_context(gsm, player_index, action),
		}
		var score: float = _heuristics.score_action(action, context)
		scored.append({"action": action, "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	return scored


func _evaluate_sequence(
	gsm: GameStateMachine,
	player_index: int,
	sequence: Array,
	num_rollouts: int,
	max_rollout_steps: int
) -> float:
	## 克隆状态、执行整条序列、然后跑 N 次 rollout
	var sim_gsm := _cloner.clone_gsm(gsm)
	for action: Dictionary in sequence:
		var kind: String = str(action.get("kind", ""))
		if kind == "end_turn":
			if sim_gsm.game_state.phase == GameState.GamePhase.MAIN:
				sim_gsm.end_turn(player_index)
			break
		var resolved := _resolve_action_for_gsm(action, sim_gsm, player_index)
		_try_execute_action(sim_gsm, player_index, resolved)
		if sim_gsm.game_state.is_game_over():
			break

	if sim_gsm.game_state.is_game_over():
		return 1.0 if sim_gsm.game_state.winner_index == player_index else 0.0

	var wins: int = 0
	for _i in num_rollouts:
		var result: Dictionary = _rollout_sim.run_rollout(sim_gsm, player_index, max_rollout_steps)
		if int(result.get("winner_index", -1)) == player_index:
			wins += 1
	return float(wins) / float(num_rollouts) if num_rollouts > 0 else 0.0


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


## 计算序列中非 end_turn 的实际游戏动作数量
func _count_game_actions(sequence: Array) -> int:
	var count: int = 0
	for action: Dictionary in sequence:
		if str(action.get("kind", "")) != "end_turn":
			count += 1
	return count


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
	if action.has("card") and action.get("card") is CardInstance:
		var original_card: CardInstance = action.get("card")
		resolved["card"] = _find_card_in_hand(player, original_card)

	## 解析 target_slot 引用
	if action.has("target_slot") and action.get("target_slot") is PokemonSlot:
		var original_slot: PokemonSlot = action.get("target_slot")
		resolved["target_slot"] = _find_matching_slot(player, original_slot)

	## 解析 source_slot 引用（特性来源）
	if action.has("source_slot") and action.get("source_slot") is PokemonSlot:
		var original_slot: PokemonSlot = action.get("source_slot")
		resolved["source_slot"] = _find_matching_slot(player, original_slot)

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

	return resolved


## 在手牌中按 instance_id 查找对应卡牌
func _find_card_in_hand(player: PlayerState, original: CardInstance) -> CardInstance:
	if original == null:
		return null
	for card: CardInstance in player.hand:
		if card != null and card.instance_id == original.instance_id:
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


## 在卡牌数组中按 instance_id 查找
func _find_card_by_id(cards: Array[CardInstance], original: CardInstance) -> CardInstance:
	if original == null:
		return null
	for card: CardInstance in cards:
		if card != null and card.instance_id == original.instance_id:
			return card
	return null


## 将 action 序列化为纯数据字典（去除对象引用，保留用于重放的标识信息）
func _serialize_action(action: Dictionary) -> Dictionary:
	var serialized := {}
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
