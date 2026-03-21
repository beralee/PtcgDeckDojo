## 凶暴吼叫 - 吼叫尾
## 对对手1只宝可梦造成（自身伤害指示物数量 x multiplier）点伤害。
## 目标任选（包括战斗场和备战区），备战区不计算弱点抗性。
class_name AttackSelfDamageCounterTargetDamage
extends BaseEffect

var damage_per_counter: int = 20


func _init(per_counter: int = 20) -> void:
	damage_per_counter = per_counter


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null:
		return []
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for slot: PokemonSlot in opponent.get_all_pokemon():
		items.append(slot)
		labels.append(slot.get_pokemon_name())
	if items.is_empty():
		return []
	return [{
		"id": "target_pokemon",
		"title": "选择对手的1只宝可梦",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var ctx: Dictionary = get_attack_interaction_context()

	var target: PokemonSlot = null
	var target_raw: Array = ctx.get("target_pokemon", [])
	if not target_raw.is_empty() and target_raw[0] is PokemonSlot:
		var t: PokemonSlot = target_raw[0]
		if t in opponent.get_all_pokemon():
			target = t
	if target == null:
		return

	# 计算伤害：自身伤害指示物数量（每10HP=1个指示物）x damage_per_counter
	var counter_count: int = attacker.damage_counters / 10
	var damage: int = counter_count * damage_per_counter
	if damage > 0:
		target.damage_counters += damage


func get_description() -> String:
	return "给对手的1只宝可梦造成自身伤害指示物数量x%d伤害。" % damage_per_counter
