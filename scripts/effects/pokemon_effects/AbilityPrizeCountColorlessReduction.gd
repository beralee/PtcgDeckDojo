class_name AbilityPrizeCountColorlessReduction
extends BaseEffect

var attack_name: String = ""


func _init(required_attack_name: String = "") -> void:
	attack_name = required_attack_name


func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	pass


func get_attack_colorless_cost_modifier(
	pokemon: PokemonSlot,
	attack: Dictionary,
	state: GameState
) -> int:
	if attack_name != "" and str(attack.get("name", "")) != attack_name:
		return 0
	var owner_index: int = pokemon.get_top_card().owner_index if pokemon.get_top_card() != null else -1
	if owner_index == -1:
		return 0
	var opponent_index: int = 1 - owner_index
	var prizes_taken_by_opponent: int = 6 - state.players[opponent_index].prizes.size()
	var colorless_count := 0
	var cost: String = CardData.normalize_attack_cost(attack.get("cost", ""))
	for symbol: String in cost:
		if symbol == "C":
			colorless_count += 1
	return -mini(prizes_taken_by_opponent, colorless_count)


func get_description() -> String:
	return "这只宝可梦的招式所需能量减少与对手已获得奖赏卡张数相同数量的无色能量。"
