class_name AbilityMoveBasicEnergyToOwnPokemon
extends BaseEffect

const USED_FLAG_TYPE := "ability_move_basic_energy_to_own_pokemon_used"
const STEP_ID := "energy_assignment"


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	if state.current_player_index != top.owner_index:
		return false
	for effect_data: Dictionary in pokemon.effects:
		if effect_data.get("type", "") == USED_FLAG_TYPE and effect_data.get("turn", -1) == state.turn_number:
			return false
	var player: PlayerState = state.players[top.owner_index]
	if player.get_all_pokemon().size() < 2:
		return false
	for energy: CardInstance in pokemon.attached_energy:
		if energy != null and energy.card_data != null and energy.card_data.card_type == "Basic Energy":
			return true
	return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null or card.owner_index < 0 or card.owner_index >= state.players.size():
		return []
	var player: PlayerState = state.players[card.owner_index]
	var source_slot: PokemonSlot = _find_slot_for_card(player, card)
	if source_slot == null:
		return []

	var energy_items: Array = []
	var energy_labels: Array[String] = []
	for energy: CardInstance in source_slot.attached_energy:
		if energy == null or energy.card_data == null or energy.card_data.card_type != "Basic Energy":
			continue
		energy_items.append(energy)
		energy_labels.append(energy.card_data.name)
	if energy_items.is_empty():
		return []

	var target_items: Array = []
	var target_labels: Array[String] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null or slot == source_slot:
			continue
		target_items.append(slot)
		target_labels.append(slot.get_pokemon_name())
	if target_items.is_empty():
		return []

	return [build_card_assignment_step(
		STEP_ID,
		"Choose 1 Basic Energy to move to another Pokemon",
		energy_items,
		energy_labels,
		target_items,
		target_labels,
		1,
		1,
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
	var player: PlayerState = state.players[top.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var assignments: Array = ctx.get(STEP_ID, [])
	if assignments.is_empty():
		return
	var assignment_raw: Variant = assignments[0]
	if not (assignment_raw is Dictionary):
		return
	var assignment: Dictionary = assignment_raw
	var source_raw: Variant = assignment.get("source")
	var target_raw: Variant = assignment.get("target")
	if not (source_raw is CardInstance) or not (target_raw is PokemonSlot):
		return
	var energy: CardInstance = source_raw as CardInstance
	var target: PokemonSlot = target_raw as PokemonSlot
	if energy.card_data == null or energy.card_data.card_type != "Basic Energy":
		return
	if target not in player.get_all_pokemon() or target == pokemon:
		return
	if energy not in pokemon.attached_energy:
		return
	pokemon.attached_energy.erase(energy)
	target.attached_energy.append(energy)
	pokemon.effects.append({
		"type": USED_FLAG_TYPE,
		"turn": state.turn_number,
	})


func _find_slot_for_card(player: PlayerState, card: CardInstance) -> PokemonSlot:
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and slot.get_top_card() == card:
			return slot
	return null


func get_description() -> String:
	return "Once during your turn, move a Basic Energy from this Pokemon to another of your Pokemon."
