class_name EffectMirageGate
extends BaseEffect

const ASSIGNMENT_STEP_ID := "mirage_gate_assignments"

var required_lost_zone_count: int = 7
var attach_count: int = 2


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	if player.lost_zone.size() < required_lost_zone_count:
		return false
	return not player.get_all_pokemon().is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var energy_items: Array[CardInstance] = _get_unique_basic_energy_cards(player.deck)
	if energy_items.is_empty():
		return []

	var energy_labels: Array[String] = []
	for energy_card: CardInstance in energy_items:
		energy_labels.append(energy_card.card_data.name)

	var target_items: Array = []
	var target_labels: Array[String] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		target_items.append(slot)
		target_labels.append("%s (HP %d/%d)" % [
			slot.get_pokemon_name(),
			slot.get_remaining_hp(),
			slot.get_max_hp(),
		])

	return [build_card_assignment_step(
		ASSIGNMENT_STEP_ID,
		"Choose up to 2 different Basic Energy cards and attach them to your Pokemon",
		energy_items,
		energy_labels,
		target_items,
		target_labels,
		0,
		mini(attach_count, energy_items.size()),
		true
	)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var candidates: Array[CardInstance] = _get_unique_basic_energy_cards(player.deck)
	if candidates.is_empty():
		player.shuffle_deck()
		return
	var assignments: Array[Dictionary] = _resolve_assignments(player, candidates, ctx)
	if assignments.is_empty() and ctx.has(ASSIGNMENT_STEP_ID):
		player.shuffle_deck()
		return
	if assignments.is_empty():
		assignments = _build_fallback_assignments(player, candidates)

	for assignment: Dictionary in assignments:
		var energy_card: CardInstance = assignment.get("source")
		var target_slot: PokemonSlot = assignment.get("target")
		if energy_card == null or target_slot == null:
			continue
		if energy_card not in player.deck or target_slot not in player.get_all_pokemon():
			continue
		player.deck.erase(energy_card)
		energy_card.face_up = true
		target_slot.attached_energy.append(energy_card)

	player.shuffle_deck()


func _resolve_assignments(player: PlayerState, candidates: Array[CardInstance], ctx: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var used_sources: Array[CardInstance] = []
	var selected_raw: Array = ctx.get(ASSIGNMENT_STEP_ID, [])
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
		if source_card not in candidates or target_slot not in player.get_all_pokemon():
			continue
		if source_card in used_sources:
			continue
		used_sources.append(source_card)
		result.append({
			"source": source_card,
			"target": target_slot,
		})
		if result.size() >= attach_count:
			break
	return result


func _build_fallback_assignments(player: PlayerState, candidates: Array[CardInstance]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var target_slots: Array[PokemonSlot] = player.get_all_pokemon()
	if target_slots.is_empty():
		return result
	for idx: int in range(mini(attach_count, candidates.size())):
		result.append({
			"source": candidates[idx],
			"target": target_slots[mini(idx, target_slots.size() - 1)],
		})
	return result


func _get_unique_basic_energy_cards(cards: Array[CardInstance]) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	var seen_types: Dictionary = {}
	for card: CardInstance in cards:
		if card == null or card.card_data == null or card.card_data.card_type != "Basic Energy":
			continue
		var energy_type: String = card.card_data.energy_provides if card.card_data.energy_provides != "" else card.card_data.energy_type
		if energy_type == "" or seen_types.has(energy_type):
			continue
		seen_types[energy_type] = true
		result.append(card)
	return result


func get_empty_interaction_message(card: CardInstance, state: GameState) -> String:
	var player: PlayerState = state.players[card.owner_index]
	if _get_unique_basic_energy_cards(player.deck).is_empty():
		return "牌库里没有可附着的基本能量，幻象之门没有附着任何能量。"
	return ""


func get_description() -> String:
	return "If you have enough cards in the Lost Zone, attach up to 2 Basic Energy cards of different types from your deck to your Pokemon."
