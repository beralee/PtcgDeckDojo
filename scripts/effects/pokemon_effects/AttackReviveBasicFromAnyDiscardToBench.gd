class_name AttackReviveBasicFromAnyDiscardToBench
extends BaseEffect

const BenchLimit = preload("res://scripts/engine/BenchLimitHelper.gd")


func get_attack_interaction_steps(card: CardInstance, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
	if card == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	if BenchLimit.is_bench_full(state, player):
		return []
	var items: Array = _get_basic_targets(state)
	if items.is_empty():
		return []
	var labels: Array[String] = []
	for discard_card: CardInstance in items:
		labels.append("%s" % discard_card.card_data.name)
	return [{
		"id": "revive_basic_from_any_discard",
		"title": "选择1张弃牌区中的基础宝可梦放回其持有者的备战区",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, state: GameState) -> void:
	if attacker == null or attacker.get_top_card() == null:
		return
	var owner_index: int = attacker.get_top_card().owner_index
	var owner: PlayerState = state.players[owner_index]
	if BenchLimit.is_bench_full(state, owner):
		return
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get("revive_basic_from_any_discard", [])
	var chosen: CardInstance = null
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance:
		var candidate: CardInstance = selected_raw[0]
		if _is_basic_pokemon(candidate) and _remove_from_any_discard(candidate, state):
			chosen = candidate
	if chosen == null:
		for candidate: CardInstance in _get_basic_targets(state):
			if _remove_from_any_discard(candidate, state):
				chosen = candidate
				break
	if chosen == null:
		return
	chosen.face_up = true
	var target_owner: int = chosen.owner_index
	var player: PlayerState = state.players[target_owner]
	if BenchLimit.is_bench_full(state, player):
		player.discard_pile.append(chosen)
		return
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(chosen)
	slot.turn_played = state.turn_number
	player.bench.append(slot)


func get_description() -> String:
	return "选择自己或对手弃牌区中的1张基础宝可梦，放于持有者的备战区。"


func _get_basic_targets(state: GameState) -> Array:
	var items: Array = []
	for player: PlayerState in state.players:
		for discard_card: CardInstance in player.discard_pile:
			if _is_basic_pokemon(discard_card):
				items.append(discard_card)
	return items


func _is_basic_pokemon(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.is_basic_pokemon()


func _remove_from_any_discard(card: CardInstance, state: GameState) -> bool:
	for player: PlayerState in state.players:
		if card in player.discard_pile:
			player.discard_pile.erase(card)
			return true
	return false
