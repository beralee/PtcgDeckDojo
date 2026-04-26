class_name AttackDragonLauncher
extends BaseEffect

const DREEPY_EFFECT_ID := "e793842faf5a8017e5456f898b1bf9d2"
const DISCARD_STEP_ID := "dragon_launcher_dreepy"
const TARGET_STEP_ID := "dragon_launcher_targets"

var damage_amount: int = 100
var attack_index_to_match: int = -1


func _init(damage: int = 100, match_attack_index: int = -1) -> void:
	damage_amount = damage
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var dreepy_slots: Array[PokemonSlot] = _get_benched_dreepy(player)
	var max_count: int = mini(dreepy_slots.size(), opponent.get_all_pokemon().size())
	if max_count <= 0:
		return []
	var labels: Array[String] = []
	for slot: PokemonSlot in dreepy_slots:
		labels.append(slot.get_pokemon_name())
	return [{
		"id": DISCARD_STEP_ID,
		"title": "Choose up to %d Dreepy to discard" % max_count,
		"items": dreepy_slots,
		"labels": labels,
		"min_select": 0,
		"max_select": max_count,
		"allow_cancel": false,
	}]


func get_followup_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState,
	resolved_context: Dictionary
) -> Array[Dictionary]:
	if card == null or state == null:
		return []
	var selected_count: int = _get_selected_dreepy_count(resolved_context)
	if selected_count <= 0:
		return []
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var targets: Array = opponent.get_all_pokemon()
	if targets.is_empty():
		return []
	var labels: Array[String] = []
	for slot: PokemonSlot in targets:
		labels.append(slot.get_pokemon_name())
	return [{
		"id": TARGET_STEP_ID,
		"title": "Choose %d opponent Pokemon" % selected_count,
		"items": targets,
		"labels": labels,
		"min_select": selected_count,
		"max_select": selected_count,
		"allow_cancel": false,
	}]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var ctx: Dictionary = get_attack_interaction_context()

	var selected_dreepy: Array[PokemonSlot] = _get_selected_dreepy_slots(ctx, player)
	if selected_dreepy.is_empty():
		return
	var selected_targets: Array[PokemonSlot] = _get_selected_targets(ctx, opponent, selected_dreepy.size())
	if selected_targets.size() != selected_dreepy.size():
		return

	for slot: PokemonSlot in selected_dreepy:
		if slot not in player.bench:
			continue
		player.bench.erase(slot)
		for card: CardInstance in slot.collect_all_cards():
			player.discard_pile.append(card)
		slot.pokemon_stack.clear()
		slot.attached_energy.clear()
		slot.attached_tool = null

	for target: PokemonSlot in selected_targets:
		if target in opponent.bench and AbilityBenchImmune.has_bench_immune(target):
			continue
		if AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(target, state):
			continue
		DamageCalculator.new().apply_damage_to_slot(target, damage_amount)


func _get_benched_dreepy(player: PlayerState) -> Array[PokemonSlot]:
	var result: Array[PokemonSlot] = []
	if player == null:
		return result
	for slot: PokemonSlot in player.bench:
		if _is_dreepy(slot):
			result.append(slot)
	return result


func _is_dreepy(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	var top: CardInstance = slot.get_top_card()
	if top == null or top.card_data == null:
		return false
	var cd: CardData = top.card_data
	return str(cd.effect_id) == DREEPY_EFFECT_ID or str(cd.name_en) == "Dreepy"


func _get_selected_dreepy_count(context: Dictionary) -> int:
	var selected_raw: Array = context.get(DISCARD_STEP_ID, [])
	return selected_raw.size()


func _get_selected_dreepy_slots(context: Dictionary, player: PlayerState) -> Array[PokemonSlot]:
	var selected_raw: Array = context.get(DISCARD_STEP_ID, [])
	var result: Array[PokemonSlot] = []
	var seen: Dictionary = {}
	for entry: Variant in selected_raw:
		if not (entry is PokemonSlot):
			continue
		var slot: PokemonSlot = entry as PokemonSlot
		if slot in player.bench and _is_dreepy(slot) and not seen.has(slot.get_instance_id()):
			seen[slot.get_instance_id()] = true
			result.append(slot)
	return result


func _get_selected_targets(context: Dictionary, opponent: PlayerState, expected_count: int) -> Array[PokemonSlot]:
	var selected_raw: Array = context.get(TARGET_STEP_ID, [])
	var all_targets: Array = opponent.get_all_pokemon()
	var result: Array[PokemonSlot] = []
	var seen: Dictionary = {}
	for entry: Variant in selected_raw:
		if not (entry is PokemonSlot):
			continue
		var slot: PokemonSlot = entry as PokemonSlot
		if slot in all_targets and not seen.has(slot.get_instance_id()):
			seen[slot.get_instance_id()] = true
			result.append(slot)
			if result.size() >= expected_count:
				break
	return result


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if attack.has("_override_attack_index"):
		return int(attack.get("_override_attack_index", -1))
	if card == null or card.card_data == null:
		return -1
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return -1


func get_description() -> String:
	return "Discard up to N Dreepy from your Bench, then deal 100 damage to that many opponent Pokemon."
