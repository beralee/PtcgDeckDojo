class_name EffectCyllene
extends BaseEffect

var coin_flipper: CoinFlipper
var _pending_heads_count: int = -1


func _init(flipper: CoinFlipper = null) -> void:
	coin_flipper = flipper if flipper != null else CoinFlipper.new()


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not state.players[card.owner_index].discard_pile.is_empty()


func get_preview_interaction_steps(_card: CardInstance, _state: GameState) -> Array[Dictionary]:
	return [{
		"id": "coin_flip_preview",
		"title": "Flip 2 coins",
		"wait_for_coin_animation": true,
		"preview_only": true,
	}]


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	_pending_heads_count = _flip_heads_count()
	if _pending_heads_count <= 0:
		return []

	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for discard_card: CardInstance in player.discard_pile:
		items.append(discard_card)
		labels.append(discard_card.card_data.name)

	return [{
		"id": "discard_to_top",
		"title": "Choose up to %d card(s) to put on top of your deck" % _pending_heads_count,
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": mini(_pending_heads_count, items.size()),
		"allow_cancel": false,
		"wait_for_coin_animation": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	if _pending_heads_count < 0:
		_pending_heads_count = _flip_heads_count()
	var player: PlayerState = state.players[card.owner_index]
	if _pending_heads_count <= 0:
		_pending_heads_count = -1
		return

	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("discard_to_top", [])
	var selected_cards: Array[CardInstance] = []
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.discard_pile:
			selected_cards.append(entry)
			if selected_cards.size() >= _pending_heads_count:
				break

	var ordered_cards: Array[CardInstance] = selected_cards.duplicate()
	ordered_cards.reverse()
	for picked: CardInstance in ordered_cards:
		player.discard_pile.erase(picked)
		picked.face_up = false
		player.deck.push_front(picked)

	_pending_heads_count = -1


func _flip_heads_count() -> int:
	var heads := 0
	for _i: int in 2:
		if coin_flipper.flip():
			heads += 1
	return heads


func get_description() -> String:
	return "Flip 2 coins. Put up to 2 cards from your discard pile on top of your deck for each heads."
