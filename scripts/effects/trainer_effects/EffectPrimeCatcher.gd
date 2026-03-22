## 顶尖捕捉器 (ACE SPEC) - 拉对手备战宝可梦，然后己方也换宝可梦
class_name EffectPrimeCatcher
extends BaseEffect


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var opp: PlayerState = state.players[1 - pi]
	var opp_labels: Array[String] = []
	for slot: PokemonSlot in opp.bench:
		opp_labels.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])
	var my_labels: Array[String] = []
	for slot: PokemonSlot in player.bench:
		my_labels.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])
	return [
		{
			"id": "opponent_bench_target",
			"title": "选择对手1只备战宝可梦",
			"items": opp.bench.duplicate(),
			"labels": opp_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
		{
			"id": "own_bench_target",
			"title": "选择己方1只备战宝可梦",
			"items": player.bench.duplicate(),
			"labels": my_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
	]


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	var opp: PlayerState = state.players[1 - card.owner_index]
	return not opp.bench.is_empty() and not player.bench.is_empty()


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var opp: PlayerState = state.players[1 - pi]
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(_targets)

	# 1. 拉对手备战宝可梦到战斗场
	if opp.active_pokemon != null and not opp.bench.is_empty():
		var target: PokemonSlot = null
		var opp_raw: Array = ctx.get("opponent_bench_target", [])
		if not opp_raw.is_empty() and opp_raw[0] is PokemonSlot and opp_raw[0] in opp.bench:
			target = opp_raw[0]
		if target == null:
			target = opp.bench[0]
		var old_active: PokemonSlot = opp.active_pokemon
		opp.bench.erase(target)
		opp.bench.append(old_active)
		opp.active_pokemon = target

	# 2. 己方战斗宝可梦与备战宝可梦互换
	if player.active_pokemon != null and not player.bench.is_empty():
		var my_target: PokemonSlot = null
		var own_raw: Array = ctx.get("own_bench_target", [])
		if not own_raw.is_empty() and own_raw[0] is PokemonSlot and own_raw[0] in player.bench:
			my_target = own_raw[0]
		if my_target == null:
			my_target = player.bench[0]
		var my_old: PokemonSlot = player.active_pokemon
		player.bench.erase(my_target)
		player.bench.append(my_old)
		player.active_pokemon = my_target


func get_description() -> String:
	return "选择对手1只备战宝可梦与战斗宝可梦互换，然后己方也互换"
