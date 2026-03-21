## 按能量数追加伤害效果 - 根据己方能量数量追加对应伤害
## 适用: 起源帝牙卢卡VSTAR"金属爆破"(场上每个M能量+40)、光辉沙奈朵"精神强念"(自身每个P能量+40)
## 参数: energy_type, damage_per_energy, count_all_own
class_name AttackEnergyCountDamage
extends BaseEffect

## 统计的能量类型（空 = 所有类型）
var energy_type: String = ""
## 每个能量追加的伤害
var damage_per_energy: int = 40
## 是否统计己方全场所有宝可梦的能量（true = 金属爆破；false = 只统计攻击方）
var count_all_own: bool = false


func _init(e_type: String = "", dmg_per_e: int = 40, all_own: bool = false) -> void:
	energy_type = e_type
	damage_per_energy = dmg_per_e
	count_all_own = all_own


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var pi: int = attacker.get_top_card().owner_index
	var energy_count: int = 0

	if count_all_own:
		# 统计己方全场所有宝可梦（出战 + 备战）上的符合类型的能量
		var own_player: PlayerState = state.players[pi]
		var all_slots: Array = []
		if own_player.active_pokemon != null:
			all_slots.append(own_player.active_pokemon)
		for bench_slot: PokemonSlot in own_player.bench:
			all_slots.append(bench_slot)
		for slot: PokemonSlot in all_slots:
			if energy_type == "":
				energy_count += slot.get_total_energy_count()
			else:
				energy_count += slot.count_energy_of_type(energy_type)
	else:
		# 只统计攻击方自身的能量
		if energy_type == "":
			energy_count = attacker.get_total_energy_count()
		else:
			energy_count = attacker.count_energy_of_type(energy_type)

	# 追加伤害
	defender.damage_counters += damage_per_energy * energy_count


func get_description() -> String:
	var type_str: String = energy_type if energy_type != "" else "所有类型"
	var scope_str: String = "己方场上全部宝可梦" if count_all_own else "自身"
	return "%s每个%s能量追加%d伤害" % [scope_str, type_str, damage_per_energy]
