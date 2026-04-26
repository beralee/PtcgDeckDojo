class_name EffectMissFortuneSisters
extends BaseEffect

const LOOK_COUNT := 5


func can_execute(card: CardInstance, state: GameState) -> bool:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	return not opponent.deck.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var looked_cards: Array[CardInstance] = _get_looked_cards(opponent)
	if looked_cards.is_empty():
		return []
	var item_cards: Array = []
	var item_labels: Array[String] = []
	var reveal_labels: Array[String] = []
	for deck_card: CardInstance in looked_cards:
		reveal_labels.append(deck_card.card_data.name if deck_card.card_data != null else "")
		if deck_card.card_data != null and deck_card.card_data.card_type == "Item":
			item_cards.append(deck_card)
			item_labels.append(deck_card.card_data.name)
	var title: String = "查看对手牌库上方%d张：%s" % [looked_cards.size(), ", ".join(reveal_labels)]
	if item_cards.is_empty():
		return [{
			"id": "miss_fortune_continue",
			"title": "%s\n其中没有物品卡。" % title,
			"items": ["continue"],
			"labels": ["继续"],
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
		}]
	return [{
		"id": "discard_item_cards",
		"title": "%s\n选择任意数量的物品放入弃牌区" % title,
		"items": item_cards,
		"labels": item_labels,
		"min_select": 0,
		"max_select": item_cards.size(),
		"allow_cancel": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var looked_cards: Array[CardInstance] = _get_looked_cards(opponent)
	if looked_cards.is_empty():
		return
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("discard_item_cards", [])
	for entry: Variant in selected_raw:
		if not (entry is CardInstance):
			continue
		var deck_card: CardInstance = entry
		if deck_card in opponent.deck and deck_card in looked_cards and deck_card.card_data != null and deck_card.card_data.card_type == "Item":
			opponent.deck.erase(deck_card)
			opponent.discard_card(deck_card)
	opponent.shuffle_deck()


func get_description() -> String:
	return "查看对手牌库上方5张卡牌，选择其中任意数量的物品，放于弃牌区。将剩余的卡牌放回牌库并重洗牌库。"


func _get_looked_cards(player: PlayerState) -> Array[CardInstance]:
	var looked_cards: Array[CardInstance] = []
	var count: int = mini(LOOK_COUNT, player.deck.size())
	for idx: int in count:
		looked_cards.append(player.deck[idx])
	return looked_cards
