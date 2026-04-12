## Triggered ability that resolves when a Pokemon enters the bench.
class_name AbilityOnBenchEnter
extends BaseEffect

var effect_type: String = "search_supporter"

const TRIGGERED_KEY: String = "ability_bench_enter_triggered"


func _init(eff_type: String = "search_supporter") -> void:
	effect_type = eff_type


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	if pokemon.turn_played != state.turn_number:
		return false
	for eff: Dictionary in pokemon.effects:
		if eff.get("type") == TRIGGERED_KEY and eff.get("turn") == state.turn_number:
			return false

	var player: PlayerState = state.players[top.owner_index]
	match effect_type:
		"search_supporter":
			return _has_supporter(player.deck)
		"rush_in":
			return player.active_pokemon != null and player.bench.has(pokemon)
		_:
			return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	match effect_type:
		"search_supporter":
			var items: Array = []
			var labels: Array[String] = []
			for deck_card: CardInstance in player.deck:
				if deck_card.card_data != null and deck_card.card_data.card_type == "Supporter":
					items.append(deck_card)
					labels.append("%s [%s]" % [deck_card.card_data.name, deck_card.card_data.card_type])
			if items.is_empty():
				return []
			return [{
				"id": "supporter_card",
				"title": "从牌库中选择1张支援者加入手牌",
				"items": items,
				"labels": labels,
				"min_select": 1,
				"max_select": 1,
				"allow_cancel": true,
			}]
		_:
			return []


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

	match effect_type:
		"search_supporter":
			_search_supporter(player, targets)
		"rush_in":
			_rush_in(pokemon, player, targets)

	pokemon.effects.append({
		"type": TRIGGERED_KEY,
		"turn": state.turn_number,
	})


func _search_supporter(player: PlayerState, targets: Array) -> void:
	if player.deck.is_empty():
		return

	var found_idx: int = -1
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("supporter_card", [])
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance:
		found_idx = player.deck.find(selected_raw[0] as CardInstance)
	elif targets.size() > 0 and targets[0] is CardInstance:
		found_idx = player.deck.find(targets[0] as CardInstance)

	if found_idx == -1:
		for idx: int in player.deck.size():
			var card: CardInstance = player.deck[idx]
			if card.card_data != null and card.card_data.card_type == "Supporter":
				found_idx = idx
				break

	if found_idx == -1:
		return

	var supporter: CardInstance = player.deck[found_idx]
	if supporter.card_data == null or supporter.card_data.card_type != "Supporter":
		return
	player.deck.remove_at(found_idx)
	supporter.face_up = true
	player.hand.append(supporter)
	player.shuffle_deck()


func _rush_in(
	pokemon: PokemonSlot,
	player: PlayerState,
	targets: Array
) -> void:
	var bench_idx: int = player.bench.find(pokemon)
	if bench_idx == -1:
		return

	var old_active: PokemonSlot = player.active_pokemon
	if old_active == null:
		return

	player.bench.remove_at(bench_idx)
	player.active_pokemon = pokemon
	if not player.is_bench_full():
		old_active.clear_on_leave_active()
		player.bench.append(old_active)

	if targets.size() > 0 and targets[0] is PokemonSlot:
		var energy_target: PokemonSlot = targets[0] as PokemonSlot
		for energy: CardInstance in old_active.attached_energy:
			energy_target.attached_energy.append(energy)
		old_active.attached_energy.clear()


func _has_supporter(deck: Array[CardInstance]) -> bool:
	for card: CardInstance in deck:
		if card.card_data != null and card.card_data.card_type == "Supporter":
			return true
	return false


func get_description() -> String:
	match effect_type:
		"search_supporter":
			return "特性：这只宝可梦上场到备战区时，从牌库中选择1张支援者加入手牌。"
		"rush_in":
			return "特性：这只宝可梦上场到备战区时，可换到战斗场。"
	return "特性：进入备战区时触发。"
