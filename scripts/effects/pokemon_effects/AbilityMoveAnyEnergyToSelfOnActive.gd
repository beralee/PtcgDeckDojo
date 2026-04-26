class_name AbilityMoveAnyEnergyToSelfOnActive
extends BaseEffect

const STEP_ID := "wyrdeer_energy_to_self"


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or pokemon.get_top_card() == null:
		return false
	var pi: int = pokemon.get_top_card().owner_index
	var player: PlayerState = state.players[pi]
	if state.current_player_index != pi or player.active_pokemon != pokemon:
		return false
	if not pokemon.entered_active_from_bench_this_turn(state.turn_number):
		return false
	if pokemon.has_ability_used(state.turn_number):
		return false
	return _movable_energy(player, pokemon).size() > 0


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var pokemon: PokemonSlot = player.active_pokemon
	if pokemon == null:
		return []
	var source_items: Array = _movable_energy(player, pokemon)
	var source_labels: Array[String] = []
	for energy: CardInstance in source_items:
		source_labels.append("%s - %s" % [_energy_owner_name(player, energy), energy.card_data.name])
	return [{
		"id": STEP_ID,
		"title": "Move any amount of your Energy to this Pokemon",
		"items": source_items,
		"labels": source_labels,
		"min_select": 0,
		"max_select": source_items.size(),
		"allow_cancel": true,
	}]


func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
	if pokemon == null or pokemon.get_top_card() == null:
		return
	var pi: int = pokemon.get_top_card().owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected: Array[CardInstance] = []
	for entry: Variant in ctx.get(STEP_ID, []):
		if entry is CardInstance and entry in _movable_energy(player, pokemon) and entry not in selected:
			selected.append(entry)
	if selected.is_empty() and not ctx.has(STEP_ID):
		selected = _movable_energy(player, pokemon)
	for energy: CardInstance in selected:
		for slot: PokemonSlot in player.get_all_pokemon():
			if energy in slot.attached_energy:
				slot.attached_energy.erase(energy)
				break
		pokemon.attached_energy.append(energy)
	pokemon.mark_ability_used(state.turn_number)


func _movable_energy(player: PlayerState, self_slot: PokemonSlot) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		for energy: CardInstance in slot.attached_energy:
			if slot == self_slot and energy in self_slot.attached_energy:
				continue
			result.append(energy)
	return result


func _energy_owner_name(player: PlayerState, energy: CardInstance) -> String:
	for slot: PokemonSlot in player.get_all_pokemon():
		if energy in slot.attached_energy:
			return slot.get_pokemon_name()
	return ""
