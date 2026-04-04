## Reveal prizes and swap Hisuian Heavy Ball itself into the prize cards.
class_name EffectHisuianHeavyBall
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not player.prizes.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var prize_items: Array = []
	var prize_labels: Array[String] = []
	for prize_card: CardInstance in player.prizes:
		if prize_card.card_data != null and prize_card.card_data.is_basic_pokemon():
			prize_items.append(prize_card)
			prize_labels.append(prize_card.card_data.name)
	if prize_items.is_empty():
		return []

	return [{
		"id": "chosen_prize_basic",
		"title": "Choose 1 Basic Pokemon from your Prize cards",
		"items": prize_items,
		"labels": prize_labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("chosen_prize_basic", [])

	var selected_prize: CardInstance = null
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance:
		var candidate: CardInstance = selected_raw[0]
		if candidate in player.prizes and candidate.card_data != null and candidate.card_data.is_basic_pokemon():
			selected_prize = candidate

	if selected_prize == null:
		for prize_card: CardInstance in player.prizes:
			if prize_card.card_data != null and prize_card.card_data.is_basic_pokemon():
				selected_prize = prize_card
				break
	if selected_prize == null:
		return

	selected_prize = player.take_prize_card(selected_prize)
	if selected_prize == null:
		return

	player.hand.erase(card)
	card.face_up = false
	player.prizes.append(card)
	_shuffle_cards(player.prizes)
	player.reset_prize_layout()


func _shuffle_cards(cards: Array[CardInstance]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(cards.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp: CardInstance = cards[i]
		cards[i] = cards[j]
		cards[j] = temp


func get_description() -> String:
	return "Look at your Prize cards. If you find a Basic Pokemon there, put it into your hand and shuffle Hisuian Heavy Ball into your Prize cards."
