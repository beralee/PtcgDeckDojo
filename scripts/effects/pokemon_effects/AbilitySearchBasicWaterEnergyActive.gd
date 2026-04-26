class_name AbilitySearchBasicWaterEnergyActive
extends BaseEffect

const USED_KEY := "ability_search_basic_water_energy_active_used"
const STEP_ID := "search_water_energy"

var search_count: int = 2


func _init(count: int = 2) -> void:
	search_count = count


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	if state.current_player_index != top.owner_index:
		return false
	var player: PlayerState = state.players[top.owner_index]
	if player.active_pokemon != pokemon:
		return false
	for effect_data: Dictionary in pokemon.effects:
		if effect_data.get("type", "") == USED_KEY and int(effect_data.get("turn", -1)) == state.turn_number:
			return false
	return not player.deck.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = _get_basic_water_energy(player.deck)
	if items.is_empty():
		return [build_empty_search_resolution_step("牌库里没有基本水能量。你仍可以使用这个特性。")]

	var labels: Array[String] = []
	for energy: CardInstance in items:
		labels.append(energy.card_data.name)
	return [{
		"id": STEP_ID,
		"title": "选择最多%d张基本水能量加入手牌" % search_count,
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": mini(search_count, items.size()),
		"allow_cancel": true,
	}]


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
	var selected_raw: Array = ctx.get(STEP_ID, [])
	var has_explicit_selection: bool = ctx.has(STEP_ID)

	var selected: Array[CardInstance] = []
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.deck and _is_basic_water_energy(entry) and entry not in selected:
			selected.append(entry)
			if selected.size() >= search_count:
				break

	if selected.is_empty() and not has_explicit_selection:
		for energy: CardInstance in _get_basic_water_energy(player.deck):
			selected.append(energy)
			if selected.size() >= search_count:
				break

	_move_public_cards_to_hand_with_log(
		state,
		top.owner_index,
		selected,
		top,
		"ability",
		"search_to_hand",
		["基本水能量"]
	)
	player.shuffle_deck()
	pokemon.effects.append({"type": USED_KEY, "turn": state.turn_number})


func _get_basic_water_energy(cards: Array[CardInstance]) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for card: CardInstance in cards:
		if _is_basic_water_energy(card):
			result.append(card)
	return result


func _is_basic_water_energy(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	return card.card_data.card_type == "Basic Energy" and card.card_data.energy_provides == "W"


func get_description() -> String:
	return "战栗冷气：在战斗场时，每回合1次，从牌库选择最多%d张基本水能量给对手看过后加入手牌并重洗牌库。" % search_count
