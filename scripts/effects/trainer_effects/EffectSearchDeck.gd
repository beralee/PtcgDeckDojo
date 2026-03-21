## 检索牌库效果 - 从牌库搜索符合条件的卡牌加入手牌
## 适用: 超级球（弃2张检索1张）、精灵球（投币检索基础宝可梦）、网球（检索基础宝可梦）等
## 注意: 简化版实现——自动从牌库顶抽取（完整版需要UI选择）
## 参数: search_count, discard_cost, card_type_filter
class_name EffectSearchDeck
extends BaseEffect

## 检索数量
var search_count: int = 1
## 弃牌代价（从手牌弃N张）
var discard_cost: int = 0
## 卡牌类型过滤（空=任意，"Pokemon"=仅宝可梦，"Basic"=仅基础宝可梦）
var card_type_filter: String = ""
## 是否需要投币（正面才能检索）
var require_coin_flip: bool = false


func _init(count: int = 1, discard: int = 0, filter: String = "", coin: bool = false) -> void:
	search_count = count
	discard_cost = discard
	card_type_filter = filter
	require_coin_flip = coin


func can_execute(card: CardInstance, state: GameState) -> bool:
	# 检查手牌是否足够支付弃牌代价（卡牌本身已移出手牌，所以当前手牌就是可用数量）
	var player: PlayerState = state.players[card.owner_index]
	var available_hand_cards: int = 0
	for hand_card: CardInstance in player.hand:
		if hand_card != card:
			available_hand_cards += 1
	if available_hand_cards < discard_cost:
		return false
	for deck_card: CardInstance in player.deck:
		if _matches_filter(deck_card):
			return true
	return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var steps: Array[Dictionary] = []
	if discard_cost > 0:
		var hand_items: Array = []
		var hand_labels: Array[String] = []
		for c: CardInstance in player.hand:
			if c == card:
				continue
			hand_items.append(c)
			hand_labels.append(c.card_data.name)
		steps.append({
			"id": "discard_cards",
			"title": "选择要弃置的%d张手牌" % discard_cost,
			"items": hand_items,
			"labels": hand_labels,
			"min_select": discard_cost,
			"max_select": discard_cost,
			"allow_cancel": true,
		})

	var deck_items: Array = []
	var deck_labels: Array[String] = []
	for c: CardInstance in player.deck:
		if _matches_filter(c):
			deck_items.append(c)
			deck_labels.append(c.card_data.name)
	steps.append({
		"id": "search_cards",
		"title": "选择最多%d张符合条件的卡" % search_count,
		"items": deck_items,
		"labels": deck_labels,
		"min_select": 1,
		"max_select": mini(search_count, deck_items.size()),
		"allow_cancel": true,
	})
	return steps


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(_targets)

	var discard_cards: Array[CardInstance] = []
	var discard_raw: Array = ctx.get("discard_cards", [])
	for c: Variant in discard_raw:
		if c is CardInstance and c in player.hand:
			discard_cards.append(c)
	if discard_cards.size() < discard_cost:
		for hand_card: CardInstance in player.hand:
			if discard_cards.size() >= discard_cost:
				break
			if hand_card not in discard_cards:
				discard_cards.append(hand_card)
	for discarded: CardInstance in discard_cards:
		if discarded in player.hand:
			player.hand.erase(discarded)
			player.discard_pile.append(discarded)

	var found: Array[CardInstance] = []
	var selected_raw: Array = ctx.get("search_cards", [])
	for c: Variant in selected_raw:
		if c is CardInstance and c in player.deck and _matches_filter(c):
			found.append(c)
			if found.size() >= search_count:
				break
	if found.is_empty():
		for deck_card: CardInstance in player.deck:
			if found.size() >= search_count:
				break
			if _matches_filter(deck_card):
				found.append(deck_card)

	for c: CardInstance in found:
		player.deck.erase(c)
	for c: CardInstance in found:
		c.face_up = true
		player.hand.append(c)

	# 洗牌（检索后必须洗牌）
	player.shuffle_deck()


func _matches_filter(card: CardInstance) -> bool:
	if card_type_filter == "":
		return true
	var cd: CardData = card.card_data
	match card_type_filter:
		"Pokemon":
			return cd.is_pokemon()
		"Basic":
			return cd.is_basic_pokemon()
		"Trainer":
			return cd.is_trainer()
		"Energy":
			return cd.is_energy()
		"Item":
			return cd.card_type == "Item"
		"Supporter":
			return cd.card_type == "Supporter"
		_:
			return cd.card_type == card_type_filter


func get_description() -> String:
	var parts: Array[String] = []
	if discard_cost > 0:
		parts.append("弃%d张手牌" % discard_cost)
	var filter_str: String = ""
	if card_type_filter != "":
		var filter_map := {"Pokemon": "宝可梦", "Basic": "基础宝可梦", "Trainer": "训练家", "Energy": "能量"}
		filter_str = filter_map.get(card_type_filter, card_type_filter)
	parts.append("从牌库检索%d张%s" % [search_count, filter_str])
	return "，".join(parts)
