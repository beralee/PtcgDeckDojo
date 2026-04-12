class_name EffectUnfairStamp
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var pi: int = card.owner_index
	return state.last_knockout_turn_against[pi] == state.turn_number - 1


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	_shuffle_and_draw(state, pi, 5, card)
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
	return "If one of your Pokemon was Knocked Out during your opponent's last turn, each player shuffles their hand into their deck. You draw 5 cards and your opponent draws 2."
