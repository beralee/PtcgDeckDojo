## 暗码迷的解读 - 从牌库选2张卡放到牌库顶，其余卡重新洗入牌库
class_name EffectCiphermaniac
extends BaseEffect

## 最多可放到牌库顶的卡牌数量
const TOP_CARD_COUNT: int = 2


func can_execute(card: CardInstance, state: GameState) -> bool:
	## 牌库不为空才可使用
	var player: PlayerState = state.players[card.owner_index]
	return not player.deck.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	if player.deck.is_empty():
		return []

	var pick_count: int = mini(TOP_CARD_COUNT, player.deck.size())
	var deck_items: Array = []
	var deck_labels: Array[String] = []
	for deck_card: CardInstance in player.deck:
		deck_items.append(deck_card)
		deck_labels.append(deck_card.card_data.name)

	return [{
		"id": "top_cards",
		"title": "按顺序选择要放在牌库顶的牌（先点最上面）",
		"items": deck_items,
		"labels": deck_labels,
		"min_select": pick_count,
		"max_select": pick_count,
		"allow_cancel": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(targets)

	if player.deck.is_empty():
		return

	var pick_count: int = mini(TOP_CARD_COUNT, player.deck.size())
	var chosen: Array[CardInstance] = []
	var selected_raw: Array = ctx.get("top_cards", [])
	for picked: Variant in selected_raw:
		if picked is CardInstance and picked in player.deck and picked not in chosen:
			chosen.append(picked)
			if chosen.size() >= pick_count:
				break
	if chosen.is_empty():
		for i: int in pick_count:
			chosen.append(player.deck[i])

	for c: CardInstance in chosen:
		player.deck.erase(c)

	player.shuffle_deck()

	var reversed_chosen: Array[CardInstance] = chosen.duplicate()
	reversed_chosen.reverse()
	for c: CardInstance in reversed_chosen:
		player.deck.insert(0, c)


func get_description() -> String:
	return "从牌库选最多%d张卡放到牌库顶，其余重新洗入牌库" % TOP_CARD_COUNT
