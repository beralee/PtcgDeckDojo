## 弃指定能量×倍伤害效果 - 强劲电光（雷丘V）
## 弃置攻击者身上所有指定类型的能量，每弃1张追加额外伤害
## 参数:
##   energy_type       要弃置的能量类型（默认"L"=雷能量）
##   damage_per_energy 每弃1张追加的伤害值（默认60）
class_name AttackDiscardEnergyMultiDamage
extends BaseEffect

## 要弃置的能量类型
var energy_type: String = "L"
## 每弃1张追加的伤害值
var damage_per_energy: int = 60


func _init(e_type: String = "L", per_energy: int = 60) -> void:
	energy_type = e_type
	damage_per_energy = per_energy


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top_card: CardInstance = attacker.get_top_card()
	if top_card == null:
		return
	var pi: int = top_card.owner_index
	var player: PlayerState = state.players[pi]

	# 找出所有符合类型的能量
	var to_discard: Array[CardInstance] = []
	for energy_card: CardInstance in attacker.attached_energy:
		if _matches_energy_type(energy_card):
			to_discard.append(energy_card)

	if to_discard.is_empty():
		return

	# 从附着能量中移除并放入弃牌区
	for energy_card: CardInstance in to_discard:
		attacker.attached_energy.erase(energy_card)
		player.discard_pile.append(energy_card)

	# 追加伤害
	var bonus_damage: int = damage_per_energy * to_discard.size()
	defender.damage_counters += bonus_damage


## 判断能量卡是否符合指定类型
func _matches_energy_type(card: CardInstance) -> bool:
	var cd: CardData = card.card_data
	if cd == null:
		return false
	if not cd.is_energy():
		return false
	if energy_type == "":
		return true
	return cd.energy_provides == energy_type or cd.energy_type == energy_type


func get_description() -> String:
	return "强劲电光：弃置自身所有%s能量，每弃1张追加%d伤害。" % [energy_type, damage_per_energy]
