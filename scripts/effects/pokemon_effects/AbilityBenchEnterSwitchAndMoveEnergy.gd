class_name AbilityBenchEnterSwitchAndMoveEnergy
extends AbilityOnBenchEnter

const STEP_ID := "iron_leaves_energy_to_move"
const USED_FLAG_TYPE := "ability_bench_enter_switch_and_move_energy_used"


func _init() -> void:
	super._init("rush_in")


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if not super.can_use_ability(pokemon, state):
		return false
	for effect_data: Dictionary in pokemon.effects:
		if effect_data.get("type", "") == USED_FLAG_TYPE and effect_data.get("turn", -1) == state.turn_number:
			return false
	return true


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null or card.owner_index < 0 or card.owner_index >= state.players.size():
		return []
	var player: PlayerState = state.players[card.owner_index]
	var energy_items: Array = []
	var energy_labels: Array[String] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null:
			continue
		for energy: CardInstance in slot.attached_energy:
			if energy == null or energy.card_data == null:
				continue
			energy_items.append(energy)
			energy_labels.append("%s from %s" % [energy.card_data.name, slot.get_pokemon_name()])
	if energy_items.is_empty():
		return []
	return [{
		"id": STEP_ID,
		"title": "Choose any amount of Energy to move onto this Pokemon",
		"items": energy_items,
		"labels": energy_labels,
		"min_select": 0,
		"max_select": energy_items.size(),
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
	var player: PlayerState = state.players[top.owner_index]
	var bench_idx: int = player.bench.find(pokemon)
	if bench_idx == -1 or player.active_pokemon == null:
		return
	var old_active: PokemonSlot = player.active_pokemon

	player.bench.remove_at(bench_idx)
	player.active_pokemon = pokemon
	old_active.clear_on_leave_active()
	player.bench.append(old_active)

	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get(STEP_ID, [])
	var moved_ids: Dictionary = {}
	for entry: Variant in selected_raw:
		if not (entry is CardInstance):
			continue
		var energy := entry as CardInstance
		if moved_ids.has(energy.instance_id):
			continue
		var source := _find_slot_for_energy(player, energy)
		if source == null or source == pokemon:
			continue
		source.attached_energy.erase(energy)
		pokemon.attached_energy.append(energy)
		moved_ids[energy.instance_id] = true

	pokemon.effects.append({
		"type": USED_FLAG_TYPE,
		"turn": state.turn_number,
	})


func _find_slot_for_energy(player: PlayerState, energy: CardInstance) -> PokemonSlot:
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and energy in slot.attached_energy:
			return slot
	return null


func get_description() -> String:
	return "When this Pokemon enters play from your hand onto the Bench, switch it with your Active Pokemon and move any chosen Energy onto it."
