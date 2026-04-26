class_name AttackBonusIfOwnStadium
extends BaseEffect

var damage_bonus: int = 80


func _init(bonus: int = 80) -> void:
	damage_bonus = bonus


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or state == null or state.stadium_card == null:
		return 0
	var owner_index: int = attacker.get_top_card().owner_index if attacker.get_top_card() != null else -1
	if owner_index < 0:
		return 0
	return damage_bonus if state.stadium_owner_index == owner_index else 0


func get_description() -> String:
	return "如果场上有自己的竞技场，则这次攻击追加造成伤害。"
