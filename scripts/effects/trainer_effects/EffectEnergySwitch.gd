class_name EffectEnergySwitch
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return _has_valid_source(player) and player.get_all_pokemon().size() >= 2


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var all_pokemon: Array = player.get_all_pokemon()

	var energy_items: Array = []
	var energy_labels: Array[String] = []
	var source_groups: Array[Dictionary] = []
	for slot: PokemonSlot in all_pokemon:
		var group_indices: Array[int] = []
		for energy: CardInstance in slot.attached_energy:
			if energy.card_data.card_type == "Basic Energy":
				group_indices.append(energy_items.size())
				energy_items.append(energy)
				energy_labels.append(energy.card_data.name)
		if not group_indices.is_empty():
			source_groups.append({"slot": slot, "energy_indices": group_indices})

	var target_items: Array = []
	var target_labels: Array[String] = []
	for slot: PokemonSlot in all_pokemon:
		target_items.append(slot)
		target_labels.append(slot.get_pokemon_name())

	var exclude_map: Dictionary = {}
	for group: Dictionary in source_groups:
		var slot: PokemonSlot = group["slot"]
		var target_idx: int = target_items.find(slot)
		if target_idx < 0:
			continue
		for ei: Variant in group["energy_indices"]:
			exclude_map[int(ei)] = [target_idx]

	var step: Dictionary = build_card_assignment_step(
		"energy_assignment",
		"选择要转移的基本能量（左侧），然后选择目标宝可梦（右侧）",
		energy_items,
		energy_labels,
		target_items,
		target_labels,
		1,
		1,
		true,
	)
	step["source_groups"] = source_groups
	step["source_exclude_targets"] = exclude_map
	return [step]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)

	var assignments: Array = ctx.get("energy_assignment", [])
	if assignments.is_empty():
		return
	var assignment: Dictionary = assignments[0]

	var chosen_energy: Variant = assignment.get("source")
	var target_slot: Variant = assignment.get("target")
	if not chosen_energy is CardInstance or not target_slot is PokemonSlot:
		return

	var energy: CardInstance = chosen_energy as CardInstance
	var target: PokemonSlot = target_slot as PokemonSlot
	if energy.card_data.card_type != "Basic Energy":
		return
	if target not in player.get_all_pokemon():
		return

	var source: PokemonSlot = _find_slot_for_energy(player, energy)
	if source == null or source == target:
		return

	source.attached_energy.erase(energy)
	target.attached_energy.append(energy)


func _has_valid_source(player: PlayerState) -> bool:
	for slot: PokemonSlot in player.get_all_pokemon():
		for energy: CardInstance in slot.attached_energy:
			if energy.card_data.card_type == "Basic Energy":
				return true
	return false


func _find_slot_for_energy(player: PlayerState, energy: CardInstance) -> PokemonSlot:
	for slot: PokemonSlot in player.get_all_pokemon():
		if energy in slot.attached_energy:
			return slot
	return null


func get_description() -> String:
	return "将你的 1 只宝可梦身上的 1 个基本能量转移到另一只宝可梦身上。"
