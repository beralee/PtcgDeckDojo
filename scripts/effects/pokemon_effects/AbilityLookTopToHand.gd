class_name AbilityLookTopToHand
extends BaseEffect

const USED_FLAG_TYPE := "ability_look_top_to_hand_used"

var look_count: int = 2
var filter_type: String = ""
var active_only: bool = false
var shuffle_remaining: bool = false
var bottom_remaining: bool = true


func _init(
	look: int = 2,
	filter: String = "",
	require_active: bool = false,
	shuffle_rest: bool = false,
	bottom_rest: bool = true
) -> void:
	look_count = look
	filter_type = filter
	active_only = require_active
	shuffle_remaining = shuffle_rest
	bottom_remaining = bottom_rest


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	if active_only and state.players[top.owner_index].active_pokemon != pokemon:
		return false
	for effect_data: Dictionary in pokemon.effects:
		if effect_data.get("type", "") == USED_FLAG_TYPE and effect_data.get("turn", -1) == state.turn_number:
			return false
	return not state.players[top.owner_index].deck.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for idx: int in mini(look_count, player.deck.size()):
		var deck_card: CardInstance = player.deck[idx]
		if _matches_filter(deck_card):
			items.append(deck_card)
			labels.append(deck_card.card_data.name)
	return [{
		"id": "look_top_pick",
		"title": "Choose up to 1 card from the top %d" % look_count,
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": mini(1, items.size()),
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
	var player: PlayerState = state.players[top.owner_index]
	var look_cards: Array[CardInstance] = []
	for idx: int in mini(look_count, player.deck.size()):
		look_cards.append(player.deck[idx])

	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("look_top_pick", [])
	var chosen: CardInstance = null
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance and selected_raw[0] in look_cards and _matches_filter(selected_raw[0]):
		chosen = selected_raw[0]

	if chosen != null:
		player.deck.erase(chosen)
		player.hand.append(chosen)
		look_cards.erase(chosen)

	for remaining: CardInstance in look_cards:
		player.deck.erase(remaining)
	if bottom_remaining:
		for remaining: CardInstance in look_cards:
			player.deck.append(remaining)
	elif shuffle_remaining:
		for remaining: CardInstance in look_cards:
			player.deck.append(remaining)
		player.shuffle_deck()

	pokemon.effects.append({"type": USED_FLAG_TYPE, "turn": state.turn_number})


func _matches_filter(card: CardInstance) -> bool:
	if filter_type == "":
		return true
	return card.card_data.card_type == filter_type


func get_description() -> String:
	return "Look at the top cards of your deck and add one to your hand."
