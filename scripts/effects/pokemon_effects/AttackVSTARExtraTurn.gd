class_name AttackVSTARExtraTurn
extends BaseEffect


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top_card: CardInstance = attacker.get_top_card()
	if top_card == null:
		return

	var player_index: int = top_card.owner_index
	if state.vstar_power_used[player_index]:
		return

	state.vstar_power_used[player_index] = true
	attacker.effects.append({
		"type": "vstar_power_used",
		"player_index": player_index,
		"turn": state.turn_number,
	})
	attacker.effects.append({
		"type": "extra_turn",
		"player_index": player_index,
		"turn": state.turn_number,
	})


func get_description() -> String:
	return "Take an extra turn after this one."
