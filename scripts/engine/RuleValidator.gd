class_name RuleValidator
extends RefCounted

const BenchLimit = preload("res://scripts/engine/BenchLimitHelper.gd")

const ITEM_LOCK_PREFIX := "item_lock_"
const AttackSelfLockUntilLeaveActiveEffect = preload("res://scripts/effects/pokemon_effects/AttackSelfLockUntilLeaveActive.gd")

func can_attach_energy(state: GameState, player_index: int) -> bool:
	if state.current_player_index != player_index:
		return false
	if state.phase != GameState.GamePhase.MAIN:
		return false
	return not state.energy_attached_this_turn


func can_play_supporter(state: GameState, player_index: int) -> bool:
	if state.current_player_index != player_index:
		return false
	if state.phase != GameState.GamePhase.MAIN:
		return false
	if state.supporter_used_this_turn:
		return false
	if state.turn_number == 1 and player_index == state.first_player_index:
		return false
	return true


func can_play_item(state: GameState, player_index: int) -> bool:
	if state.current_player_index != player_index:
		return false
	if state.phase != GameState.GamePhase.MAIN:
		return false
	return int(state.shared_turn_flags.get("%s%d" % [ITEM_LOCK_PREFIX, player_index], -1)) != state.turn_number


func can_play_stadium(state: GameState, player_index: int, card: CardInstance) -> bool:
	if state.current_player_index != player_index:
		return false
	if state.phase != GameState.GamePhase.MAIN:
		return false
	if state.stadium_played_this_turn:
		return false
	if state.stadium_card != null and state.stadium_card.card_data.name == card.card_data.name:
		return false
	return true


func can_evolve(
	state: GameState,
	player_index: int,
	slot: PokemonSlot,
	evolution: CardInstance,
	effect_processor: EffectProcessor = null
) -> bool:
	if state.current_player_index != player_index:
		return false
	if state.phase != GameState.GamePhase.MAIN:
		return false
	if slot == null or _is_effectively_knocked_out(slot, state, effect_processor):
		return false
	if state.is_first_turn_for_player(player_index):
		return false
	if slot.turn_played == state.turn_number:
		return false
	if slot.turn_evolved == state.turn_number:
		return false
	if not evolution.card_data.is_pokemon():
		return false
	var top_name: String = slot.get_pokemon_name()
	var evolves_from: String = evolution.card_data.evolves_from
	if evolves_from == "" or evolves_from != top_name:
		return false
	return true


func can_retreat(
	state: GameState,
	player_index: int,
	effect_processor: EffectProcessor = null
) -> bool:
	if state.current_player_index != player_index:
		return false
	if state.phase != GameState.GamePhase.MAIN:
		return false
	if state.retreat_used_this_turn:
		return false
	var player: PlayerState = state.players[player_index]
	if player.active_pokemon == null:
		return false
	if _is_effectively_knocked_out(player.active_pokemon, state, effect_processor):
		return false
	if player.active_pokemon.status_conditions.get("asleep", false):
		return false
	if player.active_pokemon.status_conditions.get("paralyzed", false):
		return false
	if effect_processor != null:
		var opponent_active: PokemonSlot = state.players[1 - player_index].active_pokemon
		if opponent_active != null and not effect_processor.is_ability_disabled(opponent_active, state):
			var ability_count: int = opponent_active.get_abilities().size()
			for ability_index: int in ability_count:
				var effect: BaseEffect = effect_processor.get_ability_effect(opponent_active, ability_index, state)
				if effect != null and effect.has_method("prevents_opponent_retreat"):
					if bool(effect.call("prevents_opponent_retreat", opponent_active, player_index, state)):
						return false
	for effect_data: Dictionary in player.active_pokemon.effects:
		if effect_data.get("type", "") == "retreat_lock" and int(effect_data.get("turn", -999)) == state.turn_number - 1:
			return false
	var has_live_bench: bool = false
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot != null and not _is_effectively_knocked_out(bench_slot, state, effect_processor):
			has_live_bench = true
			break
	if not has_live_bench:
		return false
	return true


func has_enough_energy_to_retreat(
	slot: PokemonSlot,
	energy_to_discard: Array[CardInstance],
	required_cost: int = -1,
	effect_processor: EffectProcessor = null,
	state: GameState = null
) -> bool:
	var cost: int = required_cost if required_cost >= 0 else slot.get_retreat_cost()
	var provided: int = 0
	for energy: CardInstance in energy_to_discard:
		if effect_processor != null:
			provided += effect_processor.get_energy_colorless_count(energy, state)
		else:
			provided += 1
	return provided >= cost


func can_use_attack(
	state: GameState,
	player_index: int,
	attack_index: int,
	effect_processor: EffectProcessor = null
) -> bool:
	return get_attack_unusable_reason(state, player_index, attack_index, effect_processor) == ""


func get_attack_unusable_reason(
	state: GameState,
	player_index: int,
	attack_index: int,
	effect_processor: EffectProcessor = null
) -> String:
	if state.current_player_index != player_index:
		return "不是你的回合"
	if state.phase != GameState.GamePhase.MAIN:
		return "当前不在主要阶段"

	var player: PlayerState = state.players[player_index]
	if player.active_pokemon == null:
		return "当前没有战斗宝可梦"
	var active: PokemonSlot = player.active_pokemon
	if _is_effectively_knocked_out(active, state, effect_processor):
		return "当前战斗宝可梦已昏厥"
	var opponent_index: int = 1 - player_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return "Opponent has no Active Pokemon"
	if state.players[opponent_index].active_pokemon == null:
		return "Opponent has no Active Pokemon"

	if active.status_conditions.get("asleep", false):
		return "睡眠状态下不能攻击"
	if active.status_conditions.get("paralyzed", false):
		return "麻痹状态下不能攻击"

	var card_data: CardData = active.get_card_data()
	if attack_index < 0 or attack_index >= card_data.attacks.size():
		return "招式索引无效"
	var attack: Dictionary = card_data.attacks[attack_index]
	var special_gate_reason := _fails_special_attack_usage_gate(state, player_index, active, attack_index)
	if special_gate_reason != "":
		return special_gate_reason

	if (
		state.turn_number == 1
		and player_index == state.first_player_index
		and not _allows_first_player_attack_on_first_turn(attack)
	):
		return "先攻玩家首回合不能攻击"

	if attack.get("is_vstar_power", false) and state.vstar_power_used[player_index]:
		return "本局已使用过 VSTAR 力量"

	for effect_data: Dictionary in active.effects:
		if effect_data.get("type", "") == AttackSelfLockUntilLeaveActiveEffect.EFFECT_TYPE:
			if str(effect_data.get("attack_name", "")) == str(attack.get("name", "")):
				return "该招式在离开战斗场前无法再次使用"
		if effect_data.get("type", "") == "attack_lock" and int(effect_data.get("turn", -999)) == state.turn_number - 2:
			if str(effect_data.get("attack_name", "")) == str(attack.get("name", "")):
				return "该招式下回合无法再次使用"
		if effect_data.get("type", "") == "defender_attack_lock" and int(effect_data.get("turn", -999)) == state.turn_number - 1:
			var locked_attack_name: String = str(effect_data.get("attack_name", ""))
			if locked_attack_name != "" and locked_attack_name != str(attack.get("name", "")):
				continue
			return "受到上回合效果影响，无法攻击"

	var cost: String = CardData.normalize_attack_cost(attack.get("cost", ""))
	if effect_processor != null:
		var any_cost_modifier: int = effect_processor.get_attack_any_cost_modifier(active, attack, state)
		var colorless_modifier: int = effect_processor.get_attack_colorless_cost_modifier(active, attack, state)
		if colorless_modifier < 0:
			cost = _remove_cost_symbols(cost, "C", -colorless_modifier)
		elif colorless_modifier > 0:
			for _i: int in colorless_modifier:
				cost += "C"
		# 任意属性减费：枚举所有可能的移除组合，只要有一种满足能量即可
		if any_cost_modifier < 0:
			var candidates: Array[String] = _get_all_any_cost_removals(cost, -any_cost_modifier)
			for candidate: String in candidates:
				if has_enough_energy(active, candidate, effect_processor, state):
					return ""
			# 没有任何组合能满足
			return "能量不足，当前无法支付 [%s]" % cost

	if not has_enough_energy(active, cost, effect_processor, state):
		return "能量不足，当前无法支付 [%s]" % cost
	return ""


func _allows_first_player_attack_on_first_turn(attack: Dictionary) -> bool:
	var attack_name: String = str(attack.get("name", ""))
	if attack_name == "快速充能":
		return true
	var attack_text: String = str(attack.get("text", ""))
	return attack_text.contains("即使是先攻玩家的最初回合也可以使用")


func _fails_special_attack_usage_gate(
	state: GameState,
	player_index: int,
	active: PokemonSlot,
	attack_index: int
) -> String:
	var card_data: CardData = active.get_card_data()
	if card_data == null:
		return ""
	match card_data.effect_id:
		"11e3c629e34562a7061a05c483eb5718":
			if attack_index == 1 and state.players[player_index].lost_zone.size() < 10:
				return "自己的放逐区没有达到 10 张，无法使用这个招式"
	return ""


func has_enough_energy(
	slot: PokemonSlot,
	cost: String,
	effect_processor: EffectProcessor = null,
	state: GameState = null
) -> bool:
	cost = CardData.normalize_attack_cost(cost)
	if cost == "":
		return true

	var required: Dictionary = {}
	for c: String in cost:
		required[c] = required.get(c, 0) + 1

	var available: Dictionary = {}
	var colorless_pool: int = 0
	var any_pool: int = 0
	for energy: CardInstance in slot.attached_energy:
		var e_type: String = energy.card_data.energy_provides
		var energy_count: int = 1
		if effect_processor != null:
			e_type = effect_processor.get_energy_type(energy, state)
			energy_count = effect_processor.get_energy_colorless_count(energy, state)
		if e_type == "":
			e_type = "C"
		if e_type == "ANY":
			any_pool += energy_count
			continue
		if e_type == "C":
			colorless_pool += energy_count
			continue
		available[e_type] = available.get(e_type, 0) + energy_count

	var colorless_needed: int = required.get("C", 0)
	var remaining_energy: int = colorless_pool

	# 遍历所有需求侧的属性能量类型，检查供给是否足够
	for key: String in required.keys():
		if key == "C":
			continue
		var needed: int = int(required[key])
		var owned: int = int(available.get(key, 0))
		if owned < needed:
			var missing: int = needed - owned
			if any_pool < missing:
				return false
			any_pool -= missing
		remaining_energy += maxi(0, owned - needed)

	# 已满足需求的多余属性能量也可用于支付无色消耗
	for key: String in available.keys():
		if not required.has(key):
			remaining_energy += int(available[key])

	remaining_energy += any_pool
	return remaining_energy >= colorless_needed


func can_play_basic_to_bench(state: GameState, player_index: int, card: CardInstance) -> bool:
	if state.current_player_index != player_index:
		return false
	if state.phase != GameState.GamePhase.MAIN:
		return false
	if not card.card_data.is_basic_pokemon():
		return false
	var player: PlayerState = state.players[player_index]
	return not BenchLimit.is_bench_full(state, player)


func can_attach_tool(
	state: GameState,
	player_index: int,
	slot: PokemonSlot,
	effect_processor: EffectProcessor = null
) -> bool:
	if state.current_player_index != player_index:
		return false
	if state.phase != GameState.GamePhase.MAIN:
		return false
	if slot == null or _is_effectively_knocked_out(slot, state, effect_processor):
		return false
	return slot.attached_tool == null


func _is_effectively_knocked_out(
	slot: PokemonSlot,
	state: GameState,
	effect_processor: EffectProcessor = null
) -> bool:
	if slot == null:
		return false
	if effect_processor != null:
		return effect_processor.is_effectively_knocked_out(slot, state)
	return slot.is_knocked_out()


func has_basic_pokemon_in_hand(player: PlayerState) -> bool:
	return player.has_basic_pokemon_in_hand()


func validate_energy_on_pokemon(slot: PokemonSlot, energy_list: Array[CardInstance]) -> bool:
	for energy: CardInstance in energy_list:
		if not energy in slot.attached_energy:
			return false
	return true


func _remove_cost_symbols(cost: String, symbol: String, count: int) -> String:
	var remaining: int = count
	var result := ""
	for cost_symbol: String in cost:
		if remaining > 0 and cost_symbol == symbol:
			remaining -= 1
			continue
		result += cost_symbol
	return result


func _remove_any_cost_symbols(cost: String, count: int) -> String:
	## 向后兼容：返回默认移除结果（优先移除非C）。
	## 在费用校验中应优先使用 _get_all_any_cost_removals 枚举所有可能。
	var remaining: int = count
	var parts: Array[String] = []
	for symbol: String in cost:
		parts.append(symbol)
	for i: int in parts.size():
		if remaining <= 0:
			break
		if parts[i] != "C":
			parts[i] = ""
			remaining -= 1
	for i: int in parts.size():
		if remaining <= 0:
			break
		if parts[i] == "C":
			parts[i] = ""
			remaining -= 1
	return "".join(parts)


func _get_all_any_cost_removals(cost: String, count: int) -> Array[String]:
	## 枚举从费用字符串中移除 count 个任意字符的所有组合。
	## 例如 cost="RP", count=1 → ["P", "R"]
	if count <= 0 or cost == "":
		return [cost]
	if count >= cost.length():
		return [""]
	var results: Array[String] = []
	_enumerate_removals(cost, count, 0, [], results)
	# 去重
	var seen: Dictionary = {}
	var unique: Array[String] = []
	for r: String in results:
		if not seen.has(r):
			seen[r] = true
			unique.append(r)
	return unique


func _enumerate_removals(cost: String, remaining: int, start: int, removed: Array, results: Array[String]) -> void:
	if remaining == 0:
		var parts: String = ""
		for i: int in cost.length():
			if i not in removed:
				parts += cost[i]
		results.append(parts)
		return
	for i: int in range(start, cost.length()):
		removed.append(i)
		_enumerate_removals(cost, remaining - 1, i + 1, removed, results)
		removed.pop_back()
