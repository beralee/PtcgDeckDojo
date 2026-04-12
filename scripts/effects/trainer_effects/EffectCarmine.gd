class_name EffectCarmine
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not state.players[card.owner_index].deck.is_empty()


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var hand_copy: Array[CardInstance] = player.hand.duplicate()
	_discard_cards_from_hand_with_log(state, card.owner_index, hand_copy, card, "trainer")
	_draw_cards_with_log(state, card.owner_index, 5, card, "trainer")


func get_description() -> String:
	return "Discard your hand and draw 5 cards. You may play this during your first turn."
