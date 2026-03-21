class_name AbilityAttachFromDeck
extends BaseEffect

const ASSIGNMENT_STEP_ID := "energy_assignments"
const USED_KEY := "ability_attach_from_deck_used"
const EVOLVE_TRIGGERED_KEY := "ability_attach_from_deck_evolved"

var energy_type: String = ""
var max_count: int = 1
var target_filter: String = "own"
var on_evolve_only: bool = false
var once_per_turn: bool = false


func _init(
	e_type: String = "",
	count: int = 1,
	t_filter: String = "own",
	evolve_only: bool = false,
	once: bool = false
) -> void:
	energy_type = e_type
	max_count = count
	target_filter = t_filter
	on_evolve_only = evolve_only
	once_per_turn = once


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false

	var player_index: int = top.owner_index

	if once_per_turn:
		for effect: Dictionary in pokemon.effects:
			if effect.get("type") == USED_KEY and effect.get("turn") == state.turn_number:
				return false

	if on_evolve_only:
		if pokemon.turn_evolved != state.turn_number:
			return false
		for effect: Dictionary in pokemon.effects:
			if effect.get("type") == EVOLVE_TRIGGERED_KEY and effect.get("turn") == state.turn_number:
				return false

	var player: PlayerState = state.players[player_index]
	return _has_matching_energy(player.deck)


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var matching_energy_cards: Array[CardInstance] = _collect_matching_energy_cards(player.deck)
	if matching_energy_cards.is_empty():
		return []

	var target_items: Array = _build_attach_target_items(player, card)
	if target_items.is_empty():
		return []

	var energy_labels: Array[String] = []
	for energy_card: CardInstance in matching_energy_cards:
		energy_labels.append(energy_card.card_data.name)

	var target_labels: Array[String] = _build_attach_target_labels(target_items)
	var min_assignments := 0
	if not on_evolve_only and target_filter == "own_one":
		min_assignments = 1

	return [build_card_assignment_step(
		ASSIGNMENT_STEP_ID,
		"选择能量并分配到己方宝可梦",
		matching_energy_cards,
		energy_labels,
		target_items,
		target_labels,
		min_assignments,
		mini(max_count, matching_energy_cards.size()),
		true
	)]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return

	var player_index: int = top.owner_index
	var player: PlayerState = state.players[player_index]
	var context: Dictionary = get_interaction_context(targets)
	var assignments: Array[Dictionary] = _resolve_assignment_entries(pokemon, player, targets, state, context)

	if assignments.is_empty() and context.has(ASSIGNMENT_STEP_ID):
		_mark_usage(pokemon, state)
		return
	if assignments.is_empty():
		return

	for assignment: Dictionary in assignments:
		var energy_card: CardInstance = assignment.get("source")
		var target_slot: PokemonSlot = assignment.get("target")
		if energy_card == null or target_slot == null:
			continue
		player.deck.erase(energy_card)
		energy_card.face_up = true
		target_slot.attached_energy.append(energy_card)

	player.shuffle_deck()
	_mark_usage(pokemon, state)


func _mark_usage(pokemon: PokemonSlot, state: GameState) -> void:
	if on_evolve_only:
		pokemon.effects.append({
			"type": EVOLVE_TRIGGERED_KEY,
			"turn": state.turn_number,
		})
	if once_per_turn:
		pokemon.effects.append({
			"type": USED_KEY,
			"turn": state.turn_number,
		})


func _has_matching_energy(deck: Array[CardInstance]) -> bool:
	for card: CardInstance in deck:
		if _matches_energy(card):
			return true
	return false


func _matches_energy(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false

	var cd: CardData = card.card_data
	if not cd.is_energy():
		return false

	if energy_type == "":
		return true
	if energy_type == "Special Energy":
		return cd.card_type == "Special Energy"
	if energy_type == "Basic Energy":
		return cd.card_type == "Basic Energy"
	return cd.energy_provides == energy_type or cd.energy_type == energy_type


func _collect_matching_energy_cards(deck: Array[CardInstance]) -> Array[CardInstance]:
	var matching_cards: Array[CardInstance] = []
	for card: CardInstance in deck:
		if _matches_energy(card):
			matching_cards.append(card)
	return matching_cards


func _build_attach_target_items(player: PlayerState, card: CardInstance) -> Array:
	var items: Array = []
	match target_filter:
		"self":
			for slot: PokemonSlot in player.get_all_pokemon():
				if slot.get_top_card() == card:
					items.append(slot)
					break
		"own", "own_one":
			for slot: PokemonSlot in player.get_all_pokemon():
				items.append(slot)
	return items


func _build_attach_target_labels(items: Array) -> Array[String]:
	var labels: Array[String] = []
	for item: Variant in items:
		if item is PokemonSlot:
			var slot: PokemonSlot = item as PokemonSlot
			labels.append("%s (HP %d/%d)" % [
				slot.get_pokemon_name(),
				slot.get_remaining_hp(),
				slot.get_max_hp(),
			])
	return labels


func _resolve_assignment_entries(
	pokemon: PokemonSlot,
	player: PlayerState,
	targets: Array,
	state: GameState,
	context: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var selected_assignments: Array = context.get(ASSIGNMENT_STEP_ID, [])
	var has_explicit_assignments: bool = context.has(ASSIGNMENT_STEP_ID)
	var used_sources: Array[CardInstance] = []

	for entry: Variant in selected_assignments:
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		var source: Variant = assignment.get("source")
		var target: Variant = assignment.get("target")
		if not (source is CardInstance) or not (target is PokemonSlot):
			continue

		var source_card: CardInstance = source as CardInstance
		var target_slot: PokemonSlot = target as PokemonSlot
		if source_card not in player.deck or not _matches_energy(source_card):
			continue
		if source_card in used_sources:
			continue
		if not _is_valid_target(pokemon, player, target_slot):
			continue

		used_sources.append(source_card)
		result.append({
			"source": source_card,
			"target": target_slot,
		})
		if result.size() >= max_count:
			break

	if not result.is_empty() or has_explicit_assignments:
		return result

	var fallback_sources: Array[CardInstance] = []
	for card: CardInstance in player.deck:
		if _matches_energy(card):
			fallback_sources.append(card)
			if fallback_sources.size() >= max_count:
				break
	if fallback_sources.is_empty():
		return []

	var fallback_targets: Array[PokemonSlot] = _resolve_targets(pokemon, player, targets, state)
	if fallback_targets.is_empty():
		return []

	for i: int in fallback_sources.size():
		var fallback_target: PokemonSlot = fallback_targets[mini(i, fallback_targets.size() - 1)]
		if not _is_valid_target(pokemon, player, fallback_target):
			continue
		result.append({
			"source": fallback_sources[i],
			"target": fallback_target,
		})

	return result


func _is_valid_target(pokemon: PokemonSlot, player: PlayerState, target_slot: PokemonSlot) -> bool:
	if target_slot == null:
		return false

	match target_filter:
		"self":
			return target_slot == pokemon
		"own", "own_one":
			return target_slot in player.get_all_pokemon()
		_:
			return false


func _resolve_targets(
	pokemon: PokemonSlot,
	player: PlayerState,
	targets: Array,
	_state: GameState
) -> Array[PokemonSlot]:
	var result: Array[PokemonSlot] = []

	match target_filter:
		"self":
			result.append(pokemon)
		"own_one":
			if not targets.is_empty() and targets[0] is PokemonSlot:
				result.append(targets[0] as PokemonSlot)
			else:
				result.append(pokemon)
		"own":
			if not targets.is_empty():
				for target: Variant in targets:
					if target is PokemonSlot:
						result.append(target as PokemonSlot)
			elif on_evolve_only:
				for _i: int in max_count:
					result.append(pokemon)
			else:
				result.append_array(player.get_all_pokemon())
		_:
			result.append_array(player.get_all_pokemon())

	return result


func get_description() -> String:
	var type_str: String = energy_type if energy_type != "" else "any"
	var filter_str: String = ""
	match target_filter:
		"self":
			filter_str = "this Pokemon"
		"own_one":
			filter_str = "1 of your Pokemon"
		_:
			filter_str = "your Pokemon"

	var trigger_str: String = "When you evolve this Pokemon, " if on_evolve_only else ""
	var limit_str: String = " (once during your turn)" if once_per_turn else ""
	return "%sattach up to %d %s Energy cards from your deck to %s%s." % [
		trigger_str,
		max_count,
		type_str,
		filter_str,
		limit_str
	]
