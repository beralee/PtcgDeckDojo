## 替换宝可梦效果 - 将战斗/备战宝可梦互换
## 适用: 老大的号令（替换对手战斗宝可梦）、逃跑绳（双方替换）等
## 参数: target_player ("self"/"opponent"/"both")
class_name EffectSwitchPokemon
extends BaseEffect

## 目标: "self"=己方, "opponent"=对方, "both"=双方
var target_player: String = "self"


func _init(target: String = "self") -> void:
	target_player = target


func can_execute(card: CardInstance, state: GameState) -> bool:
	var pi: int = card.owner_index
	match target_player:
		"self":
			return not state.players[pi].bench.is_empty()
		"opponent":
			return not state.players[1 - pi].bench.is_empty()
		"both":
			return not state.players[pi].bench.is_empty() or not state.players[1 - pi].bench.is_empty()
	return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var pi: int = card.owner_index
	match target_player:
		"self":
			return [_build_switch_step(state.players[pi], "self_switch_target", "选择要换上战斗场的己方备战宝可梦")]
		"opponent":
			return [_build_switch_step(state.players[1 - pi], "opponent_switch_target", "选择对手1只备战宝可梦")]
		"both":
			var steps: Array[Dictionary] = []
			if not state.players[1 - pi].bench.is_empty():
				steps.append(_build_switch_step(state.players[1 - pi], "opponent_switch_target", "选择对手1只备战宝可梦"))
			if not state.players[pi].bench.is_empty():
				steps.append(_build_switch_step(state.players[pi], "self_switch_target", "选择要换上战斗场的己方备战宝可梦"))
			return steps
	return []


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var ctx: Dictionary = get_interaction_context(targets)
	match target_player:
		"self":
			_switch(state, pi, _get_selected_target(ctx, "self_switch_target", state.players[pi]))
		"opponent":
			_switch(state, 1 - pi, _get_selected_target(ctx, "opponent_switch_target", state.players[1 - pi]))
		"both":
			_switch(state, 1 - pi, _get_selected_target(ctx, "opponent_switch_target", state.players[1 - pi]))
			_switch(state, pi, _get_selected_target(ctx, "self_switch_target", state.players[pi]))


func _build_switch_step(player: PlayerState, step_id: String, title: String) -> Dictionary:
	var items: Array = []
	var labels: Array[String] = []
	for slot: PokemonSlot in player.bench:
		items.append(slot)
		labels.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])
	return {
		"id": step_id,
		"title": title,
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}


func _get_selected_target(ctx: Dictionary, step_id: String, player: PlayerState) -> PokemonSlot:
	var target_raw: Array = ctx.get(step_id, [])
	if not target_raw.is_empty() and target_raw[0] is PokemonSlot:
		var candidate: PokemonSlot = target_raw[0]
		if candidate in player.bench:
			return candidate
	if not player.bench.is_empty():
		return player.bench[0]
	return null


func _switch(state: GameState, pi: int, chosen_target: PokemonSlot = null) -> void:
	var player: PlayerState = state.players[pi]
	if player.active_pokemon == null or player.bench.is_empty():
		return
	var old_active: PokemonSlot = player.active_pokemon
	var new_active: PokemonSlot = chosen_target if chosen_target != null and chosen_target in player.bench else player.bench[0]
	player.bench.erase(new_active)
	old_active.clear_on_leave_active()
	player.bench.append(old_active)
	player.active_pokemon = new_active


func get_description() -> String:
	match target_player:
		"self":    return "替换己方战斗宝可梦与备战宝可梦"
		"opponent": return "替换对手的战斗宝可梦与备战宝可梦"
		"both":     return "双方各替换战斗宝可梦与备战宝可梦"
	return ""
