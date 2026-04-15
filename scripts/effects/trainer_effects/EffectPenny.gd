## 牡丹 - 选择己方1只基础宝可梦，将其及身上所有卡放回手牌
class_name EffectPenny
extends BaseEffect

const TARGET_STEP_ID := "penny_target"
const REPLACEMENT_STEP_ID := "penny_replacement"


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not _get_valid_targets(player).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var targets: Array[PokemonSlot] = _get_valid_targets(player)
	if targets.is_empty():
		return []

	var items: Array = []
	var labels: Array[String] = []
	for slot: PokemonSlot in targets:
		items.append(slot)
		labels.append(_build_slot_label(slot))

	var steps: Array[Dictionary] = [{
		"id": TARGET_STEP_ID,
		"title": "选择1只基础宝可梦放回手牌",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]

	if player.active_pokemon != null and player.active_pokemon in targets and not player.bench.is_empty():
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
	var target: PokemonSlot = _get_selected_target(ctx, player)
	if target == null:
		return

	var is_active: bool = (target == player.active_pokemon)
	var replacement: PokemonSlot = null
	if is_active:
		replacement = _get_selected_replacement(ctx, player)
		if replacement == null:
			return

	_return_slot_cards_to_hand(target, player)

	if is_active:
		player.active_pokemon = replacement
		player.bench.erase(replacement)
	else:
		player.bench.erase(target)


func _is_basic(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	var cd: CardData = slot.get_card_data()
	return cd != null and cd.stage == "Basic"


func _get_valid_targets(player: PlayerState) -> Array[PokemonSlot]:
	var targets: Array[PokemonSlot] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		if not _is_basic(slot):
			continue
		if slot == player.active_pokemon and player.bench.is_empty():
			continue
		targets.append(slot)
	return targets


func _build_slot_label(slot: PokemonSlot) -> String:
	return "%s (HP %d/%d)" % [
		slot.get_pokemon_name(),
		slot.get_remaining_hp(),
		slot.get_max_hp(),
	]


func _get_selected_target(ctx: Dictionary, player: PlayerState) -> PokemonSlot:
	var valid_targets: Array[PokemonSlot] = _get_valid_targets(player)
	var raw: Array = ctx.get(TARGET_STEP_ID, [])
	if not raw.is_empty() and raw[0] is PokemonSlot:
		var selected: PokemonSlot = raw[0]
		if selected in valid_targets:
			return selected
	if not valid_targets.is_empty():
		return valid_targets[0]
	return null


func _get_selected_replacement(ctx: Dictionary, player: PlayerState) -> PokemonSlot:
	if player.bench.is_empty():
		return null
	var raw: Array = ctx.get(REPLACEMENT_STEP_ID, [])
	if not raw.is_empty() and raw[0] is PokemonSlot:
		var selected: PokemonSlot = raw[0]
		if selected in player.bench:
			return selected
	return player.bench[0]


func _return_slot_cards_to_hand(slot: PokemonSlot, player: PlayerState) -> void:
	for pokemon_card: CardInstance in slot.pokemon_stack:
		pokemon_card.face_up = true
		player.hand.append(pokemon_card)
	for energy_card: CardInstance in slot.attached_energy:
		energy_card.face_up = true
		player.hand.append(energy_card)
	if slot.attached_tool != null:
		slot.attached_tool.face_up = true
		player.hand.append(slot.attached_tool)
	slot.pokemon_stack.clear()
	slot.attached_energy.clear()
	slot.attached_tool = null
	slot.damage_counters = 0
	slot.clear_all_status()


func get_description() -> String:
	return "选择己方1只基础宝可梦，将其及身上所有卡放回手牌"
