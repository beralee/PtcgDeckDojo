class_name EffectGiacomo
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not _get_source_slots(state.players[1 - card.owner_index]).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var source_slots: Array[PokemonSlot] = _get_source_slots(opponent)
	if source_slots.is_empty():
		return []
	var target_items: Array = []
	var target_labels: Array[String] = []
	for slot: PokemonSlot in source_slots:
		for energy: CardInstance in slot.attached_energy:
			if _is_special_energy(energy):
				target_items.append(energy)
				target_labels.append("%s - %s" % [slot.get_pokemon_name(), energy.card_data.name])
	return [build_card_assignment_step(
		"discard_special_energy",
		"选择对手每只宝可梦身上的1个特殊能量",
		source_slots,
		_build_source_labels(source_slots),
		target_items,
		target_labels,
		source_slots.size(),
		source_slots.size(),
		false
	).merged({"source_exclude_targets": _build_source_exclude_targets(source_slots, target_items)})]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var raw_assignments: Array = ctx.get("discard_special_energy", [])
	var chosen: Array[CardInstance] = []
	var used_sources: Dictionary = {}
	for entry: Variant in raw_assignments:
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		var source: Variant = assignment.get("source")
		var target: Variant = assignment.get("target")
		if not (source is PokemonSlot) or not (target is CardInstance):
			continue
		var source_slot: PokemonSlot = source
		var energy: CardInstance = target
		if not source_slot in opponent.get_all_pokemon():
			continue
		if used_sources.has(source_slot) or not (energy in source_slot.attached_energy) or not _is_special_energy(energy):
			continue
		used_sources[source_slot] = true
		chosen.append(energy)
	if chosen.is_empty():
		for slot: PokemonSlot in _get_source_slots(opponent):
			for energy: CardInstance in slot.attached_energy:
				if _is_special_energy(energy):
					chosen.append(energy)
					break
	for energy: CardInstance in chosen:
		for slot: PokemonSlot in opponent.get_all_pokemon():
			if energy in slot.attached_energy:
				slot.attached_energy.erase(energy)
				opponent.discard_card(energy)
				break


func get_description() -> String:
	return "选择对手所有宝可梦身上附着的特殊能量各1个，放于弃牌区。"


func _get_source_slots(player: PlayerState) -> Array[PokemonSlot]:
	var result: Array[PokemonSlot] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		for energy: CardInstance in slot.attached_energy:
			if _is_special_energy(energy):
				result.append(slot)
				break
	return result


func _build_source_labels(source_slots: Array[PokemonSlot]) -> Array[String]:
	var labels: Array[String] = []
	for slot: PokemonSlot in source_slots:
		labels.append(slot.get_pokemon_name())
	return labels


func _build_source_exclude_targets(source_slots: Array[PokemonSlot], target_items: Array) -> Dictionary:
	var exclude_map: Dictionary = {}
	for source_index: int in source_slots.size():
		var source_slot: PokemonSlot = source_slots[source_index]
		var excluded: Array[int] = []
		for target_index: int in target_items.size():
			var target: Variant = target_items[target_index]
			if not (target is CardInstance) or not ((target as CardInstance) in source_slot.attached_energy):
				excluded.append(target_index)
		exclude_map[source_index] = excluded
	return exclude_map


func _is_special_energy(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.card_type == "Special Energy"
