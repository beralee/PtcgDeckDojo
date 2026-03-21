class_name AttackRevengeBonus
extends BaseEffect

var bonus_damage: int = 120


func _init(bonus: int = 120) -> void:
	bonus_damage = bonus


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top_card: CardInstance = attacker.get_top_card()
	if top_card == null:
		return

	var player: PlayerState = state.players[top_card.owner_index]
	var had_ko_last_turn := false
	for slot: PokemonSlot in player.get_all_pokemon():
		for effect: Dictionary in slot.effects:
			if effect.get("type", "") == "pokemon_ko_last_turn":
				had_ko_last_turn = true
				break
		if had_ko_last_turn:
			break

	if had_ko_last_turn:
		defender.damage_counters += bonus_damage


func get_description() -> String:
	return "Deal extra damage if one of your Pokemon was KO'd last turn."
