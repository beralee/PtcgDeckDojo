class_name AbilityGustFromBench
extends BaseEffect

const USED_KEY: String = "ability_gust_from_bench_used"


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var pi: int = top.owner_index
	var player: PlayerState = state.players[pi]
	var opponent: PlayerState = state.players[1 - pi]
	if state.current_player_index != pi:
		return false
	if pokemon not in player.bench:
		return false
	if opponent.bench.is_empty():
		return false
	for eff: Dictionary in pokemon.effects:
		if eff.get("type", "") == USED_KEY and eff.get("turn", -1) == state.turn_number:
			return false
	return true


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var labels: Array[String] = []
	for slot: PokemonSlot in opponent.bench:
		labels.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])
	return [{
		"id": "opponent_bench_target",
		"title": "对手选择1只备战宝可梦换到战斗场",
		"items": opponent.bench.duplicate(),
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
		"opponent_chooses": true,
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
	var opponent: PlayerState = state.players[1 - pi]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("opponent_bench_target", [])

	var target_slot: PokemonSlot = null
	if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot:
		var candidate: PokemonSlot = selected_raw[0]
		if candidate in opponent.bench:
			target_slot = candidate
	if target_slot == null:
		target_slot = opponent.bench[0]

	var old_active: PokemonSlot = opponent.active_pokemon
	opponent.bench.erase(target_slot)
	opponent.active_pokemon = target_slot
	if old_active != null:
		old_active.clear_on_leave_active()
		opponent.bench.append(old_active)

	player.bench.erase(pokemon)
	for card: CardInstance in pokemon.pokemon_stack:
		player.discard_pile.append(card)
	for card: CardInstance in pokemon.attached_energy:
		player.discard_pile.append(card)
	if pokemon.attached_tool != null:
		player.discard_pile.append(pokemon.attached_tool)

	pokemon.effects.append({
		"type": USED_KEY,
		"turn": state.turn_number,
	})


func get_description() -> String:
	return "特性：强力吹风机。若这只宝可梦在备战区，则在自己的回合可使用1次。将对手的战斗宝可梦与1只备战宝可梦互换（上场的宝可梦由对手选择），然后将这只宝可梦及其身上附有的所有卡丢弃。"
