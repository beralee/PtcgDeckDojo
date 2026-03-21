class_name AttackDefenderRetreatLockNextTurn
extends BaseEffect

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(_attacker: PokemonSlot, defender: PokemonSlot, _attack_index: int, state: GameState) -> void:
	if not applies_to_attack_index(_attack_index):
		return
	if defender == null:
		return
	# 薄雾能量免疫对手招式效果
	if EffectMistEnergy.has_mist_energy(defender):
		return
	defender.effects.append({
		"type": "retreat_lock",
		"turn": state.turn_number,
	})


func get_description() -> String:
	return "The Defending Pokemon can't retreat during your opponent's next turn."
