class_name AttackDefenderAttackLockNextTurn
extends BaseEffect

var mode: String = ""


func _init(lock_mode: String = "") -> void:
	mode = lock_mode


func execute_attack(
	_attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	if defender == null:
		return
	# 薄雾能量免疫对手招式效果
	if EffectMistEnergy.has_mist_energy(defender):
		return
	defender.effects.append({
		"type": "defender_attack_lock",
		"turn": state.turn_number,
		"mode": mode,
	})


func get_description() -> String:
	return "Prevent the defending Pokemon from attacking on the next turn."
