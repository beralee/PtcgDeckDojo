## 反击捕捉器 - 只有己方奖赏卡比对手多时可用，拉对手备战宝可梦到战斗场
class_name EffectCounterCatcher
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
	var pi: int = card.owner_index
	var my_prizes: int = state.players[pi].prizes.size()
	var opp_prizes: int = state.players[1 - pi].prizes.size()
	if my_prizes <= opp_prizes:
		return false
	return not state.players[1 - pi].bench.is_empty()


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
	opp.bench.append(old_active)
	opp.active_pokemon = target


func get_description() -> String:
	return "己方奖赏卡多时，选择对手1只备战宝可梦与战斗宝可梦互换"
