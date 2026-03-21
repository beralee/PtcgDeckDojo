## Reveal prizes and take a Basic Pokemon from them, replacing it with a Heavy Ball copy.
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

	var replacement_items: Array = []
	var replacement_labels: Array[String] = []
	for hand_card: CardInstance in player.hand:
		if hand_card == card:
			continue
		replacement_items.append(hand_card)
		replacement_labels.append(hand_card.card_data.name)
	for prize_basic: CardInstance in prize_items:
		replacement_items.append(prize_basic)
		replacement_labels.append("%s（拿到手牌后放回）" % prize_basic.card_data.name)

	return [
		{
			"id": "chosen_prize_basic",
			"title": "选择1张奖赏卡中的基础宝可梦加入手牌",
			"items": prize_items,
			"labels": prize_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
		{
			"id": "replacement_prize_card",
			"title": "选择1张手牌放回奖赏卡",
			"items": replacement_items,
			"labels": replacement_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
	]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("chosen_prize_basic", [])
	var replacement_raw: Array = ctx.get("replacement_prize_card", [])

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

	player.prizes.erase(selected_prize)
	selected_prize.face_up = true
	player.hand.append(selected_prize)

	var replacement: CardInstance = null
	if not replacement_raw.is_empty() and replacement_raw[0] is CardInstance:
		var candidate: CardInstance = replacement_raw[0]
		if candidate == selected_prize or (candidate in player.hand and candidate != card):
			replacement = candidate

	if replacement == null:
		for hand_card: CardInstance in player.hand:
			if hand_card != card:
				replacement = hand_card
				break
	if replacement == null:
		return

	player.hand.erase(replacement)
	replacement.face_up = false
	player.prizes.append(replacement)
	_shuffle_cards(player.prizes)


func _shuffle_cards(cards: Array[CardInstance]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(cards.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp: CardInstance = cards[i]
		cards[i] = cards[j]
		cards[j] = temp


func get_description() -> String:
	return "查看奖赏卡。若其中有基础宝可梦，选择1张加入手牌，再从手牌选1张放回奖赏卡。"
