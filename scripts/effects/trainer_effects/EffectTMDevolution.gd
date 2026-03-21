class_name EffectTMDevolution
extends BaseEffect

const GRANTED_ATTACK_ID := "tm_devolution"


func get_granted_attacks(_pokemon: PokemonSlot, _state: GameState) -> Array[Dictionary]:
	return [{
		"id": GRANTED_ATTACK_ID,
		"name": "退化",
		"cost": "C",
		"damage": "",
		"text": "Devolve each of your opponent's evolved Pokemon by putting the highest Stage Evolution card on it into your opponent's hand.",
	}]


func execute_granted_attack(attacker: PokemonSlot, attack_data: Dictionary, state: GameState, _targets: Array = []) -> void:
	if str(attack_data.get("id", "")) != GRANTED_ATTACK_ID:
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var opponent: PlayerState = state.players[1 - top.owner_index]
	_devolve_slot(opponent, opponent.active_pokemon)
	for slot: PokemonSlot in opponent.bench:
		_devolve_slot(opponent, slot)


func discard_at_end_of_turn(_slot: PokemonSlot, _state: GameState) -> bool:
	return true


func _devolve_slot(owner: PlayerState, slot: PokemonSlot) -> void:
	if slot == null or slot.pokemon_stack.size() <= 1:
		return
	var removed: CardInstance = slot.pokemon_stack.pop_back()
	owner.hand.append(removed)


func get_description() -> String:
	return "Grants a temporary attack that devolves each of your opponent's evolved Pokemon."
