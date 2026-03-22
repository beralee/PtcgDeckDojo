class_name AbilityLostZoneAttackCostReduction
extends BaseEffect

var required_lost_zone_count: int = 4
var attack_name: String = ""


func _init(required_count: int = 4, required_attack_name: String = "") -> void:
	required_lost_zone_count = required_count
	attack_name = required_attack_name


func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	pass


func get_attack_any_cost_modifier(attacker: PokemonSlot, attack: Dictionary, state: GameState) -> int:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return 0
	if attack_name != "" and str(attack.get("name", "")) != attack_name:
		return 0
	if state.players[top.owner_index].lost_zone.size() < required_lost_zone_count:
		return 0
	var cost: String = CardData.normalize_attack_cost(attack.get("cost", ""))
	return -cost.length()


func get_description() -> String:
	return "Remove all attack costs when the controller has enough cards in the Lost Zone."
