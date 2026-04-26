class_name EffectSadasVitality
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return _get_basic_energy(player).size() >= 1 and _get_ancient_targets(player).size() >= 1


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var source_items: Array = _get_basic_energy(player)
	var source_labels: Array[String] = []
	for energy: CardInstance in source_items:
		source_labels.append(energy.card_data.name)
	var target_items: Array = _get_ancient_targets(player)
	var target_labels: Array[String] = []
	for slot: PokemonSlot in target_items:
		target_labels.append(slot.get_pokemon_name())
	var step := build_card_assignment_step(
		"sada_assignments",
		"Attach up to 2 Basic Energy to your Ancient Pokemon",
		source_items,
		source_labels,
		target_items,
		target_labels,
		1,
		mini(2, source_items.size())
	)
	step["max_assignments_per_target"] = 1
	return [step]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var assignments_raw: Array = ctx.get("sada_assignments", [])
	var attached_count := 0
	var attached_targets: Array[PokemonSlot] = []
	for entry: Variant in assignments_raw:
		if attached_count >= 2:
			break
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		var source: Variant = assignment.get("source", null)
		var target: Variant = assignment.get("target", null)
		if not (source is CardInstance) or not (target is PokemonSlot):
			continue
		var energy: CardInstance = source
		var slot: PokemonSlot = target
		if energy not in player.discard_pile:
			continue
		if not slot in _get_ancient_targets(player):
			continue
		if slot in attached_targets:
			continue
		player.discard_pile.erase(energy)
		slot.attached_energy.append(energy)
		attached_targets.append(slot)
		attached_count += 1
	_draw_cards_with_log(state, card.owner_index, 3, card, "trainer")


func _get_basic_energy(player: PlayerState) -> Array:
	var items: Array = []
	for card: CardInstance in player.discard_pile:
		if card.card_data.card_type == "Basic Energy":
			items.append(card)
	return items


func _get_ancient_targets(player: PlayerState) -> Array:
	var targets: Array = []
	for slot: PokemonSlot in player.get_all_pokemon():
		var card_data: CardData = slot.get_card_data()
		if card_data != null and card_data.is_ancient_pokemon():
			targets.append(slot)
	return targets


func get_description() -> String:
	return "Attach a Basic Energy from your discard pile to each of up to 2 of your Ancient Pokemon. Then draw 3 cards."
