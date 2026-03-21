class_name AbilityMillDeckRecoverToHand
extends BaseEffect

var mill_count: int = 7
var recover_count: int = 2
var is_vstar_power: bool = true


func _init(mill: int = 7, recover: int = 2, vstar: bool = true) -> void:
	mill_count = mill
	recover_count = recover
	is_vstar_power = vstar


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	if is_vstar_power and state.vstar_power_used[top.owner_index]:
		return false
	return not state.players[top.owner_index].deck.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var preview: Array[CardInstance] = []
	for idx: int in mini(mill_count, player.deck.size()):
		preview.append(player.deck[idx])
	var items: Array = preview.duplicate()
	var labels: Array[String] = []
	for entry: CardInstance in items:
		labels.append(entry.card_data.name)
	return [{
		"id": "recover_cards",
		"title": "Choose up to %d card(s) to recover after milling" % recover_count,
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
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var pi: int = top.owner_index
	var player: PlayerState = state.players[pi]

	var milled: Array[CardInstance] = []
	for _i: int in mini(mill_count, player.deck.size()):
		var milled_card: CardInstance = player.deck.pop_front()
		milled_card.face_up = true
		player.discard_pile.append(milled_card)
		milled.append(milled_card)

	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("recover_cards", [])
	var selected_cards: Array[CardInstance] = []
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.discard_pile and entry in milled:
			selected_cards.append(entry)
			if selected_cards.size() >= recover_count:
				break

	for selected: CardInstance in selected_cards:
		player.discard_pile.erase(selected)
		player.hand.append(selected)

	if is_vstar_power:
		state.vstar_power_used[pi] = true


func get_description() -> String:
	return "Mill cards from the top of your deck, then recover cards to your hand."
