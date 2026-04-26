class_name EffectKieran
extends BaseEffect

const MODE_STEP_ID := "kieran_mode"
const SWITCH_STEP_ID := "kieran_switch_target"
const MODE_SWITCH := "switch_active"
const MODE_DAMAGE := "boost_vs_active_rule_box"
const DAMAGE_FLAG_PREFIX := "kieran_attack_bonus_turn_"
const DAMAGE_VALUE_PREFIX := "kieran_attack_bonus_value_"


func can_execute(card: CardInstance, state: GameState) -> bool:
	return _get_available_modes(card, state).size() > 0


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var modes: Array[String] = _get_available_modes(card, state)
	if modes.is_empty():
		return []
	var labels: Array[String] = []
	for mode: String in modes:
		labels.append(_get_mode_label(mode))
	return [{
		"id": MODE_STEP_ID,
		"title": "选择效果",
		"items": modes,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}]


func get_followup_interaction_steps(
	card: CardInstance,
	state: GameState,
	resolved_context: Dictionary
) -> Array[Dictionary]:
	var selected_mode: String = _resolve_selected_mode(card, state, resolved_context)
	if selected_mode != MODE_SWITCH:
		return []
	var player: PlayerState = state.players[card.owner_index]
	if player.bench.is_empty():
		return []
	var items: Array = []
	var labels: Array[String] = []
	for slot: PokemonSlot in player.bench:
		items.append(slot)
		labels.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])
	return [{
		"id": SWITCH_STEP_ID,
		"title": "选择 1 只备战宝可梦与战斗宝可梦互换",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_mode: String = _resolve_selected_mode(card, state, ctx)

	match selected_mode:
		MODE_SWITCH:
			if player.active_pokemon == null or player.bench.is_empty():
				return
			var replacement: PokemonSlot = _resolve_switch_target(player, ctx)
			if replacement == null:
				return
			var old_active: PokemonSlot = player.active_pokemon
			player.bench.erase(replacement)
			old_active.clear_on_leave_active()
			player.bench.append(old_active)
			player.active_pokemon = replacement
		MODE_DAMAGE:
			state.shared_turn_flags[DAMAGE_FLAG_PREFIX + str(card.owner_index)] = state.turn_number
			state.shared_turn_flags[DAMAGE_VALUE_PREFIX + str(card.owner_index)] = 30


func get_description() -> String:
	return "从以下效果中选择 1 个：将自己的战斗宝可梦与 1 只备战宝可梦互换；或者在这个回合，自己的宝可梦对对手战斗场上的宝可梦 ex 或宝可梦 V 造成的伤害增加 30。"


static func get_turn_damage_bonus(attacker: PokemonSlot, defender: PokemonSlot, state: GameState) -> int:
	if attacker == null or defender == null or state == null:
		return 0
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return 0
	var pi: int = top.owner_index
	if int(state.shared_turn_flags.get(DAMAGE_FLAG_PREFIX + str(pi), -999)) != state.turn_number:
		return 0
	var opponent: PlayerState = state.players[1 - pi]
	if defender != opponent.active_pokemon:
		return 0
	var defender_cd: CardData = defender.get_card_data()
	if defender_cd == null:
		return 0
	if defender_cd.mechanic == "ex" or defender_cd.mechanic in ["V", "VSTAR", "VMAX"]:
		return int(state.shared_turn_flags.get(DAMAGE_VALUE_PREFIX + str(pi), 30))
	return 0


func _get_available_modes(card: CardInstance, state: GameState) -> Array[String]:
	var player: PlayerState = state.players[card.owner_index]
	var modes: Array[String] = []
	if player.active_pokemon != null and not player.bench.is_empty():
		modes.append(MODE_SWITCH)
	modes.append(MODE_DAMAGE)
	return modes


func _get_mode_label(mode: String) -> String:
	match mode:
		MODE_SWITCH:
			return "将自己的战斗宝可梦与 1 只备战宝可梦互换"
		MODE_DAMAGE:
			return "这个回合自己的宝可梦对对手战斗宝可梦 ex 或 V 造成的伤害增加 30"
		_:
			return mode


func _resolve_selected_mode(card: CardInstance, state: GameState, ctx: Dictionary) -> String:
	var available_modes: Array[String] = _get_available_modes(card, state)
	var raw: Array = ctx.get(MODE_STEP_ID, [])
	if not raw.is_empty():
		var selected: String = str(raw[0])
		if selected in available_modes:
			return selected
	return available_modes[0] if not available_modes.is_empty() else ""


func _resolve_switch_target(player: PlayerState, ctx: Dictionary) -> PokemonSlot:
	var raw: Array = ctx.get(SWITCH_STEP_ID, [])
	if not raw.is_empty() and raw[0] is PokemonSlot:
		var selected: PokemonSlot = raw[0]
		if selected in player.bench:
			return selected
	return player.bench[0] if not player.bench.is_empty() else null
