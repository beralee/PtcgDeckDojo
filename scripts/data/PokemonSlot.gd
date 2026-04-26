## 宝可梦槽位 - 场上一只宝可梦及其所有附属卡牌
class_name PokemonSlot
extends RefCounted

## 进化链（底部为基础宝可梦，顶部为当前形态）
var pokemon_stack: Array[CardInstance] = []
## 附着的能量卡
var attached_energy: Array[CardInstance] = []
## 附着的宝可梦道具（最多1张）
var attached_tool: CardInstance = null
## 伤害指示物总量（10的倍数）
var damage_counters: int = 0

## 特殊状态
var status_conditions: Dictionary = {
	"poisoned": false,
	"burned": false,
	"asleep": false,
	"paralyzed": false,
	"confused": false,
}

## 放上场的回合号（用于进化判定）
var turn_played: int = -1
## 最近进化的回合号
var turn_evolved: int = -1
## 临时效果列表（如清除古龙水、招式锁定等）
## 每个元素为 Dictionary: {type: String, source: String, turn: int, ...}
var effects: Array[Dictionary] = []

const ENTERED_ACTIVE_FROM_BENCH_EFFECT_TYPE := "entered_active_from_bench"
const ABILITY_USED_EFFECT_TYPE := "ability_used"


## 获取顶层卡牌（当前形态）
func get_top_card() -> CardInstance:
	if pokemon_stack.is_empty():
		return null
	return pokemon_stack.back()


## 获取顶层卡牌数据
func get_card_data() -> CardData:
	var top := get_top_card()
	return top.card_data if top else null


## 获取宝可梦名称
func get_pokemon_name() -> String:
	var data := get_card_data()
	return data.name if data else ""


## 获取属性类型
func get_energy_type() -> String:
	var data := get_card_data()
	return data.energy_type if data else ""


## 获取最大HP
func get_max_hp() -> int:
	var data := get_card_data()
	return data.hp if data else 0


## 获取剩余HP
func get_remaining_hp() -> int:
	return maxi(0, get_max_hp() - damage_counters)


## 是否已昏厥
func is_knocked_out() -> bool:
	return get_max_hp() > 0 and get_remaining_hp() <= 0


## 获取昏厥时对手应拿的奖赏卡数
func get_prize_count() -> int:
	var data := get_card_data()
	return data.get_prize_count() if data else 1


## 获取撤退所需能量数
func get_retreat_cost() -> int:
	var data := get_card_data()
	return data.retreat_cost if data else 0


## 获取招式列表
func get_attacks() -> Array[Dictionary]:
	var data := get_card_data()
	return data.attacks if data else []


## 获取特性列表
func get_abilities() -> Array[Dictionary]:
	var data := get_card_data()
	return data.abilities if data else []


## 是否处于任何特殊状态
func has_any_status() -> bool:
	for status: bool in status_conditions.values():
		if status:
			return true
	return false


## 清除所有特殊状态
func clear_all_status() -> void:
	for key: String in status_conditions:
		status_conditions[key] = false


## 从战斗场退回备战区时，清除所有特殊状态和战斗位置相关的临时效果
## PTCG 规则：宝可梦离开战斗区时，中毒/灼伤/混乱等状态以及
## 减伤、招式锁定、撤退锁定等战斗位置效果全部消失
const _BENCH_CLEAR_EFFECT_TYPES: Array[String] = [
	"reduce_damage_next_turn",
	"attack_lock",
	"attack_lock_until_leave_active",
	"defender_attack_lock",
	"retreat_lock",
	"prevent_attack_damage_and_effects",
	"ability_disabled",
	"extra_prize",
]

func clear_on_leave_active() -> void:
	clear_all_status()
	if effects.is_empty():
		return
	var kept: Array[Dictionary] = []
	for eff: Dictionary in effects:
		if eff.get("type", "") not in _BENCH_CLEAR_EFFECT_TYPES:
			kept.append(eff)
	effects = kept


func mark_entered_active_from_bench(turn_number: int) -> void:
	effects.append({
		"type": ENTERED_ACTIVE_FROM_BENCH_EFFECT_TYPE,
		"turn": turn_number,
	})


func entered_active_from_bench_this_turn(turn_number: int) -> bool:
	for eff: Dictionary in effects:
		if eff.get("type", "") == ENTERED_ACTIVE_FROM_BENCH_EFFECT_TYPE and int(eff.get("turn", -999)) == turn_number:
			return true
	return false


func mark_ability_used(turn_number: int) -> void:
	effects.append({
		"type": ABILITY_USED_EFFECT_TYPE,
		"turn": turn_number,
	})


func has_ability_used(turn_number: int) -> bool:
	for eff: Dictionary in effects:
		if eff.get("type", "") == ABILITY_USED_EFFECT_TYPE and int(eff.get("turn", -999)) == turn_number:
			return true
	return false


## 设置特殊状态（自动处理互斥关系）
func set_status(status_name: String, value: bool) -> void:
	if not status_conditions.has(status_name):
		return

	if value:
		# 睡眠、麻痹、混乱三者互斥
		var exclusive: Array[String] = ["asleep", "paralyzed", "confused"]
		if status_name in exclusive:
			for s: String in exclusive:
				status_conditions[s] = false

	status_conditions[status_name] = value


## 获取附着的特定类型能量数量
func count_energy_of_type(energy_type: String) -> int:
	var count := 0
	for energy in attached_energy:
		if energy.card_data and energy.card_data.energy_provides == energy_type:
			count += 1
	return count


## 获取附着的总能量数量
func get_total_energy_count() -> int:
	return attached_energy.size()


## 收集此槽位上的所有卡牌（用于昏厥时放入弃牌区）
func collect_all_cards() -> Array[CardInstance]:
	var all_cards: Array[CardInstance] = []
	all_cards.append_array(pokemon_stack)
	all_cards.append_array(attached_energy)
	if attached_tool:
		all_cards.append(attached_tool)
	return all_cards


func _to_string() -> String:
	var hp_str := "%d/%d" % [get_remaining_hp(), get_max_hp()]
	return "[PokemonSlot: %s HP=%s]" % [get_pokemon_name(), hp_str]
