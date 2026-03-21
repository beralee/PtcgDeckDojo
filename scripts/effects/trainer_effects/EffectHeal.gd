## 治疗效果 - 从宝可梦移除伤害指示物
## 适用: 伤药（治疗30）、好伤药（弃能量治疗全部）等
## 参数: heal_amount, heal_all, discard_energy_cost
class_name EffectHeal
extends BaseEffect

## 治疗量（heal_all=true 时忽略）
var heal_amount: int = 30
## 是否全部治疗
var heal_all: bool = false
## 是否需要弃置能量
var discard_energy_cost: int = 0


func _init(amount: int = 30, full: bool = false, energy_cost: int = 0) -> void:
	heal_amount = amount
	heal_all = full
	discard_energy_cost = energy_cost


func execute(_card: CardInstance, _targets: Array, state: GameState) -> void:
	# 简化：治疗己方战斗宝可梦
	var pi: int = _card.owner_index
	var player: PlayerState = state.players[pi]
	if player.active_pokemon == null:
		return

	var slot: PokemonSlot = player.active_pokemon

	# 弃置能量代价
	for _i: int in discard_energy_cost:
		if not slot.attached_energy.is_empty():
			var energy: CardInstance = slot.attached_energy.pop_back()
			player.discard_pile.append(energy)

	# 治疗
	if heal_all:
		slot.damage_counters = 0
	else:
		slot.damage_counters = maxi(0, slot.damage_counters - heal_amount)


func get_description() -> String:
	if heal_all:
		return "治疗所有伤害"
	return "治疗%d点伤害" % heal_amount
