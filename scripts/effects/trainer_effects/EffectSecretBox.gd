## 秘密箱 - ACE SPEC 物品卡
## 弃3张手牌，从牌库中检索物品、道具、支援者、竞技场各1张加入手牌，洗牌。
class_name EffectSecretBox
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	# 手牌至少要有3张（不含秘密箱自身，因为秘密箱打出时已从手牌移除）
	return player.hand.size() >= 3


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	if player.hand.size() < 3:
		return []

	var steps: Array[Dictionary] = []
	# 步骤1：选择3张手牌弃掉
	var hand_items: Array = []
	var hand_labels: Array[String] = []
	for hand_card: CardInstance in player.hand:
		hand_items.append(hand_card)
		hand_labels.append(hand_card.card_data.name if hand_card.card_data != null else "未知卡牌")
	steps.append({
		"id": "discard_cards",
		"title": "选择3张手牌放入弃牌区",
		"items": hand_items,
		"labels": hand_labels,
		"min_select": 3,
		"max_select": 3,
		"allow_cancel": true,
	})

	# 步骤2-5：从牌库搜索各类型卡牌
	var search_types: Array[Array] = [
		["search_item", "Item", "选择1张物品卡"],
		["search_tool", "Tool", "选择1张宝可梦道具"],
		["search_supporter", "Supporter", "选择1张支援者卡"],
		["search_stadium", "Stadium", "选择1张竞技场卡"],
	]
	for search_def: Array in search_types:
		var items: Array = []
		var labels: Array[String] = []
		for deck_card: CardInstance in player.deck:
			if deck_card.card_data != null and deck_card.card_data.card_type == search_def[1]:
				items.append(deck_card)
				labels.append(deck_card.card_data.name)
		if not items.is_empty():
			steps.append({
				"id": search_def[0],
				"title": search_def[2],
				"items": items,
				"labels": labels,
				"min_select": 0,
				"max_select": 1,
				"allow_cancel": true,
			})

	return steps


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(targets)

	# 弃3张手牌
	var discard_raw: Array = ctx.get("discard_cards", [])
	var discarded: int = 0
	for entry: Variant in discard_raw:
		if not (entry is CardInstance):
			continue
		var dc: CardInstance = entry as CardInstance
		if dc in player.hand:
			player.remove_from_hand(dc)
			player.discard_card(dc)
			discarded += 1
			if discarded >= 3:
				break
	if discarded < 3:
		# 自动补弃
		while discarded < 3 and not player.hand.is_empty():
			var dc: CardInstance = player.hand[0]
			player.remove_from_hand(dc)
			player.discard_card(dc)
			discarded += 1

	# 从牌库检索各类型
	var search_keys: Array[String] = ["search_item", "search_tool", "search_supporter", "search_stadium"]
	var search_types: Array[String] = ["Item", "Tool", "Supporter", "Stadium"]
	for i: int in search_keys.size():
		var raw: Array = ctx.get(search_keys[i], [])
		if raw.is_empty():
			continue
		if not (raw[0] is CardInstance):
			continue
		var found_card: CardInstance = raw[0] as CardInstance
		if found_card in player.deck and found_card.card_data != null and found_card.card_data.card_type == search_types[i]:
			player.deck.erase(found_card)
			found_card.face_up = true
			player.hand.append(found_card)

	player.shuffle_deck()


func get_description() -> String:
	return "弃3张手牌，从牌库检索物品、道具、支援者、竞技场各1张加入手牌。"
