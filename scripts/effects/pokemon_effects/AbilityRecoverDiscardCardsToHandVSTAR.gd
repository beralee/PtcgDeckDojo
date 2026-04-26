class_name AbilityRecoverDiscardCardsToHandVSTAR
extends BaseEffect

const STEP_ID := "recover_cards"

var recover_count: int = 2
var card_type_filter: String = "Item"


func _init(count: int = 2, filter_type: String = "Item") -> void:
	recover_count = count
	card_type_filter = filter_type


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var pi: int = top.owner_index
	if state.current_player_index != pi:
		return false
	if state.vstar_power_used[pi]:
		return false
	return not _get_recoverable_cards(state.players[pi]).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = _get_recoverable_cards(player)
	if items.is_empty():
		return []
	var labels: Array[String] = []
	for discard_card: CardInstance in items:
		labels.append(discard_card.card_data.name)
	return [{
		"id": STEP_ID,
		"title": "Choose up to %d %s card(s) from your discard pile" % [recover_count, card_type_filter],
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": mini(recover_count, items.size()),
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
	var pi: int = top.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get(STEP_ID, [])
	var selected_cards: Array[CardInstance] = []
	var has_explicit_selection: bool = ctx.has(STEP_ID)
	var recoverable: Array = _get_recoverable_cards(player)

	for entry: Variant in selected_raw:
		if not (entry is CardInstance):
			continue
		var selected := entry as CardInstance
		if selected not in recoverable or selected in selected_cards:
			continue
		selected_cards.append(selected)
		if selected_cards.size() >= recover_count:
			break

	if selected_cards.is_empty() and not has_explicit_selection:
		for i: int in mini(recover_count, recoverable.size()):
			selected_cards.append(recoverable[i])

	for selected: CardInstance in selected_cards:
		player.discard_pile.erase(selected)
		player.hand.append(selected)

	state.vstar_power_used[pi] = true


func _get_recoverable_cards(player: PlayerState) -> Array:
	var result: Array = []
	for card: CardInstance in player.discard_pile:
		if card == null or card.card_data == null:
			continue
		if card.card_data.card_type == card_type_filter:
			result.append(card)
	return result


func get_description() -> String:
	return "VSTAR Power: put up to %d %s card(s) from your discard pile into your hand." % [recover_count, card_type_filter]
