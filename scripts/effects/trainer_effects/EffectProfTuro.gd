## 弗图博士的剧本 - 选择己方场上1只宝可梦回手牌，身上附属卡全部弃牌
class_name EffectProfTuro
extends BaseEffect

const TARGET_STEP_ID := "prof_turo_target"
const REPLACEMENT_STEP_ID := "prof_turo_replacement"


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not _get_valid_targets(state.players[card.owner_index]).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var targets: Array[PokemonSlot] = _get_valid_targets(player)
	if targets.is_empty():
		return []

	var target_items: Array = []
	var target_labels: Array[String] = []
	for slot: PokemonSlot in targets:
		target_items.append(slot)
		target_labels.append(_build_slot_label(slot))

	var steps: Array[Dictionary] = [{
		"id": TARGET_STEP_ID,
		"title": "选择1只要回手牌的己方宝可梦",
		"items": target_items,
		"labels": target_labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]

	if _is_live_slot(player.active_pokemon) and player.active_pokemon in targets and not player.bench.is_empty():
		var replacement_items: Array = []
		var replacement_labels: Array[String] = []
		for slot: PokemonSlot in player.bench:
			replacement_items.append(slot)
			replacement_labels.append(_build_slot_label(slot))
		steps.append({
			"id": REPLACEMENT_STEP_ID,
			"title": "选择新的战斗宝可梦",
			"items": replacement_items,
			"labels": replacement_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		})

	return steps


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var target_slot: PokemonSlot = _get_selected_target(ctx, player)
	if target_slot == null:
		return

	var replacement: PokemonSlot = null
	var is_active: bool = target_slot == player.active_pokemon
	if is_active:
		replacement = _get_selected_replacement(ctx, player)
		if replacement == null:
			return

	for pokemon_card: CardInstance in target_slot.pokemon_stack:
		pokemon_card.face_up = true
		player.hand.append(pokemon_card)
	for energy_card: CardInstance in target_slot.attached_energy:
		player.discard_card(energy_card)
	if target_slot.attached_tool != null:
		player.discard_card(target_slot.attached_tool)

	target_slot.pokemon_stack.clear()
	target_slot.attached_energy.clear()
	target_slot.attached_tool = null
	target_slot.effects.clear()
	target_slot.clear_all_status()
	target_slot.damage_counters = 0

	if is_active:
		player.active_pokemon = replacement
		player.bench.erase(replacement)
	else:
		player.bench.erase(target_slot)


func get_description() -> String:
	return "选择己方场上1只宝可梦回手牌，身上附属的所有卡弃牌"


func _get_valid_targets(player: PlayerState) -> Array[PokemonSlot]:
	var targets: Array[PokemonSlot] = []
	if _is_live_slot(player.active_pokemon) and not player.bench.is_empty():
		targets.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null and not slot.pokemon_stack.is_empty():
			targets.append(slot)
	return targets


func _is_live_slot(slot: PokemonSlot) -> bool:
	return slot != null and not slot.pokemon_stack.is_empty()


func _build_slot_label(slot: PokemonSlot) -> String:
	return "%s (HP %d/%d)" % [
		slot.get_pokemon_name(),
		slot.get_remaining_hp(),
		slot.get_max_hp(),
	]


func _get_selected_target(ctx: Dictionary, player: PlayerState) -> PokemonSlot:
	var valid_targets: Array[PokemonSlot] = _get_valid_targets(player)
	var selected_raw: Array = ctx.get(TARGET_STEP_ID, [])
	if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot:
		var candidate: PokemonSlot = selected_raw[0]
		if candidate in valid_targets:
			return candidate
	if not valid_targets.is_empty():
		return valid_targets[0]
	return null


func _get_selected_replacement(ctx: Dictionary, player: PlayerState) -> PokemonSlot:
	if player.bench.is_empty():
		return null
	var selected_raw: Array = ctx.get(REPLACEMENT_STEP_ID, [])
	if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot:
		var candidate: PokemonSlot = selected_raw[0]
		if candidate in player.bench:
			return candidate
	return player.bench[0]
