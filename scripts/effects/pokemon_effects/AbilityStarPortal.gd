## Origin Forme Palkia VSTAR - attach up to 3 Water Energy from discard to your Water Pokemon.
class_name AbilityStarPortal
extends BaseEffect

const SELECT_ASSIGNMENTS_ID := "star_portal_assignments"


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var pi: int = top.owner_index
	if state.current_player_index != pi:
		return false
	if state.vstar_power_used[pi]:
		return false
	var player: PlayerState = state.players[pi]
	return not _get_water_energy_cards(player.discard_pile).is_empty() and not _get_water_targets(player).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var energy_items: Array = _get_water_energy_cards(player.discard_pile)
	if energy_items.is_empty():
		return []

	var energy_labels: Array[String] = []
	for energy_card: CardInstance in energy_items:
		energy_labels.append(energy_card.card_data.name)

	var target_items: Array = []
	var target_labels: Array[String] = []
	for target_slot: PokemonSlot in _get_water_targets(player):
		target_items.append(target_slot)
		target_labels.append("%s (HP %d/%d)" % [
			target_slot.get_pokemon_name(),
			target_slot.get_remaining_hp(),
			target_slot.get_max_hp(),
		])

	return [build_card_assignment_step(
		SELECT_ASSIGNMENTS_ID,
		"选择最多3张水能量并分配给己方水属性宝可梦",
		energy_items,
		energy_labels,
		target_items,
		target_labels,
		1,
		mini(3, energy_items.size()),
		true
	)]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	if not can_use_ability(pokemon, state):
		return

	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var pi: int = top.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(targets)

	var assignments: Array[Dictionary] = _resolve_assignments(player, ctx)
	if assignments.is_empty() and ctx.has(SELECT_ASSIGNMENTS_ID):
		return
	if assignments.is_empty():
		return

	for assignment: Dictionary in assignments:
		var energy_card: CardInstance = assignment.get("source")
		var target_slot: PokemonSlot = assignment.get("target")
		if energy_card == null or target_slot == null:
			continue
		if energy_card not in player.discard_pile:
			continue
		player.discard_pile.erase(energy_card)
		energy_card.face_up = true
		target_slot.attached_energy.append(energy_card)

	state.vstar_power_used[pi] = true


func _resolve_assignments(player: PlayerState, ctx: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var selected_raw: Array = ctx.get(SELECT_ASSIGNMENTS_ID, [])
	var has_explicit_assignments: bool = ctx.has(SELECT_ASSIGNMENTS_ID)
	var used_sources: Array[CardInstance] = []
	for entry: Variant in selected_raw:
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		var source: Variant = assignment.get("source")
		var target: Variant = assignment.get("target")
		if not (source is CardInstance) or not (target is PokemonSlot):
			continue
		var source_card: CardInstance = source as CardInstance
		var target_slot: PokemonSlot = target as PokemonSlot
		if source_card not in player.discard_pile or not _is_water_energy(source_card):
			continue
		if target_slot not in player.get_all_pokemon() or not _is_water_pokemon(target_slot):
			continue
		if source_card in used_sources:
			continue
		used_sources.append(source_card)
		result.append({
			"source": source_card,
			"target": target_slot,
		})
		if result.size() >= 3:
			break

	if not result.is_empty() or has_explicit_assignments:
		return result

	var fallback_targets: Array[PokemonSlot] = _get_water_targets(player)
	if fallback_targets.is_empty():
		return []
	for i: int in mini(3, _get_water_energy_cards(player.discard_pile).size()):
		result.append({
			"source": _get_water_energy_cards(player.discard_pile)[i],
			"target": fallback_targets[mini(i, fallback_targets.size() - 1)],
		})
	return result


func _get_water_energy_cards(cards: Array[CardInstance]) -> Array:
	var result: Array = []
	for card: CardInstance in cards:
		if _is_water_energy(card):
			result.append(card)
	return result


func _get_water_targets(player: PlayerState) -> Array[PokemonSlot]:
	var result: Array[PokemonSlot] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		if _is_water_pokemon(slot):
			result.append(slot)
	return result


func _is_water_energy(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	return card.card_data.card_type == "Basic Energy" and (
		card.card_data.energy_provides == "W" or card.card_data.energy_type == "W"
	)


func _is_water_pokemon(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	var cd: CardData = slot.get_card_data()
	return cd != null and cd.energy_type == "W"


func get_description() -> String:
	return "VSTAR Power: attach up to 3 Water Energy cards from your discard pile to your Water Pokemon."
