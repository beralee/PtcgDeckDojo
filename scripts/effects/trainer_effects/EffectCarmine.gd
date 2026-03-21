class_name EffectCarmine
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not state.players[card.owner_index].deck.is_empty()


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var hand_copy: Array[CardInstance] = player.hand.duplicate()
	for hand_card: CardInstance in hand_copy:
		player.hand.erase(hand_card)
		hand_card.face_up = true
		player.discard_pile.append(hand_card)
	player.draw_cards(5)


func get_description() -> String:
	return "Discard your hand and draw 5 cards. You may play this during your first turn."
