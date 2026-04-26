class_name AbilitySubjugatingChains
extends BaseEffect

const STEP_ID := "subjugating_chains_target"
const SHARED_KEY := "subjugating_chains"


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var pi: int = top.owner_index
	if state.current_player_index != pi:
		return false
	var player: PlayerState = state.players[pi]
	if _find_bench_index(player, pokemon) == -1:
		return false
	if int(state.shared_turn_flags.get("%s_%d" % [SHARED_KEY, pi], -1)) == state.turn_number:
		return false
	return not _get_valid_targets(player).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = _get_valid_targets(player)
	if items.is_empty():
		return []
	var labels: Array[String] = []
	for slot: PokemonSlot in items:
		labels.append(slot.get_pokemon_name())
	return [{
		"id": STEP_ID,
		"title": "Choose 1 of your Benched Darkness Pokemon to switch into the Active Spot",
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
	if not can_use_ability(pokemon, state):
		return
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var pi: int = top.owner_index
	var player: PlayerState = state.players[pi]
	var valid_targets: Array = _get_valid_targets(player)
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get(STEP_ID, [])
	var chosen: PokemonSlot = null
	if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot and selected_raw[0] in valid_targets:
		chosen = selected_raw[0]
	elif not valid_targets.is_empty():
		chosen = valid_targets[0]
	if chosen == null:
		return

	var old_active := player.active_pokemon
	var bench_idx: int = _find_bench_index(player, chosen)
	if bench_idx == -1 or old_active == null:
		return
	player.bench.remove_at(bench_idx)
	old_active.clear_on_leave_active()
	player.bench.append(old_active)
	player.active_pokemon = chosen
	player.active_pokemon.set_status("poisoned", true)
	state.shared_turn_flags["%s_%d" % [SHARED_KEY, pi]] = state.turn_number


func _get_valid_targets(player: PlayerState) -> Array:
	var result: Array = []
	for slot: PokemonSlot in player.bench:
		if slot == null:
			continue
		var cd: CardData = slot.get_card_data()
		if cd == null or cd.energy_type != "D":
			continue
		if _is_pecharunt_ex(cd):
			continue
		result.append(slot)
	return result


func _is_pecharunt_ex(cd: CardData) -> bool:
	if cd == null:
		return false
	return cd.effect_id == "e92d1881bfe5e0b957b87c93cd757fc7" or cd.name_en == "Pecharunt ex" or cd.name == "桃歹郎ex"


func _find_bench_index(player: PlayerState, candidate: PokemonSlot) -> int:
	if player == null or candidate == null:
		return -1
	var candidate_top: CardInstance = candidate.get_top_card()
	var candidate_id: int = candidate_top.instance_id if candidate_top != null else -1
	for i: int in player.bench.size():
		var bench_slot: PokemonSlot = player.bench[i]
		if bench_slot == candidate:
			return i
		if candidate_id == -1 or bench_slot == null:
			continue
		var bench_top: CardInstance = bench_slot.get_top_card()
		if bench_top != null and bench_top.instance_id == candidate_id:
			return i
	return -1


func get_description() -> String:
	return "Once during your turn, switch 1 of your Benched Darkness Pokemon, except Pecharunt ex, with your Active Pokemon. The new Active Pokemon is now Poisoned."
