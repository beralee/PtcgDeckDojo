class_name AbilityPreventDamageFromAttackersWithAbilities
extends BaseEffect


func prevents_damage_from(attacker: PokemonSlot, _defender: PokemonSlot, _state: GameState) -> bool:
	var attacker_data: CardData = attacker.get_card_data()
	return attacker_data != null and not attacker_data.abilities.is_empty()


func get_description() -> String:
	return "Prevent all damage from attacks by opponent Pokemon that have Abilities."
