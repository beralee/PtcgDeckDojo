## VSTAR power: summon colorless non-rule-box Pokemon from discard to bench.
class_name AbilityVSTARSummon
extends BaseEffect

var max_count: int = 2


func _init(count: int = 2) -> void:
	max_count = count


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var pi: int = top.owner_index

	if state.vstar_power_used[pi]:
		return false

	var player: PlayerState = state.players[pi]
	if player.is_bench_full():
		return false

	return _has_valid_target(player.discard_pile)


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var bench_space: int = 5 - player.bench.size()
	var actual_max: int = mini(max_count, bench_space)
	if actual_max <= 0:
		return []

	var items: Array = []
	var labels: Array[String] = []
	for discard_card: CardInstance in player.discard_pile:
		if _is_valid_target(discard_card):
			items.append(discard_card)
			labels.append("%s (HP %d)" % [discard_card.card_data.name, discard_card.card_data.hp])

	if items.is_empty():
		return []

	return [{
		"id": "summon_targets",
		"title": "从弃牌区选择要放入备战区的宝可梦",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": mini(actual_max, items.size()),
		"allow_cancel": true,
	}]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var pi: int = top.owner_index
	var player: PlayerState = state.players[pi]

	var bench_space: int = 5 - player.bench.size()
	var actual_max: int = mini(max_count, bench_space)
	if actual_max <= 0:
		return

	var selected: Array[CardInstance] = []
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("summon_targets", [])
	for entry: Variant in selected_raw:
		if entry is CardInstance and _is_valid_target(entry) and entry in player.discard_pile and entry not in selected:
			selected.append(entry)
			if selected.size() >= actual_max:
				break

	if selected.is_empty():
		for card: CardInstance in player.discard_pile:
			if selected.size() >= actual_max:
				break
			if _is_valid_target(card):
				selected.append(card)

	if selected.is_empty():
		return

	for poke_card: CardInstance in selected:
		var discard_idx: int = player.discard_pile.find(poke_card)
		if discard_idx == -1 or player.is_bench_full():
			continue
		player.discard_pile.remove_at(discard_idx)
		poke_card.face_up = true
		var slot := PokemonSlot.new()
		slot.pokemon_stack.append(poke_card)
		slot.turn_played = state.turn_number
		player.bench.append(slot)

	state.vstar_power_used[pi] = true


func _has_valid_target(discard_pile: Array[CardInstance]) -> bool:
	for card: CardInstance in discard_pile:
		if _is_valid_target(card):
			return true
	return false


func _is_valid_target(card: CardInstance) -> bool:
	var cd: CardData = card.card_data
	if cd == null:
		return false
	if not cd.is_pokemon():
		return false
	if cd.energy_type != "C":
		return false
	return not cd.is_rule_box_pokemon()


func get_description() -> String:
	return "VSTAR力量：从弃牌区选择最多%d只无色非规则宝可梦放入备战区。" % max_count
