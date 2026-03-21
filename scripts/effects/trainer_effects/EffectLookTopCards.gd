## Generic effect for cards that look at the top N cards, then pick matches.
class_name EffectLookTopCards
extends BaseEffect

## Number of cards to look at. 0 means the entire deck.
var look_count: int = 7
## Filter: "Pokemon", "Supporter", "Evolution", "Basic", "" for any.
var card_filter: String = ""
## Maximum number of cards to pick.
var pick_count: int = 1


func _init(look: int = 7, filter: String = "", pick: int = 1) -> void:
	look_count = look
	card_filter = filter
	pick_count = pick


func can_execute(card: CardInstance, state: GameState) -> bool:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	# Effects that "look at" cards are generally playable as long as the deck is not empty.
	# They may whiff if no matching cards are found.
	return not player.deck.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var check_count: int = mini(look_count, player.deck.size()) if look_count > 0 else player.deck.size()

	var items: Array = []
	var labels: Array[String] = []
	for idx: int in check_count:
		var deck_card: CardInstance = player.deck[idx]
		if _matches_filter(deck_card):
			items.append(deck_card)
			labels.append(deck_card.card_data.name)

	var max_select: int = mini(pick_count, items.size())
	return [{
		"id": "look_top_cards",
		"title": "Choose up to %d matching card(s)" % pick_count,
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": max_select,
		"allow_cancel": true,
	}]


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(_targets)

	var picked: Array[CardInstance] = []
	var selected_raw: Array = ctx.get("look_top_cards", [])
	for selected: Variant in selected_raw:
		if selected is CardInstance and selected in player.deck and _matches_filter(selected):
			picked.append(selected)
			if picked.size() >= pick_count:
				break

	if picked.is_empty():
		var check_count: int = mini(look_count, player.deck.size()) if look_count > 0 else player.deck.size()
		for idx: int in check_count:
			if picked.size() >= pick_count:
				break
			var deck_card: CardInstance = player.deck[idx]
			if _matches_filter(deck_card):
				picked.append(deck_card)

	for picked_card: CardInstance in picked:
		player.deck.erase(picked_card)
		picked_card.face_up = true
		player.hand.append(picked_card)

	player.shuffle_deck()


func _matches_filter(card: CardInstance) -> bool:
	if card_filter == "":
		return true
	var cd: CardData = card.card_data
	match card_filter:
		"Pokemon":
			return cd.is_pokemon()
		"Supporter":
			return cd.card_type == "Supporter"
		"Evolution":
			return cd.is_evolution_pokemon()
		"Basic":
			return cd.is_basic_pokemon()
		"Item":
			return cd.card_type == "Item"
		"Tool":
			return cd.card_type == "Tool"
		_:
			return cd.card_type == card_filter


func get_description() -> String:
	var filter_name := "card"
	match card_filter:
		"Pokemon":
			filter_name = "Pokemon"
		"Supporter":
			filter_name = "Supporter"
		"Evolution":
			filter_name = "Evolution Pokemon"
		"Basic":
			filter_name = "Basic Pokemon"
		"Item":
			filter_name = "Item"
		"Tool":
			filter_name = "Pokemon Tool"
		_:
			if card_filter != "":
				filter_name = card_filter

	if look_count > 0:
		return "Look at the top %d cards of your deck, then choose up to %d %s card(s)." % [
			look_count,
			pick_count,
			filter_name,
		]
	return "Search your deck for up to %d %s card(s)." % [pick_count, filter_name]
