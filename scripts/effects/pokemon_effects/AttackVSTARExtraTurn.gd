class_name AttackVSTARExtraTurn
extends BaseEffect

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(_attack_index):
		return
	var top_card: CardInstance = attacker.get_top_card()
	if top_card == null:
		return

	var player_index: int = top_card.owner_index
	if state.vstar_power_used[player_index]:
		return

	state.vstar_power_used[player_index] = true
	state.shared_turn_flags["pending_extra_turn_player_index"] = player_index
	state.shared_turn_flags["pending_extra_turn_turn_number"] = state.turn_number
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
