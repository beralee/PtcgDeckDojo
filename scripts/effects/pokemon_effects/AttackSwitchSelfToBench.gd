## 瞬移破坏 - 拉鲁拉丝
## 造成伤害后将自身与备战区宝可梦交换
class_name AttackSwitchSelfToBench
extends BaseEffect


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	if player.bench.is_empty():
		return []
	var items: Array = []
	var labels: Array[String] = []
	for slot: PokemonSlot in player.bench:
		items.append(slot)
		labels.append(slot.get_pokemon_name())
	return [{
		"id": "switch_target",
		"title": "选择要交换的备战宝可梦",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
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
	var player: PlayerState = state.players[top.owner_index]
	if player.bench.is_empty():
		return

	var ctx: Dictionary = get_attack_interaction_context()
	var target: PokemonSlot = null
	var target_raw: Array = ctx.get("switch_target", [])
	if not target_raw.is_empty() and target_raw[0] is PokemonSlot:
		var t: PokemonSlot = target_raw[0]
		if t in player.bench:
			target = t
	if target == null:
		target = player.bench[0]

	# 交换
	var bench_idx: int = player.bench.find(target)
	if bench_idx < 0:
		return
	player.bench[bench_idx] = attacker
	player.active_pokemon = target


func get_description() -> String:
	return "攻击后与备战宝可梦交换。"
