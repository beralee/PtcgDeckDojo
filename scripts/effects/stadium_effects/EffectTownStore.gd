## 城镇百货 - 每回合1次，当前回合玩家可从牌库检索1张宝可梦道具加入手牌
## 效果类型: 可主动使用的竞技场效果
## 使用限制: 每回合每位玩家仅可使用1次（由 GameStateMachine 管理使用标记）
## 由 EffectProcessor 的 execute_card_effect 调用，卡牌为竞技场卡本身的占位实例
class_name EffectTownStore
extends BaseEffect


## 检查是否可以使用（牌库中至少有1张宝可梦道具）
func can_execute(card: CardInstance, state: GameState) -> bool:
	var pi: int = state.current_player_index
	var player: PlayerState = state.players[pi]
	for c: CardInstance in player.deck:
		if c.card_data != null and c.card_data.card_type == "Tool":
			return true
	return false


func can_use_as_stadium_action(_card: CardInstance, _state: GameState) -> bool:
	return true


func get_interaction_steps(_card: CardInstance, state: GameState) -> Array[Dictionary]:
	var pi: int = state.current_player_index
	var player: PlayerState = state.players[pi]
	var items: Array = []
	var labels: Array[String] = []
	for deck_card: CardInstance in player.deck:
		if deck_card.card_data != null and deck_card.card_data.card_type == "Tool":
			items.append(deck_card)
			labels.append(deck_card.card_data.name)
	if items.is_empty():
		return []
	return [{
		"id": "town_store_tool",
		"title": "选择1张宝可梦道具加入手牌",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


## 执行效果：从牌库中检索1张宝可梦道具加入手牌，然后洗牌
func execute(_card: CardInstance, targets: Array, state: GameState) -> void:
	var pi: int = state.current_player_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("town_store_tool", [])

	var tool_card: CardInstance = null
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance:
		var candidate: CardInstance = selected_raw[0]
		if candidate in player.deck and candidate.card_data != null and candidate.card_data.card_type == "Tool":
			tool_card = candidate
	if tool_card == null:
		for deck_card: CardInstance in player.deck:
			if deck_card.card_data != null and deck_card.card_data.card_type == "Tool":
				tool_card = deck_card
				break
	if tool_card == null:
		return

	player.deck.erase(tool_card)
	tool_card.face_up = true
	player.hand.append(tool_card)
	player.shuffle_deck()


func get_description() -> String:
	return "每回合1次，从牌库检索1张宝可梦道具加入手牌"
