class_name AbilityMoveOpponentDamageCounters
extends BaseEffect

const USED_FLAG_TYPE := "ability_move_damage_used"


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	for effect_data: Dictionary in pokemon.effects:
		if effect_data.get("type", "") == USED_FLAG_TYPE and effect_data.get("turn", -1) == state.turn_number:
			return false

	var opponent: PlayerState = state.players[1 - top.owner_index]
	var source_count := 0
	for slot: PokemonSlot in opponent.get_all_pokemon():
		if slot.damage_counters >= 10:
			source_count += 1
	return opponent.get_all_pokemon().size() >= 2 and source_count >= 1


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var source_items: Array = []
	var source_labels: Array[String] = []
	var target_items: Array = []
	var target_labels: Array[String] = []
	for slot: PokemonSlot in opponent.get_all_pokemon():
		if slot.damage_counters >= 10:
			source_items.append(slot)
			source_labels.append("%s (%d damage)" % [slot.get_pokemon_name(), slot.damage_counters])
		target_items.append(slot)
		target_labels.append("%s (%d damage)" % [slot.get_pokemon_name(), slot.damage_counters])

	return [
		{
			"id": "source_pokemon",
			"title": "Choose the source opponent Pokemon",
			"items": source_items,
			"labels": source_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
		{
			"id": "target_pokemon",
			"title": "Choose the destination opponent Pokemon",
			"items": target_items,
			"labels": target_labels,
			"exclude_selected_from_step_ids": ["source_pokemon"],
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
		{
			"id": "counter_count",
			"title": "Choose how many counters to move",
			"items": [1, 2],
			"labels": ["Move 1 counter", "Move 2 counters"],
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
	]


func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var source: PokemonSlot = _get_selected_slot(ctx, "source_pokemon", opponent)
	var target: PokemonSlot = _get_selected_slot(ctx, "target_pokemon", opponent)
	if source == null or target == null or source == target:
		return
	var count_raw: Array = ctx.get("counter_count", [])
	var count: int = int(count_raw[0]) if not count_raw.is_empty() else 1
	count = clampi(count, 1, 2)
	var moved_damage: int = mini(count * 10, source.damage_counters)
	if moved_damage <= 0:
		return
	source.damage_counters -= moved_damage
	target.damage_counters += moved_damage
	pokemon.effects.append({"type": USED_FLAG_TYPE, "turn": state.turn_number})


func _get_selected_slot(ctx: Dictionary, key: String, player: PlayerState) -> PokemonSlot:
	var selected_raw: Array = ctx.get(key, [])
	if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot:
		var slot: PokemonSlot = selected_raw[0]
		if slot in player.get_all_pokemon():
			return slot
	return null


func get_description() -> String:
	return "Once during your turn, move up to 2 damage counters from 1 of your opponent's Pokemon to another."
