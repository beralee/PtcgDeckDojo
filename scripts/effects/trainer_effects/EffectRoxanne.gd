class_name EffectRoxanne
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var pi: int = card.owner_index
	return state.players[1 - pi].prizes.size() <= 3


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	_shuffle_and_draw(state, pi, 6, card)
	_shuffle_and_draw(state, 1 - pi, 2, card)


func _shuffle_and_draw(state: GameState, pi: int, draw_count: int, source_card: CardInstance) -> void:
	var player: PlayerState = state.players[pi]
	var hand_copy: Array[CardInstance] = player.hand.duplicate()
	for hand_card: CardInstance in hand_copy:
		player.hand.erase(hand_card)
		hand_card.face_up = false
		player.deck.append(hand_card)
	player.shuffle_deck()
	_draw_cards_with_log(state, pi, draw_count, source_card, "trainer")


func get_description() -> String:
	return "对手剩余奖赏卡为 3 张或以下时才可使用。双方各将手牌洗回牌库。自己抽 6 张，对手抽 2 张。"
