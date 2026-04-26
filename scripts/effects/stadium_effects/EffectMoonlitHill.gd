class_name EffectMoonlitHill
extends BaseEffect

const STEP_ID := "moonlit_hill_energy"


func can_use_as_stadium_action(_card: CardInstance, _state: GameState) -> bool:
	return true


func can_execute(_card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[state.current_player_index]
	return not _get_basic_psychic_energy(player).is_empty()


func get_interaction_steps(_card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[state.current_player_index]
	var items: Array = _get_basic_psychic_energy(player)
	var labels: Array[String] = []
	for energy: CardInstance in items:
		labels.append(energy.card_data.name)
	return [{
		"id": STEP_ID,
		"title": "Discard 1 Basic Psychic Energy to heal all your Pokemon",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute(_card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[state.current_player_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var energy: CardInstance = null
	var raw: Array = ctx.get(STEP_ID, [])
	if not raw.is_empty() and raw[0] is CardInstance and raw[0] in _get_basic_psychic_energy(player):
		energy = raw[0]
	if energy == null:
		var energies: Array = _get_basic_psychic_energy(player)
		energy = energies[0] if not energies.is_empty() else null
	if energy == null:
		return
	player.remove_from_hand(energy)
	player.discard_card(energy)
	for slot: PokemonSlot in player.get_all_pokemon():
		slot.damage_counters = maxi(0, slot.damage_counters - 30)


func _get_basic_psychic_energy(player: PlayerState) -> Array:
	var result: Array = []
	for hand_card: CardInstance in player.hand:
		if hand_card.card_data != null and hand_card.card_data.card_type == "Basic Energy" and hand_card.card_data.energy_provides == "P":
			result.append(hand_card)
	return result
