class_name AbilityAttachBasicEnergyFromDiscardToOwn
extends BaseEffect

const STEP_ID := "attach_basic_energy_from_discard"


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or pokemon.get_top_card() == null:
		return false
	var pi: int = pokemon.get_top_card().owner_index
	if state.current_player_index != pi or pokemon.has_ability_used(state.turn_number):
		return false
	var player: PlayerState = state.players[pi]
	return not _basic_energy(player).is_empty() and not player.get_all_pokemon().is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var source_items: Array = _basic_energy(player)
	var source_labels: Array[String] = []
	for energy: CardInstance in source_items:
		source_labels.append(energy.card_data.name)
	var target_items: Array = player.get_all_pokemon()
	var target_labels: Array[String] = []
	for slot: PokemonSlot in target_items:
		target_labels.append(slot.get_pokemon_name())
	return [build_card_assignment_step(
		STEP_ID,
		"Attach 1 Basic Energy from discard to your Pokemon",
		source_items,
		source_labels,
		target_items,
		target_labels,
		1,
		1,
		true
	)]


func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
	if pokemon == null or pokemon.get_top_card() == null:
		return
	var pi: int = pokemon.get_top_card().owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(targets)
	var assignment: Dictionary = _resolve_assignment(player, ctx)
	if assignment.is_empty():
		return
	var energy: CardInstance = assignment.get("source", null)
	var target: PokemonSlot = assignment.get("target", null)
	if energy == null or target == null:
		return
	player.discard_pile.erase(energy)
	target.attached_energy.append(energy)
	pokemon.mark_ability_used(state.turn_number)


func _resolve_assignment(player: PlayerState, ctx: Dictionary) -> Dictionary:
	for entry: Variant in ctx.get(STEP_ID, []):
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		var source: Variant = assignment.get("source", null)
		var target: Variant = assignment.get("target", null)
		if source is CardInstance and target is PokemonSlot and source in _basic_energy(player) and target in player.get_all_pokemon():
			return {"source": source, "target": target}
	var energies: Array = _basic_energy(player)
	var targets: Array[PokemonSlot] = player.get_all_pokemon()
	if energies.is_empty() or targets.is_empty():
		return {}
	return {"source": energies[0], "target": targets[0]}


func _basic_energy(player: PlayerState) -> Array:
	var result: Array = []
	for discard_card: CardInstance in player.discard_pile:
		if discard_card.card_data != null and discard_card.card_data.card_type == "Basic Energy":
			result.append(discard_card)
	return result
