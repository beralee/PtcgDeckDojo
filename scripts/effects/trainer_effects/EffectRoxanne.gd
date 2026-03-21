class_name EffectRoxanne
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var pi: int = card.owner_index
	return state.players[1 - pi].prizes.size() <= 3


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	_shuffle_and_draw(state.players[pi], 6)
	_shuffle_and_draw(state.players[1 - pi], 2)


func _shuffle_and_draw(player: PlayerState, draw_count: int) -> void:
	var hand_copy: Array[CardInstance] = player.hand.duplicate()
	for hand_card: CardInstance in hand_copy:
		player.hand.erase(hand_card)
		hand_card.face_up = false
		player.deck.append(hand_card)
	player.shuffle_deck()
	player.draw_cards(draw_count)


func get_description() -> String:
	return "对手剩余奖赏卡3张以下时可使用。双方各将手牌洗回牌库，自己抽6张，对手抽2张。"
