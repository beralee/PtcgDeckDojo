## Lost Vacuum - discard 1 card, then remove a Tool or Stadium
class_name EffectLostVacuum
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var other_hand_cards: int = 0
	for hand_card: CardInstance in player.hand:
		if hand_card != card:
			other_hand_cards += 1
	if other_hand_cards < 1:
		return false
	if state.stadium_card != null:
		return true
	for slot_pi: int in 2:
		for slot: PokemonSlot in state.players[slot_pi].get_all_pokemon():
			if slot.attached_tool != null:
				return true
	return false


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]

	if not player.hand.is_empty():
		var discarded: CardInstance = player.hand.pop_back()
		player.discard_pile.append(discarded)

	var opp: PlayerState = state.players[1 - pi]
	for slot: PokemonSlot in opp.get_all_pokemon():
		if slot.attached_tool != null:
			opp.discard_pile.append(slot.attached_tool)
			slot.attached_tool = null
			return

	if state.stadium_card != null:
		var owner: PlayerState = state.players[state.stadium_owner_index]
		owner.discard_pile.append(state.stadium_card)
		state.stadium_card = null
		state.stadium_owner_index = -1
		return

	for slot: PokemonSlot in player.get_all_pokemon():
		if slot.attached_tool != null:
			player.discard_pile.append(slot.attached_tool)
			slot.attached_tool = null
			return


func get_description() -> String:
	return "Discard 1 card from your hand, then remove a Tool or Stadium."
