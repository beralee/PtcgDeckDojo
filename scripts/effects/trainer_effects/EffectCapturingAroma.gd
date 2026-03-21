## Capturing Aroma - flip a coin, then search for either a Basic or Evolution Pokemon.
class_name EffectCapturingAroma
extends BaseEffect

var _pending_flip_heads: bool = true


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	for deck_card: CardInstance in player.deck:
		if deck_card.card_data.is_pokemon():
			return true
	return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	_pending_flip_heads = CoinFlipper.new().flip()

	var items: Array = []
	var labels: Array[String] = []
	for deck_card: CardInstance in player.deck:
		var cd: CardData = deck_card.card_data
		if _pending_flip_heads and cd.is_evolution_pokemon():
			items.append(deck_card)
			labels.append("%s (%s)" % [cd.name, cd.stage])
		elif not _pending_flip_heads and cd.is_basic_pokemon():
			items.append(deck_card)
			labels.append("%s (基础)" % cd.name)

	var result_label: String = "正面，选择1张进化宝可梦" if _pending_flip_heads else "反面，选择1张基础宝可梦"
	if items.is_empty():
		return [{
			"id": "flip_result",
			"title": "捕获香氛投币结果：%s\n牌库中没有符合条件的宝可梦" % result_label,
			"items": ["继续"],
			"labels": ["继续"],
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		}]

	return [{
		"id": "searched_pokemon",
		"title": "捕获香氛投币结果：%s" % result_label,
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("searched_pokemon", [])
	if selected_raw.is_empty() or not selected_raw[0] is CardInstance:
		player.shuffle_deck()
		return

	var found: CardInstance = selected_raw[0]
	if found not in player.deck:
		player.shuffle_deck()
		return

	var cd: CardData = found.card_data
	var valid: bool = (_pending_flip_heads and cd.is_evolution_pokemon()) or (not _pending_flip_heads and cd.is_basic_pokemon())
	if not valid:
		player.shuffle_deck()
		return

	player.deck.erase(found)
	found.face_up = true
	player.hand.append(found)
	player.shuffle_deck()


func get_description() -> String:
	return "投币：正面检索进化宝可梦，反面检索基础宝可梦。"
