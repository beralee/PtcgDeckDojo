## 老大的指令 - 选择对手1只备战宝可梦与战斗宝可梦互换
class_name EffectBossOrders
extends BaseEffect


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var opp: PlayerState = state.players[1 - card.owner_index]
	var labels: Array[String] = []
	for slot: PokemonSlot in opp.bench:
		labels.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])
	return [{
		"id": "opponent_bench_target",
		"title": "选择对手1只备战宝可梦",
		"items": opp.bench.duplicate(),
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func can_execute(card: CardInstance, state: GameState) -> bool:
	var opp: PlayerState = state.players[1 - card.owner_index]
	return not opp.bench.is_empty()


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var opp: PlayerState = state.players[1 - pi]
	var ctx: Dictionary = get_interaction_context(_targets)

	if opp.active_pokemon == null or opp.bench.is_empty():
		return

	var target: PokemonSlot = null
	var selected_raw: Array = ctx.get("opponent_bench_target", [])
	if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot:
		var selected: PokemonSlot = selected_raw[0]
		if selected in opp.bench:
			target = selected
	if target == null:
		target = opp.bench[0]
	var old_active: PokemonSlot = opp.active_pokemon
	opp.bench.erase(target)
	old_active.clear_on_leave_active()
	opp.bench.append(old_active)
	opp.active_pokemon = target


func get_description() -> String:
	return "选择对手1只备战宝可梦与战斗宝可梦互换"
