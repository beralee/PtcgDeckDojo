class_name EffectErikasInvitation
extends BaseEffect

const BenchLimit = preload("res://scripts/engine/BenchLimitHelper.gd")


func can_execute(card: CardInstance, state: GameState) -> bool:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	return BenchLimit.get_available_bench_space(state, opponent) > 0 and not _get_basic_pokemon_in_hand(opponent).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var basics: Array = _get_basic_pokemon_in_hand(opponent)
	if basics.is_empty():
		return []
	var labels: Array[String] = []
	for pokemon: CardInstance in basics:
		labels.append(pokemon.card_data.name)
	return [{
		"id": "opponent_basic_in_hand",
		"title": "选择对手手牌中的1张基础宝可梦",
		"items": basics,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	if BenchLimit.get_available_bench_space(state, opponent) <= 0 or opponent.active_pokemon == null:
		return
	var chosen: CardInstance = _resolve_selected_basic(opponent, targets)
	if chosen == null or not opponent.remove_from_hand(chosen):
		return
	chosen.face_up = true
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(chosen)
	slot.turn_played = state.turn_number
	var old_active: PokemonSlot = opponent.active_pokemon
	old_active.clear_on_leave_active()
	opponent.bench.append(old_active)
	opponent.active_pokemon = slot


func get_description() -> String:
	return "查看对手的手牌，选择其中1张基础宝可梦，放于对手的备战区。然后，将那只宝可梦与战斗宝可梦互换。"


func _get_basic_pokemon_in_hand(player: PlayerState) -> Array:
	var basics: Array = []
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.is_basic_pokemon():
			basics.append(card)
	return basics


func _resolve_selected_basic(player: PlayerState, targets: Array) -> CardInstance:
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("opponent_basic_in_hand", [])
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance:
		var candidate: CardInstance = selected_raw[0]
		if candidate in player.hand and candidate.card_data != null and candidate.card_data.is_basic_pokemon():
			return candidate
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.is_basic_pokemon():
			return card
	return null
