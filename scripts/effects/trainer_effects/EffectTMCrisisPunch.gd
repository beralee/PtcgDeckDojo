class_name EffectTMCrisisPunch
extends BaseEffect

const GRANTED_ATTACK_ID := "tm_crisis_punch"


func get_granted_attacks(pokemon: PokemonSlot, state: GameState) -> Array[Dictionary]:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return []
	var opponent: PlayerState = state.players[1 - top.owner_index]
	if opponent.prizes.size() != 1:
		return []
	return [{
		"id": GRANTED_ATTACK_ID,
		"name": "临危一击",
		"cost": "CCC",
		"damage": 280,
		"text": "只有在对手剩余 1 张奖赏卡时，才可以使用这个招式。",
	}]


func execute_granted_attack(
	_attacker: PokemonSlot,
	attack_data: Dictionary,
	_state: GameState,
	_targets: Array = []
) -> void:
	if str(attack_data.get("id", "")) != GRANTED_ATTACK_ID:
		return


func discard_at_end_of_turn(_slot: PokemonSlot, _state: GameState) -> bool:
	return true


func get_description() -> String:
	return "赋予招式【临危一击】：只有在对手剩余 1 张奖赏卡时才可使用。回合结束时弃掉这张宝可梦道具。"
