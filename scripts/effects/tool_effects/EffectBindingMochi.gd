class_name EffectBindingMochi
extends BaseEffect

var damage_bonus: int = 40


func get_attack_modifier(attacker: PokemonSlot, _state: GameState) -> int:
	if attacker == null:
		return 0
	return damage_bonus if bool(attacker.status_conditions.get("poisoned", false)) else 0


func get_description() -> String:
	return "若附有此卡的中毒宝可梦使用招式，对对手战斗宝可梦的伤害+40。"
