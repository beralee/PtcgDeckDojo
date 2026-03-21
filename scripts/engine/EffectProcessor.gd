class_name EffectProcessor
extends RefCounted

var _effect_registry: Dictionary = {}
var _attack_effect_registry: Dictionary = {}
var _registered_pokemon_effect_ids: Dictionary = {}
var coin_flipper: CoinFlipper = null


func _init(flipper: CoinFlipper = null) -> void:
	coin_flipper = flipper if flipper != null else CoinFlipper.new()
	EffectRegistry.register_all(self)


func register_effect(effect_id: String, effect: BaseEffect) -> void:
	_effect_registry[effect_id] = effect


func register_attack_effect(effect_id: String, effect: BaseEffect) -> void:
	if not _attack_effect_registry.has(effect_id):
		_attack_effect_registry[effect_id] = []
	_attack_effect_registry[effect_id].append(effect)


func register_effects(effects: Dictionary) -> void:
	for eid: String in effects.keys():
		register_effect(eid, effects[eid])


func register_attack_effects(effects: Dictionary) -> void:
	for eid: String in effects.keys():
		var effect_list: Array = effects[eid]
		for effect: BaseEffect in effect_list:
			register_attack_effect(eid, effect)


func has_effect(effect_id: String) -> bool:
	return _effect_registry.has(effect_id)


func has_attack_effect(effect_id: String) -> bool:
	return _attack_effect_registry.has(effect_id)


func get_registered_count() -> int:
	return _effect_registry.size() + _attack_effect_registry.size()


func get_effect(effect_id: String) -> BaseEffect:
	return _effect_registry.get(effect_id, null)


func register_pokemon_card(card: CardData) -> void:
	if card == null or not card.is_pokemon():
		return
	var effect_id: String = card.effect_id
	if effect_id == "":
		return
	if _registered_pokemon_effect_ids.has(effect_id):
		return
	EffectRegistry.register_pokemon_card(self, card)
	_registered_pokemon_effect_ids[effect_id] = true


func get_attack_effects_for_slot(attacker: PokemonSlot, _attack_index: int = 0) -> Array[BaseEffect]:
	var result: Array[BaseEffect] = []
	if attacker == null or attacker.get_top_card() == null:
		return result
	var effect_id: String = attacker.get_card_data().effect_id
	if not _attack_effect_registry.has(effect_id):
		return result
	for effect: BaseEffect in _attack_effect_registry[effect_id]:
		result.append(effect)
	return result


func execute_card_effect(card: CardInstance, targets: Array, state: GameState) -> bool:
	if card == null or card.card_data == null:
		return false
	var effect_id: String = card.card_data.effect_id
	if card.card_data.card_type == "Special Energy" and is_special_energy_suppressed(card, state):
		return true
	if not _effect_registry.has(effect_id):
		return true
	var effect: BaseEffect = _effect_registry[effect_id]
	if not effect.can_execute(card, state):
		return false
	effect.execute(card, targets, state)
	return true


func execute_attack_effect(
	attacker: PokemonSlot,
	attack_index: int,
	defender: PokemonSlot,
	state: GameState,
	targets: Array = []
) -> void:
	if attacker == null or attacker.get_top_card() == null:
		return
	var card_data: CardData = attacker.get_card_data()
	if attack_index < 0 or attack_index >= card_data.attacks.size():
		return
	var effect_id: String = card_data.effect_id

	if _effect_registry.has(effect_id):
		var card_effect: BaseEffect = _effect_registry[effect_id]
		card_effect.set_attack_interaction_context(targets)
		card_effect.execute_attack(attacker, defender, attack_index, state)
		card_effect.clear_attack_interaction_context()

	if _attack_effect_registry.has(effect_id):
		for effect: BaseEffect in _attack_effect_registry[effect_id]:
			if effect.has_method("applies_to_attack_index") and not bool(effect.call("applies_to_attack_index", attack_index)):
				continue
			effect.set_attack_interaction_context(targets)
			effect.execute_attack(attacker, defender, attack_index, state)
			effect.clear_attack_interaction_context()


## 使用指定的 effect_id 执行攻击效果（用于复制招式场景，如巨龙无双）
## 与 execute_attack_effect 的区别：允许 effect_id 与 attacker 上的卡牌不同
func execute_attack_effect_by_id(
	effect_id: String,
	attack_index: int,
	attacker: PokemonSlot,
	defender: PokemonSlot,
	state: GameState,
	targets: Array = [],
	exclude_effect_type: Variant = null
) -> void:
	if _effect_registry.has(effect_id):
		var card_effect: BaseEffect = _effect_registry[effect_id]
		if exclude_effect_type == null or not is_instance_of(card_effect, exclude_effect_type):
			card_effect.set_attack_interaction_context(targets)
			card_effect.execute_attack(attacker, defender, attack_index, state)
			card_effect.clear_attack_interaction_context()

	if _attack_effect_registry.has(effect_id):
		for effect: BaseEffect in _attack_effect_registry[effect_id]:
			if exclude_effect_type != null and is_instance_of(effect, exclude_effect_type):
				continue
			if effect.has_method("applies_to_attack_index") and not bool(effect.call("applies_to_attack_index", attack_index)):
				continue
			effect.set_attack_interaction_context(targets)
			effect.execute_attack(attacker, defender, attack_index, state)
			effect.clear_attack_interaction_context()


## 根据 effect_id 收集被复制招式的交互步骤（用于巨龙无双等复制招式场景）
func get_attack_interaction_steps_by_id(
	effect_id: String,
	attack_index: int,
	card: CardInstance,
	attack: Dictionary,
	state: GameState,
	exclude_effect_type: Variant = null
) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	if _attack_effect_registry.has(effect_id):
		# 注入 _override_attack_index 以便效果在复制场景中能正确解析攻击索引
		var augmented_attack: Dictionary = attack.duplicate()
		augmented_attack["_override_attack_index"] = attack_index
		for effect: BaseEffect in _attack_effect_registry[effect_id]:
			if exclude_effect_type != null and is_instance_of(effect, exclude_effect_type):
				continue
			if effect.has_method("applies_to_attack_index") and not bool(effect.call("applies_to_attack_index", attack_index)):
				continue
			steps.append_array(effect.get_attack_interaction_steps(card, augmented_attack, state))
	return steps


func execute_ability_effect(
	pokemon: PokemonSlot,
	ability_index: int,
	targets: Array,
	state: GameState
) -> bool:
	var effect: BaseEffect = get_ability_effect(pokemon, ability_index, state)
	if effect == null:
		return false
	if not can_use_ability(pokemon, state, ability_index):
		return false
	effect.execute_ability(pokemon, ability_index, targets, state)
	return true


func can_use_ability(pokemon: PokemonSlot, state: GameState, ability_index: int = 0) -> bool:
	if pokemon == null or pokemon.get_top_card() == null:
		return false
	if is_ability_disabled(pokemon, state):
		return false
	if ability_index < 0:
		return false
	var effect: BaseEffect = get_ability_effect(pokemon, ability_index, state)
	if effect == null or not effect.has_method("can_use_ability"):
		return false
	return bool(effect.call("can_use_ability", pokemon, state))


func get_ability_effect(
	pokemon: PokemonSlot,
	ability_index: int = 0,
	state: GameState = null
) -> BaseEffect:
	if pokemon == null or pokemon.get_top_card() == null:
		return null
	var card_data: CardData = pokemon.get_card_data()
	if card_data == null or ability_index < 0:
		return null

	var native_count: int = card_data.abilities.size()
	if ability_index < native_count:
		return _effect_registry.get(card_data.effect_id, null)
	if state != null and ability_index == native_count:
		return _get_tool_granted_ability_effect(pokemon, state)
	return null


func get_ability_source_card(
	pokemon: PokemonSlot,
	ability_index: int = 0,
	state: GameState = null
) -> CardInstance:
	if pokemon == null or pokemon.get_top_card() == null:
		return null
	var card_data: CardData = pokemon.get_card_data()
	if ability_index < card_data.abilities.size():
		return pokemon.get_top_card()
	if state != null and ability_index == card_data.abilities.size():
		return pokemon.attached_tool
	return null


func get_ability_name(
	pokemon: PokemonSlot,
	ability_index: int = 0,
	state: GameState = null
) -> String:
	if pokemon == null or pokemon.get_top_card() == null:
		return ""
	var card_data: CardData = pokemon.get_card_data()
	if ability_index >= 0 and ability_index < card_data.abilities.size():
		return str(card_data.abilities[ability_index].get("name", ""))
	var effect: BaseEffect = get_ability_effect(pokemon, ability_index, state)
	if effect != null and effect.has_method("get_ability_name"):
		return str(effect.call("get_ability_name"))
	return ""


func get_granted_abilities(pokemon: PokemonSlot, state: GameState) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if pokemon == null or pokemon.get_top_card() == null:
		return entries
	var card_data: CardData = pokemon.get_card_data()
	var native_count: int = card_data.abilities.size()
	var effect: BaseEffect = _get_tool_granted_ability_effect(pokemon, state)
	if effect == null:
		return entries
	entries.append({
		"ability_index": native_count,
		"name": get_ability_name(pokemon, native_count, state),
		"source": "tool",
		"source_card": pokemon.attached_tool,
		"enabled": can_use_ability(pokemon, state, native_count),
	})
	return entries


func get_granted_attacks(pokemon: PokemonSlot, state: GameState) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if pokemon == null or pokemon.attached_tool == null:
		return entries
	if is_tool_effect_suppressed(pokemon, state):
		return entries
	var effect: BaseEffect = get_effect(pokemon.attached_tool.card_data.effect_id)
	if effect == null or not effect.has_method("get_granted_attacks"):
		return entries
	var raw_entries: Variant = effect.call("get_granted_attacks", pokemon, state)
	if raw_entries is Array:
		for entry: Variant in raw_entries:
			if entry is Dictionary:
				entries.append(entry)
	return entries


func get_granted_attack_interaction_steps(
	pokemon: PokemonSlot,
	granted_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if pokemon == null or pokemon.attached_tool == null:
		return []
	if is_tool_effect_suppressed(pokemon, state):
		return []
	var effect: BaseEffect = get_effect(pokemon.attached_tool.card_data.effect_id)
	if effect == null or not effect.has_method("get_granted_attack_interaction_steps"):
		return []
	var raw_steps: Variant = effect.call("get_granted_attack_interaction_steps", pokemon, granted_attack, state)
	if raw_steps is Array:
		return raw_steps
	return []


func execute_granted_attack(
	attacker: PokemonSlot,
	granted_attack: Dictionary,
	defender: PokemonSlot,
	state: GameState,
	targets: Array = []
) -> bool:
	if attacker == null or attacker.attached_tool == null:
		return false
	if is_tool_effect_suppressed(attacker, state):
		return false
	var effect: BaseEffect = get_effect(attacker.attached_tool.card_data.effect_id)
	if effect == null or not effect.has_method("execute_granted_attack"):
		return false
	if effect.has_method("set_attack_interaction_context"):
		effect.set_attack_interaction_context(targets)
	effect.call("execute_granted_attack", attacker, granted_attack, state, targets)
	if effect.has_method("clear_attack_interaction_context"):
		effect.clear_attack_interaction_context()
	return true


func _get_tool_granted_ability_effect(pokemon: PokemonSlot, state: GameState) -> BaseEffect:
	if pokemon == null or pokemon.attached_tool == null:
		return null
	if is_tool_effect_suppressed(pokemon, state):
		return null
	var tool_eid: String = pokemon.attached_tool.card_data.effect_id
	if not _effect_registry.has(tool_eid):
		return null
	var effect: BaseEffect = _effect_registry[tool_eid]
	if effect is AbilityVSTARSearch and AbilityVSTARSearch.has_vstar_search(pokemon, state):
		return effect
	return null


func get_attacker_modifier(attacker: PokemonSlot, state: GameState) -> int:
	var total: int = 0
	var pi: int = _get_owner_index(attacker)
	if pi == -1:
		return 0
	total += _get_ability_attack_modifier(attacker, state, pi)
	total += _get_tool_attack_modifier(attacker, state)
	total += _get_stadium_attack_modifier(attacker, state)
	total += _get_energy_attack_modifier(attacker, state)
	return total


func get_defender_modifier(defender: PokemonSlot, state: GameState, attacker: PokemonSlot = null) -> int:
	var total: int = 0
	var pi: int = _get_owner_index(defender)
	if pi == -1:
		return 0
	total += _get_ability_defense_modifier(defender, state, pi)
	total += _get_tool_defense_modifier(defender, state)
	total += _get_stadium_defense_modifier(defender, state)
	total += _get_energy_defense_modifier(defender, attacker, state)
	for effect_data: Dictionary in defender.effects:
		if effect_data.get("type", "") == "reduce_damage_next_turn" and int(effect_data.get("turn", -999)) == state.turn_number - 1:
			total -= int(effect_data.get("amount", 0))
	return total


func get_attack_damage_modifier(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack: Dictionary,
	state: GameState,
	targets: Array = []
) -> int:
	if attacker == null or attacker.get_top_card() == null:
		return 0
	var effect_id: String = attacker.get_card_data().effect_id
	if not _attack_effect_registry.has(effect_id):
		return 0
	var total: int = 0
	for effect: BaseEffect in _attack_effect_registry[effect_id]:
		if effect.has_method("applies_to_attack_index"):
			var attack_index := _resolve_attack_index(attacker, _attack)
			if not bool(effect.call("applies_to_attack_index", attack_index)):
				continue
		if effect.has_method("get_damage_bonus"):
			effect.set_attack_interaction_context(targets)
			total += int(effect.call("get_damage_bonus", attacker, state))
			effect.clear_attack_interaction_context()
	return total


func attack_ignores_weakness_and_resistance(attacker: PokemonSlot, attack_index: int, state: GameState) -> bool:
	if attacker == null or attacker.get_top_card() == null:
		return false
	var effect_id: String = attacker.get_card_data().effect_id
	if not _attack_effect_registry.has(effect_id):
		return false
	for effect: BaseEffect in _attack_effect_registry[effect_id]:
		if effect.has_method("applies_to_attack_index") and not bool(effect.call("applies_to_attack_index", attack_index)):
			continue
		if effect.has_method("ignores_weakness_and_resistance") and bool(effect.call("ignores_weakness_and_resistance", attacker, state, attack_index)):
			return true
	return false


func attack_ignores_defender_effects(attacker: PokemonSlot, attack_index: int, state: GameState) -> bool:
	if attacker == null or attacker.get_top_card() == null:
		return false
	var effect_id: String = attacker.get_card_data().effect_id
	if not _attack_effect_registry.has(effect_id):
		return false
	for effect: BaseEffect in _attack_effect_registry[effect_id]:
		if effect.has_method("applies_to_attack_index") and not bool(effect.call("applies_to_attack_index", attack_index)):
			continue
		if effect.has_method("ignores_defender_effects") and bool(effect.call("ignores_defender_effects", attacker, state, attack_index)):
			return true
	return false


func _resolve_attack_index(attacker: PokemonSlot, attack: Dictionary) -> int:
	if attacker == null or attacker.get_card_data() == null:
		return -1
	for i: int in attacker.get_card_data().attacks.size():
		if attacker.get_card_data().attacks[i] == attack:
			return i
	return -1


func get_attack_any_cost_modifier(attacker: PokemonSlot, attack: Dictionary, state: GameState) -> int:
	var total: int = 0
	if attacker == null or attacker.get_top_card() == null:
		return 0
	var effect_id: String = attacker.get_card_data().effect_id
	if _effect_registry.has(effect_id):
		var native_effect: BaseEffect = _effect_registry[effect_id]
		if native_effect.has_method("get_attack_any_cost_modifier"):
			total += int(native_effect.call("get_attack_any_cost_modifier", attacker, attack, state))
	if attacker.attached_tool != null and not is_tool_effect_suppressed(attacker, state):
		var tool_effect: BaseEffect = get_effect(attacker.attached_tool.card_data.effect_id)
		if tool_effect != null and tool_effect.has_method("get_attack_any_cost_modifier"):
			total += int(tool_effect.call("get_attack_any_cost_modifier", attacker, attack, state))
	if state.stadium_card != null:
		var stadium_effect: BaseEffect = get_effect(state.stadium_card.card_data.effect_id)
		if stadium_effect != null and stadium_effect.has_method("get_attack_any_cost_modifier"):
			total += int(stadium_effect.call("get_attack_any_cost_modifier", attacker, attack, state))
	return total


func get_attack_colorless_cost_modifier(attacker: PokemonSlot, attack: Dictionary, state: GameState) -> int:
	var total: int = 0
	if attacker == null or attacker.get_top_card() == null:
		return 0
	var effect_id: String = attacker.get_card_data().effect_id
	if _effect_registry.has(effect_id):
		var native_effect: BaseEffect = _effect_registry[effect_id]
		if native_effect.has_method("get_attack_colorless_cost_modifier"):
			total += int(native_effect.call("get_attack_colorless_cost_modifier", attacker, attack, state))
	if attacker.attached_tool != null and not is_tool_effect_suppressed(attacker, state):
		var tool_effect: BaseEffect = get_effect(attacker.attached_tool.card_data.effect_id)
		if tool_effect != null and tool_effect.has_method("get_attack_colorless_cost_modifier"):
			total += int(tool_effect.call("get_attack_colorless_cost_modifier", attacker, attack, state))
	if state.stadium_card != null:
		var stadium_effect: BaseEffect = get_effect(state.stadium_card.card_data.effect_id)
		if stadium_effect != null and stadium_effect.has_method("get_attack_colorless_cost_modifier"):
			total += int(stadium_effect.call("get_attack_colorless_cost_modifier", attacker, attack, state))
	return total


func get_retreat_cost_modifier(slot: PokemonSlot, state: GameState) -> int:
	var total: int = 0
	if slot.attached_tool != null and not is_tool_effect_suppressed(slot, state):
		var tool_effect: BaseEffect = get_effect(slot.attached_tool.card_data.effect_id)
		if tool_effect is EffectToolRetreatModifier:
			total += (tool_effect as EffectToolRetreatModifier).retreat_modifier
		elif tool_effect is EffectToolFutureBoost:
			total += (tool_effect as EffectToolFutureBoost).get_retreat_modifier(slot)
		elif tool_effect is EffectToolRescueBoard:
			total += (tool_effect as EffectToolRescueBoard).get_retreat_modifier(slot)
		elif tool_effect != null and tool_effect.has_method("get_retreat_cost_modifier"):
			total += int(tool_effect.call("get_retreat_cost_modifier", slot, state))
	if state.stadium_card != null:
		var stadium_effect: BaseEffect = get_effect(state.stadium_card.card_data.effect_id)
		if stadium_effect is EffectStadiumRetreatModifier:
			var stadium_mod: EffectStadiumRetreatModifier = stadium_effect as EffectStadiumRetreatModifier
			if stadium_mod.matches_pokemon(slot):
				total += stadium_mod.retreat_modifier
		elif stadium_effect != null and stadium_effect.has_method("get_retreat_cost_modifier"):
			total += int(stadium_effect.call("get_retreat_cost_modifier", slot, state))
	for energy: CardInstance in slot.attached_energy:
		if is_special_energy_suppressed(energy, state):
			continue
		var energy_effect: BaseEffect = get_effect(energy.card_data.effect_id)
		if energy_effect is EffectSpecialEnergyModifier:
			total += (energy_effect as EffectSpecialEnergyModifier).retreat_modifier
		elif energy_effect != null and energy_effect.has_method("get_retreat_cost_modifier"):
			total += int(energy_effect.call("get_retreat_cost_modifier", slot, state))
	return total


func get_effective_retreat_cost(slot: PokemonSlot, state: GameState) -> int:
	return maxi(0, slot.get_retreat_cost() + get_retreat_cost_modifier(slot, state))


func get_hp_modifier(slot: PokemonSlot, state: GameState = null) -> int:
	var total: int = 0
	if slot.attached_tool != null and not is_tool_effect_suppressed(slot, state):
		var tool_effect: BaseEffect = get_effect(slot.attached_tool.card_data.effect_id)
		if tool_effect != null and tool_effect.has_method("get_hp_modifier"):
			total += int(tool_effect.call("get_hp_modifier", slot, state))
	if state != null and state.stadium_card != null:
		var stadium_effect: BaseEffect = get_effect(state.stadium_card.card_data.effect_id)
		if stadium_effect != null and stadium_effect.has_method("get_hp_modifier"):
			total += int(stadium_effect.call("get_hp_modifier", slot, state))
	return total


func get_effective_max_hp(slot: PokemonSlot, state: GameState = null) -> int:
	return slot.get_max_hp() + get_hp_modifier(slot, state)


func get_effective_remaining_hp(slot: PokemonSlot, state: GameState = null) -> int:
	return maxi(0, get_effective_max_hp(slot, state) - slot.damage_counters)


func is_effectively_knocked_out(slot: PokemonSlot, state: GameState = null) -> bool:
	return get_effective_max_hp(slot, state) > 0 and get_effective_remaining_hp(slot, state) <= 0


func get_energy_colorless_count(energy: CardInstance, state: GameState = null) -> int:
	if energy == null or energy.card_data == null:
		return 0
	if state != null and is_special_energy_suppressed(energy, state):
		return 1
	var effect: BaseEffect = get_effect(energy.card_data.effect_id)
	if effect is EffectDoubleColorless:
		return (effect as EffectDoubleColorless).provides_count
	if effect is EffectSpecialEnergyModifier:
		return (effect as EffectSpecialEnergyModifier).energy_count
	if effect != null and effect.has_method("get_energy_count"):
		return int(effect.call("get_energy_count"))
	return 1


func get_energy_type(energy: CardInstance, state: GameState = null) -> String:
	if energy == null or energy.card_data == null:
		return "C"
	if state != null and is_special_energy_suppressed(energy, state):
		return "C"
	var effect: BaseEffect = get_effect(energy.card_data.effect_id)
	if effect != null and effect.has_method("provides_any_type") and bool(effect.call("provides_any_type")):
		return "ANY"
	if effect is EffectSpecialEnergyModifier:
		return (effect as EffectSpecialEnergyModifier).energy_type_provides
	if effect != null and effect.has_method("get_energy_type"):
		return str(effect.call("get_energy_type"))
	var provides: String = energy.card_data.energy_provides
	return provides if provides != "" else "C"


func is_ability_disabled(slot: PokemonSlot, state: GameState = null) -> bool:
	if slot == null:
		return false
	if state != null:
		if AbilityBasicLock.is_locked_by_basic_lock(slot, state):
			return true
		if AbilityDisableOpponentAbility.is_locked_by_dark_wing(slot, state):
			return true
	if slot.attached_tool != null and not is_tool_effect_suppressed(slot, state):
		var tool_effect: BaseEffect = get_effect(slot.attached_tool.card_data.effect_id)
		if tool_effect != null and tool_effect.has_method("disables_ability"):
			return bool(tool_effect.call("disables_ability", slot, state))
	return false


func is_special_energy_suppressed(energy: CardInstance, state: GameState) -> bool:
	if energy == null or energy.card_data == null or state == null:
		return false
	if energy.card_data.card_type != "Special Energy":
		return false
	if state.stadium_card == null:
		return false
	var stadium_effect: BaseEffect = get_effect(state.stadium_card.card_data.effect_id)
	return stadium_effect != null and stadium_effect.has_method("suppresses_special_energy_effects") and bool(stadium_effect.call("suppresses_special_energy_effects"))


func is_tool_effect_suppressed(slot: PokemonSlot, state: GameState) -> bool:
	if slot == null or slot.attached_tool == null or state == null:
		return false
	if state.stadium_card == null:
		return false
	var stadium_effect: BaseEffect = get_effect(state.stadium_card.card_data.effect_id)
	return stadium_effect != null and stadium_effect.has_method("suppresses_tool_effects") and bool(stadium_effect.call("suppresses_tool_effects"))


func get_knockout_prize_modifier(slot: PokemonSlot, state: GameState) -> int:
	if slot == null:
		return 0
	var total: int = 0
	for energy: CardInstance in slot.attached_energy:
		if is_special_energy_suppressed(energy, state):
			continue
		var effect: BaseEffect = get_effect(energy.card_data.effect_id)
		if effect != null and effect.has_method("get_knockout_prize_modifier"):
			total += int(effect.call("get_knockout_prize_modifier", slot, state))
	return total


func mark_knockout_prize_modifier_consumed(slot: PokemonSlot, state: GameState) -> void:
	if slot == null:
		return
	for energy: CardInstance in slot.attached_energy:
		if is_special_energy_suppressed(energy, state):
			continue
		var effect: BaseEffect = get_effect(energy.card_data.effect_id)
		if effect != null and effect.has_method("mark_knockout_prize_modifier_consumed"):
			effect.call("mark_knockout_prize_modifier_consumed", slot, state)


## 检查宝可梦是否附有薄雾能量（免疫对手招式效果）
func has_mist_energy_protection(slot: PokemonSlot, state: GameState) -> bool:
	if slot == null:
		return false
	for energy: CardInstance in slot.attached_energy:
		if is_special_energy_suppressed(energy, state):
			continue
		if energy.card_data.effect_id == "fb0948c721db1f31767aa6cf0c2ea692":
			return true
	return false


func is_damage_prevented_by_defender_ability(attacker: PokemonSlot, defender: PokemonSlot, state: GameState) -> bool:
	if attacker == null or defender == null:
		return false
	var effect: BaseEffect = get_effect(defender.get_card_data().effect_id)
	if effect != null and effect.has_method("prevents_damage_from"):
		return bool(effect.call("prevents_damage_from", attacker, defender, state))
	return false


func process_pokemon_check(state: GameState) -> Array[PokemonSlot]:
	var damaged_slots: Array[PokemonSlot] = []
	for pi: int in 2:
		var player: PlayerState = state.players[pi]
		for slot: PokemonSlot in player.get_all_pokemon():
			var took_damage := false
			if slot.status_conditions.get("poisoned", false):
				slot.damage_counters += 10
				took_damage = true
			if slot.status_conditions.get("burned", false):
				slot.damage_counters += 20
				took_damage = true
				if coin_flipper.flip():
					slot.status_conditions["burned"] = false
			if slot.status_conditions.get("asleep", false) and coin_flipper.flip():
				slot.status_conditions["asleep"] = false
			if slot.status_conditions.get("paralyzed", false):
				slot.status_conditions["paralyzed"] = false
			if took_damage:
				damaged_slots.append(slot)
	return damaged_slots


func _get_ability_attack_modifier(attacker: PokemonSlot, state: GameState, pi: int) -> int:
	var total: int = 0
	var player: PlayerState = state.players[pi]
	total += AbilityFutureDamageBoost.get_future_damage_boost(player, attacker)
	total += AbilityLightningBoost.get_lightning_boost(player, attacker)
	for slot: PokemonSlot in player.get_all_pokemon():
		if is_ability_disabled(slot, state):
			continue
		var cd: CardData = slot.get_card_data()
		if cd == null:
			continue
		var effect: BaseEffect = get_effect(cd.effect_id)
		if effect is AbilityFutureDamageBoost:
			continue
		if effect is AbilityDamageModifier:
			var mod: AbilityDamageModifier = effect as AbilityDamageModifier
			if mod.is_attack_modifier() and (not mod.self_only or slot == attacker):
				total += mod.get_modifier()
	return total


func _get_ability_defense_modifier(defender: PokemonSlot, state: GameState, pi: int) -> int:
	var total: int = 0
	var player: PlayerState = state.players[pi]
	for slot: PokemonSlot in player.get_all_pokemon():
		if is_ability_disabled(slot, state):
			continue
		var cd: CardData = slot.get_card_data()
		if cd == null:
			continue
		var effect: BaseEffect = get_effect(cd.effect_id)
		if effect is AbilityDamageModifier:
			var mod: AbilityDamageModifier = effect as AbilityDamageModifier
			if mod.is_defense_modifier() and (not mod.self_only or slot == defender):
				total += mod.get_modifier()
	return total


func _get_tool_attack_modifier(attacker: PokemonSlot, state: GameState) -> int:
	if attacker.attached_tool == null or is_tool_effect_suppressed(attacker, state):
		return 0
	var effect: BaseEffect = get_effect(attacker.attached_tool.card_data.effect_id)
	if effect is EffectToolDamageModifier:
		var tool_mod: EffectToolDamageModifier = effect as EffectToolDamageModifier
		if tool_mod.is_attack_modifier():
			return tool_mod.damage_modifier
	elif effect is EffectToolConditionalDamage:
		var conditional_mod: EffectToolConditionalDamage = effect as EffectToolConditionalDamage
		if conditional_mod.is_active(attacker, state):
			return conditional_mod.get_bonus()
	elif effect is EffectToolFutureBoost:
		return (effect as EffectToolFutureBoost).get_attack_bonus(attacker)
	elif effect != null and effect.has_method("get_attack_modifier"):
		return int(effect.call("get_attack_modifier", attacker, state))
	return 0


func _get_tool_defense_modifier(defender: PokemonSlot, state: GameState) -> int:
	if defender.attached_tool == null or is_tool_effect_suppressed(defender, state):
		return 0
	var effect: BaseEffect = get_effect(defender.attached_tool.card_data.effect_id)
	if effect is EffectToolDamageModifier:
		var tool_mod: EffectToolDamageModifier = effect as EffectToolDamageModifier
		if tool_mod.is_defense_modifier():
			return tool_mod.damage_modifier
	elif effect != null and effect.has_method("get_defense_modifier"):
		return int(effect.call("get_defense_modifier", defender, state))
	return 0


func _get_stadium_attack_modifier(attacker: PokemonSlot, state: GameState) -> int:
	if state.stadium_card == null:
		return 0
	var effect: BaseEffect = get_effect(state.stadium_card.card_data.effect_id)
	if effect is EffectStadiumDamageModifier:
		var stadium_mod: EffectStadiumDamageModifier = effect as EffectStadiumDamageModifier
		if stadium_mod.is_attack_modifier() and stadium_mod.matches_pokemon(attacker):
			if not stadium_mod.owner_only:
				return stadium_mod.modifier_amount
			var pi: int = _get_owner_index(attacker)
			if pi == state.stadium_owner_index:
				return stadium_mod.modifier_amount
	elif effect != null and effect.has_method("get_attack_modifier"):
		return int(effect.call("get_attack_modifier", attacker, state))
	return 0


func _get_stadium_defense_modifier(defender: PokemonSlot, state: GameState) -> int:
	if state.stadium_card == null:
		return 0
	var effect: BaseEffect = get_effect(state.stadium_card.card_data.effect_id)
	if effect is EffectStadiumDamageModifier:
		var stadium_mod: EffectStadiumDamageModifier = effect as EffectStadiumDamageModifier
		if stadium_mod.is_defense_modifier() and stadium_mod.matches_pokemon(defender):
			if not stadium_mod.owner_only:
				return stadium_mod.modifier_amount
			var pi: int = _get_owner_index(defender)
			if pi == state.stadium_owner_index:
				return stadium_mod.modifier_amount
	elif effect != null and effect.has_method("get_defense_modifier"):
		return int(effect.call("get_defense_modifier", defender, state))
	return 0


func _get_energy_defense_modifier(defender: PokemonSlot, attacker: PokemonSlot, state: GameState) -> int:
	var total: int = 0
	var v_guard_applied: bool = false
	for energy: CardInstance in defender.attached_energy:
		if is_special_energy_suppressed(energy, state):
			continue
		var effect: BaseEffect = get_effect(energy.card_data.effect_id)
		if effect == null:
			continue
		if effect is EffectVGuardEnergy and attacker != null:
			if not v_guard_applied:
				var vg: EffectVGuardEnergy = effect as EffectVGuardEnergy
				var mod: int = vg.get_defense_modifier(attacker)
				if mod != 0:
					total += mod
					v_guard_applied = true
		elif effect.has_method("get_defense_modifier") and attacker != null:
			total += int(effect.call("get_defense_modifier", attacker))
	return total


func _get_energy_attack_modifier(attacker: PokemonSlot, state: GameState) -> int:
	var total: int = 0
	for energy: CardInstance in attacker.attached_energy:
		if is_special_energy_suppressed(energy, state):
			continue
		var effect: BaseEffect = get_effect(energy.card_data.effect_id)
		if effect is EffectSpecialEnergyModifier:
			total += (effect as EffectSpecialEnergyModifier).damage_modifier
		elif effect != null and effect.has_method("get_attack_modifier"):
			total += int(effect.call("get_attack_modifier", attacker, state))
	return total


func _get_owner_index(slot: PokemonSlot) -> int:
	if slot == null or slot.get_top_card() == null:
		return -1
	return slot.get_top_card().owner_index
