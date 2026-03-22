## 崩塌的竞技场 - 双方备战区上限变为4只；场地放置时若任一方超过4只需弃掉多余宝可梦
## 持续效果: 限制双方备战区上限为4（由 RuleValidator 使用 get_bench_limit 查询）
## 放置时触发: execute() 中检查并弃掉超出上限的备战宝可梦
class_name EffectCollapsedStadium
extends BaseEffect

## 竞技场生效时的备战区上限
const BENCH_LIMIT: int = 4
const STEP_ID_PREFIX: String = "collapsed_stadium_discard_p"


## 获取此竞技场下的备战区宝可梦上限
func get_bench_limit() -> int:
	return BENCH_LIMIT


func get_on_play_interaction_steps(_card: CardInstance, state: GameState) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	for pi: int in 2:
		var player: PlayerState = state.players[pi]
		var excess: int = player.bench.size() - BENCH_LIMIT
		if excess <= 0:
			continue
		var labels: Array[String] = []
		for slot: PokemonSlot in player.bench:
			labels.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])
		steps.append({
			"id": "%s%d" % [STEP_ID_PREFIX, pi],
			"title": "选择玩家%d要弃掉的%d只备战宝可梦" % [pi, excess],
			"items": player.bench.duplicate(),
			"labels": labels,
			"min_select": excess,
			"max_select": excess,
			"allow_cancel": true,
			"chooser_player_index": pi,
		})
	return steps


## 放置竞技场时执行：检查双方备战区，若超过上限则弃掉多余宝可梦
## 超出部分的宝可梦（及其所有附属卡）被放入弃牌区
## 注意：弃掉的宝可梦不计为被击倒，不触发奖赏卡
func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	execute_on_play(card, state, targets)


func execute_on_play(_card: CardInstance, state: GameState, targets: Array = []) -> void:
	var ctx: Dictionary = get_interaction_context(targets)
	for pi: int in 2:
		var player: PlayerState = state.players[pi]
		var excess: int = player.bench.size() - BENCH_LIMIT
		if excess <= 0:
			continue
		var slots_to_discard: Array[PokemonSlot] = _resolve_discarded_slots(player, ctx, pi, excess)
		for slot: PokemonSlot in slots_to_discard:
			if slot == null or slot not in player.bench:
				continue
			player.bench.erase(slot)
			var all_cards: Array[CardInstance] = slot.collect_all_cards()
			for c: CardInstance in all_cards:
				player.discard_card(c)


func get_description() -> String:
	return "双方备战区上限变为%d只；放置时超出部分的宝可梦被弃掉" % BENCH_LIMIT


func _resolve_discarded_slots(player: PlayerState, ctx: Dictionary, pi: int, excess: int) -> Array[PokemonSlot]:
	var chosen: Array[PokemonSlot] = []
	var step_id := "%s%d" % [STEP_ID_PREFIX, pi]
	var selected_raw: Array = ctx.get(step_id, [])
	for entry: Variant in selected_raw:
		if not (entry is PokemonSlot):
			continue
		var slot: PokemonSlot = entry as PokemonSlot
		if slot in player.bench and slot not in chosen:
			chosen.append(slot)
			if chosen.size() >= excess:
				return chosen

	for idx: int in range(player.bench.size() - 1, -1, -1):
		var fallback_slot: PokemonSlot = player.bench[idx]
		if fallback_slot in chosen:
			continue
		chosen.append(fallback_slot)
		if chosen.size() >= excess:
			break
	return chosen
