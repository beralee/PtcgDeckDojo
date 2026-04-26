class_name AbilityMetalMaker
extends BaseEffect

const ASSIGNMENT_STEP_ID := "metal_maker_assignments"
const USED_KEY: String = "ability_metal_maker_used"

var look_count: int = 4
var energy_type: String = "M"


func _init(look: int = 4, e_type: String = "M") -> void:
	look_count = look
	energy_type = e_type


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or state == null:
		return false
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var player_index: int = top.owner_index
	if state.current_player_index != player_index:
		return false

	for effect: Dictionary in pokemon.effects:
		if effect.get("type") == USED_KEY and effect.get("turn") == state.turn_number:
			return false

	var player: PlayerState = state.players[player_index]
	return not player.deck.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null or state == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	var viewed_cards: Array[CardInstance] = _peek_top_cards(player)
	var energy_cards: Array[CardInstance] = _filter_matching_energy(viewed_cards)
	if energy_cards.is_empty():
		return [build_empty_search_resolution_step_with_view_label(
			"Metal Maker: no Basic Metal Energy found in the top %d cards. You may still view them." % look_count,
			"View cards"
		)]

	var target_items: Array = []
	target_items.append_array(player.get_all_pokemon())
	if target_items.is_empty():
		return []

	var energy_labels: Array[String] = []
	for energy_card: CardInstance in energy_cards:
		energy_labels.append(energy_card.card_data.name if energy_card.card_data != null else "")

	var target_labels: Array[String] = []
	for item: Variant in target_items:
		var slot := item as PokemonSlot
		if slot == null:
			target_labels.append("")
			continue
		target_labels.append("%s (%d/%d)" % [
			slot.get_pokemon_name(),
			slot.get_remaining_hp(),
			slot.get_max_hp(),
		])

	return [build_card_assignment_step(
		ASSIGNMENT_STEP_ID,
		"Metal Maker: assign any Basic Metal Energy from the top %d cards" % look_count,
		energy_cards,
		energy_labels,
		target_items,
		target_labels,
		0,
		energy_cards.size(),
		true
	)]


func get_followup_interaction_steps(
	card: CardInstance,
	state: GameState,
	resolved_context: Dictionary
) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	if card == null or state == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	return [build_readonly_card_preview_step(
		"Metal Maker: viewed cards",
		_peek_top_cards(player),
		"Close and continue"
	)]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	if pokemon == null or state == null:
		return
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var player_index: int = top.owner_index
	var player: PlayerState = state.players[player_index]
	if player.deck.is_empty():
		return

	var take: int = mini(look_count, player.deck.size())
	var viewed: Array[CardInstance] = []
	for _i: int in range(take):
		viewed.append(player.deck.pop_front())

	var energies: Array[CardInstance] = []
	var others: Array[CardInstance] = []
	for card: CardInstance in viewed:
		if _matches_energy(card):
			energies.append(card)
		else:
			others.append(card)

	var context: Dictionary = get_interaction_context(targets)
	var assignments: Array[Dictionary] = _resolve_assignments(player, energies, targets, context)
	var attached_sources: Array[CardInstance] = []
	for assignment: Dictionary in assignments:
		var energy_card: CardInstance = assignment.get("source")
		var target_slot: PokemonSlot = assignment.get("target")
		if energy_card == null or target_slot == null:
			continue
		if energy_card in attached_sources:
			continue
		energy_card.face_up = true
		target_slot.attached_energy.append(energy_card)
		attached_sources.append(energy_card)

	var return_cards: Array[CardInstance] = []
	for energy_card: CardInstance in energies:
		if energy_card not in attached_sources:
			return_cards.append(energy_card)
	return_cards.append_array(others)
	_shuffle_cards(return_cards)
	for card: CardInstance in return_cards:
		card.face_up = false
		player.deck.append(card)

	pokemon.effects.append({
		"type": USED_KEY,
		"turn": state.turn_number,
	})


func _matches_energy(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	var cd: CardData = card.card_data
	if cd.card_type != "Basic Energy":
		return false
	return cd.energy_provides == energy_type or cd.energy_type == energy_type


func _peek_top_cards(player: PlayerState) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	if player == null:
		return cards
	for idx: int in range(mini(look_count, player.deck.size())):
		cards.append(player.deck[idx])
	return cards


func _filter_matching_energy(cards: Array[CardInstance]) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for card: CardInstance in cards:
		if _matches_energy(card):
			result.append(card)
	return result


func _resolve_assignments(
	player: PlayerState,
	energies: Array[CardInstance],
	targets: Array,
	context: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var selected_raw: Array = context.get(ASSIGNMENT_STEP_ID, [])
	var has_explicit_assignments: bool = context.has(ASSIGNMENT_STEP_ID)
	var used_sources: Array[CardInstance] = []
	var valid_targets: Array[PokemonSlot] = player.get_all_pokemon()

	for entry: Variant in selected_raw:
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		var source_variant: Variant = assignment.get("source")
		var target_variant: Variant = assignment.get("target")
		if not (source_variant is CardInstance) or not (target_variant is PokemonSlot):
			continue
		var source: CardInstance = source_variant as CardInstance
		var target: PokemonSlot = target_variant as PokemonSlot
		if source not in energies or source in used_sources:
			continue
		if target not in valid_targets:
			continue
		used_sources.append(source)
		result.append({
			"source": source,
			"target": target,
		})

	if has_explicit_assignments:
		return result

	var legacy_targets: Array[PokemonSlot] = []
	for target_variant: Variant in targets:
		if target_variant is PokemonSlot and target_variant in valid_targets:
			legacy_targets.append(target_variant as PokemonSlot)
	if legacy_targets.is_empty():
		legacy_targets.append_array(valid_targets)
	if legacy_targets.is_empty():
		return result

	for i: int in range(energies.size()):
		var target_index: int = 0 if legacy_targets.size() == 1 else mini(i, legacy_targets.size() - 1)
		result.append({
			"source": energies[i],
			"target": legacy_targets[target_index],
		})
	return result


func _shuffle_cards(cards: Array[CardInstance]) -> void:
	if cards.size() < 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i: int in range(cards.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: CardInstance = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp


func get_description() -> String:
	return "Metal Maker: look at the top %d cards of your deck and attach any Basic %s Energy you find to your Pokemon. Put the other cards on the bottom of your deck." % [
		look_count,
		energy_type,
	]
