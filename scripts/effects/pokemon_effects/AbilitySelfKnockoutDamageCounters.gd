class_name AbilitySelfKnockoutDamageCounters
extends BaseEffect

const USED_FLAG_TYPE := "ability_self_knockout_damage_counters_used"

var counter_count: int = 5


func _init(count: int = 5) -> void:
	counter_count = count


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	for effect_data: Dictionary in pokemon.effects:
		if effect_data.get("type", "") == USED_FLAG_TYPE and effect_data.get("turn", -1) == state.turn_number:
			return false
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	return not state.players[1 - top.owner_index].get_all_pokemon().is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var items: Array = opponent.get_all_pokemon()
	var labels: Array[String] = []
	for slot: PokemonSlot in items:
		labels.append(slot.get_pokemon_name())
	return [{
		"id": "self_ko_target",
		"title": "选择对手的1只宝可梦放置伤害指示物",
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
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("self_ko_target", [])
	if selected_raw.is_empty() or not selected_raw[0] is PokemonSlot:
		return
	var target: PokemonSlot = selected_raw[0]
	if target not in opponent.get_all_pokemon():
		return
	target.damage_counters += counter_count * 10
	pokemon.damage_counters = pokemon.get_max_hp()
	pokemon.effects.append({"type": USED_FLAG_TYPE, "turn": state.turn_number})


func get_description() -> String:
	return "Knock Out this Pokemon and place damage counters on an opponent Pokemon."
