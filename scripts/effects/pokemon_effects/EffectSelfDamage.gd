## 自伤效果 - 攻击后对自己造成伤害
## 适用: "对自己造成30伤害"等反冲招式
## 参数: self_damage
class_name EffectSelfDamage
extends BaseEffect

## 自伤伤害量
var self_damage: int = 30
var attack_index_to_match: int = -1


func _init(damage: int = 30, match_attack_index: int = -1) -> void:
	self_damage = damage
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	if not applies_to_attack_index(_attack_index):
		return
	attacker.damage_counters += self_damage


func get_description() -> String:
	return "对自己造成%d伤害" % self_damage
