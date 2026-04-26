class_name EffectEnhancedHammer
extends BaseEffect

const STEP_ID := "enhanced_hammer_energy"


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not _special_energy(state.players[1 - card.owner_index]).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var items: Array = _special_energy(opponent)
	var labels: Array[String] = []
	for energy: CardInstance in items:
		labels.append("%s - %s" % [_energy_holder_name(opponent, energy), energy.card_data.name])
	return [{
		"id": STEP_ID,
		"title": "Choose an opponent Special Energy to discard",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var energy: CardInstance = null
	var raw: Array = ctx.get(STEP_ID, [])
	if not raw.is_empty() and raw[0] is CardInstance and raw[0] in _special_energy(opponent):
		energy = raw[0]
	if energy == null:
		var energies: Array = _special_energy(opponent)
		energy = energies[0] if not energies.is_empty() else null
	if energy == null:
		return
	for slot: PokemonSlot in opponent.get_all_pokemon():
		if energy in slot.attached_energy:
			slot.attached_energy.erase(energy)
			opponent.discard_card(energy)
			return


func _special_energy(player: PlayerState) -> Array:
	var result: Array = []
	for slot: PokemonSlot in player.get_all_pokemon():
		for energy: CardInstance in slot.attached_energy:
			if energy.card_data != null and energy.card_data.card_type == "Special Energy":
				result.append(energy)
	return result


func _energy_holder_name(player: PlayerState, energy: CardInstance) -> String:
	for slot: PokemonSlot in player.get_all_pokemon():
		if energy in slot.attached_energy:
			return slot.get_pokemon_name()
	return ""
