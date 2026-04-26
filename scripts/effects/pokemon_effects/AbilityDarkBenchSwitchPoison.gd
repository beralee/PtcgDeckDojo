class_name AbilityDarkBenchSwitchPoison
extends BaseEffect

const STEP_ID := "bench_dark_target"
const USED_FLAG_PREFIX := "pecharunt_ex_chain_"


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or pokemon.get_top_card() == null or state == null:
		return false
	var pi := pokemon.get_top_card().owner_index
	if int(state.shared_turn_flags.get(USED_FLAG_PREFIX + str(pi), -1)) == state.turn_number:
		return false
	var player: PlayerState = state.players[pi]
	for slot: PokemonSlot in player.bench:
		if slot == null or slot == pokemon:
			continue
		var cd := slot.get_card_data()
		if cd != null and cd.energy_type == "D":
			return true
	return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null or state == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for slot: PokemonSlot in player.bench:
		if slot == null:
			continue
		var cd := slot.get_card_data()
		if cd == null or cd.energy_type != "D":
			continue
		if cd.name == card.card_data.name:
			continue
		items.append(slot)
		labels.append(slot.get_pokemon_name())
	if items.is_empty():
		return []
	return [{
		"id": STEP_ID,
		"title": "选择1只备战区的恶属性宝可梦与战斗宝可梦互换",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	if pokemon == null or pokemon.get_top_card() == null or state == null:
		return
	var pi := pokemon.get_top_card().owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected: PokemonSlot = null
	var raw: Array = ctx.get(STEP_ID, [])
	if not raw.is_empty() and raw[0] is PokemonSlot:
		var maybe_slot := raw[0] as PokemonSlot
		if maybe_slot in player.bench:
			selected = maybe_slot
	if selected == null:
		for slot: PokemonSlot in player.bench:
			if slot == null:
				continue
			var cd := slot.get_card_data()
			if cd != null and cd.energy_type == "D" and cd.name != pokemon.get_pokemon_name():
				selected = slot
				break
	if selected == null or player.active_pokemon == null:
		return
	var bench_idx := player.bench.find(selected)
	if bench_idx < 0:
		return
	var old_active := player.active_pokemon
	old_active.clear_on_leave_active()
	player.bench[bench_idx] = old_active
	player.active_pokemon = selected
	player.active_pokemon.status_conditions["poisoned"] = true
	state.shared_turn_flags[USED_FLAG_PREFIX + str(pi)] = state.turn_number


func get_description() -> String:
	return "选择1只备战区的恶属性宝可梦与战斗宝可梦互换，然后令新的战斗宝可梦陷入中毒。"
