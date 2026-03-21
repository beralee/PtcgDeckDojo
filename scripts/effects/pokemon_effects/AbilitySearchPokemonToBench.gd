## Search up to N matching Basic Pokemon from deck and put them onto the bench.
class_name AbilitySearchPokemonToBench
extends BaseEffect

var energy_filter: String = "L"
var max_count: int = 2

const USED_KEY: String = "ability_search_pokemon_to_bench_used"


func _init(e_filter: String = "L", count: int = 2) -> void:
	energy_filter = e_filter
	max_count = count


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var player: PlayerState = state.players[top.owner_index]

	for eff: Dictionary in pokemon.effects:
		if eff.get("type") == USED_KEY and eff.get("turn") == state.turn_number:
			return false

	if player.is_bench_full():
		return false

	return _has_matching_pokemon(player.deck)


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var bench_space: int = 5 - player.bench.size()
	var actual_max: int = mini(max_count, bench_space)
	if actual_max <= 0:
		return []

	var items: Array = []
	var labels: Array[String] = []
	for deck_card: CardInstance in player.deck:
		if _matches_pokemon(deck_card):
			items.append(deck_card)
			labels.append("%s (HP %d)" % [deck_card.card_data.name, deck_card.card_data.hp])

	if items.is_empty():
		return []

	return [{
		"id": "bench_pokemon",
		"title": "选择最多%d只放入备战区的宝可梦" % actual_max,
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
	var player: PlayerState = state.players[top.owner_index]

	var bench_space: int = 5 - player.bench.size()
	var actual_max: int = mini(max_count, bench_space)
	if actual_max <= 0:
		return

	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("bench_pokemon", [])
	var found_pokemon: Array[CardInstance] = []
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.deck and _matches_pokemon(entry):
			found_pokemon.append(entry)
			if found_pokemon.size() >= actual_max:
				break

	if found_pokemon.is_empty():
		player.shuffle_deck()
		return

	for poke_card: CardInstance in found_pokemon:
		player.deck.erase(poke_card)
		if player.is_bench_full():
			break
		poke_card.face_up = true
		var slot := PokemonSlot.new()
		slot.pokemon_stack.append(poke_card)
		slot.turn_played = state.turn_number
		player.bench.append(slot)

	player.shuffle_deck()

	pokemon.effects.append({
		"type": USED_KEY,
		"turn": state.turn_number,
	})


func _has_matching_pokemon(deck: Array[CardInstance]) -> bool:
	for card: CardInstance in deck:
		if _matches_pokemon(card):
			return true
	return false


func _matches_pokemon(card: CardInstance) -> bool:
	var cd: CardData = card.card_data
	if cd == null:
		return false
	if not cd.is_basic_pokemon():
		return false
	if energy_filter == "":
		return true
	return cd.energy_type == energy_filter


func get_description() -> String:
	return "特性：从牌库中选择最多%d只符合条件的基础宝可梦放入备战区。（每回合1次）" % max_count
