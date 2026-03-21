## 沉重接力棒 - 撤退费用为4的宝可梦昏厥时，可将最多3张基本能量转移到备战宝可梦
## 触发条件: 持有此道具的宝可梦撤退费用为4且被击倒时
## 触发时机: 由 GameStateMachine 在 _handle_knockout 中检查此道具，并执行能量转移逻辑
## 此类本身仅存储标记数据，实际转移由外部状态机处理
class_name EffectToolHeavyBaton
extends BaseEffect

## 最多可转移的基本能量数量
const MAX_ENERGY_TRANSFER: int = 3
## 触发所需的撤退费用阈值
const REQUIRED_RETREAT_COST: int = 4


## 检查指定槽位是否满足触发条件（撤退费用 >= 4）
## slot: 持有此道具的宝可梦槽位
func can_trigger(slot: PokemonSlot) -> bool:
	return slot.get_retreat_cost() >= REQUIRED_RETREAT_COST


## 获取可从昏厥宝可梦转移到备战宝可梦的基本能量列表（最多3张）
## slot: 昏厥的宝可梦槽位
## 返回可转移的能量卡实例列表
func get_transferable_energy(slot: PokemonSlot) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for energy: CardInstance in slot.attached_energy:
		if result.size() >= MAX_ENERGY_TRANSFER:
			break
		# 仅转移基本能量（card_type == "Basic Energy"）
		if energy.card_data != null and energy.card_data.card_type == "Basic Energy":
			result.append(energy)
	return result


## 执行能量转移：将能量从昏厥槽位转移到目标备战槽位
## from_slot: 昏厥的宝可梦槽位
## to_slot: 接收能量的备战宝可梦槽位
## energies: 要转移的能量卡列表（由外部调用者提供，应是 get_transferable_energy 的子集）
func transfer_energy(from_slot: PokemonSlot, to_slot: PokemonSlot, energies: Array[CardInstance]) -> void:
	for energy: CardInstance in energies:
		var idx: int = from_slot.attached_energy.find(energy)
		if idx != -1:
			from_slot.attached_energy.remove_at(idx)
			to_slot.attached_energy.append(energy)


func get_description() -> String:
	return "撤退费用为%d的宝可梦昏厥时，可将最多%d张基本能量转移到备战宝可梦" % [
		REQUIRED_RETREAT_COST,
		MAX_ENERGY_TRANSFER
	]
