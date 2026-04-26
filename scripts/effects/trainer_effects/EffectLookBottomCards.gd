class_name EffectLookBottomCards
extends EffectLookTopCards


func _get_looked_cards(player: PlayerState) -> Array[CardInstance]:
	var looked_cards: Array[CardInstance] = []
	var check_count: int = mini(look_count, player.deck.size()) if look_count > 0 else player.deck.size()
	var start_index: int = maxi(0, player.deck.size() - check_count)
	for idx: int in range(start_index, player.deck.size()):
		looked_cards.append(player.deck[idx])
	return looked_cards
