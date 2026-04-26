class_name AttackDiscardOpponentTools
extends BaseEffect

const STEP_ID := "discard_opponent_tools"

var max_count: int = 2
var attack_index_to_match: int = -1


func _init(count: int = 2, match_attack_index: int = -1) -> void:
	max_count = count
	attack_index_to_match = match_attack_index


func applies_to_attack_index(index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == index


func get_attack_interaction_steps(card: CardInstance, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var tools: Array = _get_attached_tools(opponent)
	var labels: Array[String] = []
	for tool_card: CardInstance in tools:
		labels.append("%s - %s" % [_tool_holder_name(opponent, tool_card), tool_card.card_data.name])
	if tools.is_empty():
		return []
	return [{
		"id": STEP_ID,
		"title": "Choose up to %d opponent Pokemon Tools to discard" % max_count,
		"items": tools,
		"labels": labels,
		"min_select": 0,
		"max_select": mini(max_count, tools.size()),
		"allow_cancel": true,
	}]


func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, state: GameState) -> void:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var ctx: Dictionary = get_attack_interaction_context()
	var selected: Array[CardInstance] = []
	for entry: Variant in ctx.get(STEP_ID, []):
		if entry is CardInstance and entry in _get_attached_tools(opponent) and entry not in selected:
			selected.append(entry)
			if selected.size() >= max_count:
				break
	if selected.is_empty() and not ctx.has(STEP_ID):
		for tool_card: CardInstance in _get_attached_tools(opponent):
			selected.append(tool_card)
			if selected.size() >= max_count:
				break
	for tool_card: CardInstance in selected:
		for slot: PokemonSlot in opponent.get_all_pokemon():
			if slot.attached_tool == tool_card:
				slot.attached_tool = null
				opponent.discard_card(tool_card)
				break


func _get_attached_tools(player: PlayerState) -> Array:
	var result: Array = []
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot.attached_tool != null:
			result.append(slot.attached_tool)
	return result


func _tool_holder_name(player: PlayerState, tool_card: CardInstance) -> String:
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot.attached_tool == tool_card:
			return slot.get_pokemon_name()
	return ""
