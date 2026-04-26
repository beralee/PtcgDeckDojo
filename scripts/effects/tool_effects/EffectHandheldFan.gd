class_name EffectHandheldFan
extends BaseEffect

const STEP_ID := "handheld_fan_assignment"


func can_trigger(attacker: PokemonSlot, defender: PokemonSlot, state: GameState) -> bool:
	if attacker == null or defender == null or state == null:
		return false
	if defender.attached_tool == null or defender.attached_tool.card_data == null:
		return false
	if state.players[0].active_pokemon != defender and state.players[1].active_pokemon != defender:
		return false
	var attacker_owner: int = _get_owner_index(attacker, state)
	if attacker_owner < 0:
		return false
	return not attacker.attached_energy.is_empty() and not state.players[attacker_owner].bench.is_empty()


func get_trigger_interaction_steps(attacker: PokemonSlot, defender: PokemonSlot, state: GameState) -> Array[Dictionary]:
	if not can_trigger(attacker, defender, state):
		return []
	var attacker_owner: int = _get_owner_index(attacker, state)
	var defender_owner: int = _get_owner_index(defender, state)
	if attacker_owner < 0 or defender_owner < 0:
		return []
	var source_items: Array = attacker.attached_energy.duplicate()
	var source_labels: Array[String] = []
	for energy: CardInstance in source_items:
		source_labels.append(energy.card_data.name if energy != null and energy.card_data != null else "")
	var target_items: Array = state.players[attacker_owner].bench.duplicate()
	var target_labels: Array[String] = []
	for slot: PokemonSlot in target_items:
		target_labels.append(slot.get_pokemon_name())
	var step: Dictionary = build_card_assignment_step(
		STEP_ID,
		"选择要转移的能量与对手的备战宝可梦",
		source_items,
		source_labels,
		target_items,
		target_labels,
		1,
		1,
		false
	)
	step["chooser_player_index"] = defender_owner
	return [step]


func apply(attacker: PokemonSlot, defender: PokemonSlot, state: GameState, targets: Array = []) -> Dictionary:
	if not can_trigger(attacker, defender, state):
		return {}
	var resolved: Dictionary = _resolve_assignment(attacker, defender, state, targets)
	var energy: CardInstance = resolved.get("energy", null)
	var target: PokemonSlot = resolved.get("target", null)
	if energy == null or target == null:
		return {}
	attacker.attached_energy.erase(energy)
	target.attached_energy.append(energy)
	return {
		"energy": energy,
		"target": target,
	}


func get_description() -> String:
	return "身上放有这张卡牌的宝可梦，在战斗场上受到对手宝可梦的招式的伤害时，选择使用了招式的宝可梦身上附着的1个能量，转附于对手的备战宝可梦身上。"


func _get_owner_index(slot: PokemonSlot, state: GameState) -> int:
	for player_index: int in state.players.size():
		if slot in state.players[player_index].get_all_pokemon():
			return player_index
	return -1


func _resolve_assignment(attacker: PokemonSlot, defender: PokemonSlot, state: GameState, targets: Array) -> Dictionary:
	var attacker_owner: int = _get_owner_index(attacker, state)
	var defender_owner: int = _get_owner_index(defender, state)
	if attacker_owner < 0 or defender_owner < 0:
		return {}
	var attacker_player: PlayerState = state.players[attacker_owner]
	var ctx: Dictionary = get_interaction_context(targets)
	var raw_assignments: Array = ctx.get(STEP_ID, [])
	for entry: Variant in raw_assignments:
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		var source: Variant = assignment.get("source", null)
		var target: Variant = assignment.get("target", null)
		if source is CardInstance and target is PokemonSlot:
			var chosen_energy: CardInstance = source
			var chosen_target: PokemonSlot = target
			if chosen_energy in attacker.attached_energy and chosen_target in attacker_player.bench:
				return {
					"energy": chosen_energy,
					"target": chosen_target,
				}
	if attacker.attached_energy.is_empty() or attacker_player.bench.is_empty():
		return {}
	return {
		"energy": attacker.attached_energy[0],
		"target": attacker_player.bench[0],
	}
