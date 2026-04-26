class_name EffectJaninesSecretArt
extends BaseEffect

const ASSIGNMENT_ID := "janine_assignments"
const DARK_TYPE := "D"


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not _get_dark_energy_from_deck(player).is_empty() and not _get_dark_targets(player).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var source_items: Array = _get_dark_energy_from_deck(player)
	if source_items.is_empty():
		return []
	var source_labels: Array[String] = []
	for energy: CardInstance in source_items:
		source_labels.append(energy.card_data.name)
	var target_items: Array = _get_dark_targets(player)
	if target_items.is_empty():
		return []
	var target_labels: Array[String] = []
	for slot: PokemonSlot in target_items:
		target_labels.append("%s (HP %d/%d)" % [
			slot.get_pokemon_name(),
			slot.get_remaining_hp(),
			slot.get_max_hp(),
		])
	return [build_card_assignment_step(
		ASSIGNMENT_ID,
		"Attach up to 2 Basic Darkness Energy cards to your Darkness Pokemon",
		source_items,
		source_labels,
		target_items,
		target_labels,
		1,
		mini(2, source_items.size()),
		true
	)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var assignments: Array[Dictionary] = _resolve_assignments(player, ctx)
	if assignments.is_empty() and ctx.has(ASSIGNMENT_ID):
		player.shuffle_deck()
		return
	if assignments.is_empty():
		assignments = _build_fallback_assignments(player)
	if assignments.is_empty():
		player.shuffle_deck()
		return

	var active_poisoned := false
	for assignment: Dictionary in assignments:
		var energy: CardInstance = assignment.get("source", null)
		var target: PokemonSlot = assignment.get("target", null)
		if energy == null or target == null:
			continue
		if energy not in player.deck or target not in _get_dark_targets(player):
			continue
		player.deck.erase(energy)
		energy.face_up = true
		target.attached_energy.append(energy)
		if target == player.active_pokemon:
			active_poisoned = true

	player.shuffle_deck()
	if active_poisoned and player.active_pokemon != null:
		player.active_pokemon.set_status("poisoned", true)


func _resolve_assignments(player: PlayerState, ctx: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var selected_raw: Array = ctx.get(ASSIGNMENT_ID, [])
	var used_sources: Array[CardInstance] = []
	var valid_sources: Array = _get_dark_energy_from_deck(player)
	var valid_targets: Array = _get_dark_targets(player)
	for entry: Variant in selected_raw:
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		var source: Variant = assignment.get("source", null)
		var target: Variant = assignment.get("target", null)
		if not (source is CardInstance) or not (target is PokemonSlot):
			continue
		var source_card := source as CardInstance
		var target_slot := target as PokemonSlot
		if source_card not in valid_sources or target_slot not in valid_targets or source_card in used_sources:
			continue
		used_sources.append(source_card)
		result.append({"source": source_card, "target": target_slot})
		if result.size() >= 2:
			break
	return result


func _build_fallback_assignments(player: PlayerState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var energies: Array = _get_dark_energy_from_deck(player)
	var targets: Array = _get_dark_targets(player)
	if energies.is_empty() or targets.is_empty():
		return result
	for i: int in mini(2, energies.size()):
		result.append({
			"source": energies[i],
			"target": targets[mini(i, targets.size() - 1)],
		})
	return result


func _get_dark_energy_from_deck(player: PlayerState) -> Array:
	var result: Array = []
	for card: CardInstance in player.deck:
		if card == null or card.card_data == null:
			continue
		if card.card_data.card_type != "Basic Energy":
			continue
		if card.card_data.energy_provides != DARK_TYPE and card.card_data.energy_type != DARK_TYPE:
			continue
		result.append(card)
	return result


func _get_dark_targets(player: PlayerState) -> Array:
	var result: Array = []
	for slot: PokemonSlot in player.get_all_pokemon():
		var cd: CardData = slot.get_card_data()
		if cd != null and cd.energy_type == DARK_TYPE:
			result.append(slot)
	return result


func get_description() -> String:
	return "Attach up to 2 Basic Darkness Energy cards from your deck to your Darkness Pokemon. If any were attached to your Active Pokemon, it is now Poisoned."
