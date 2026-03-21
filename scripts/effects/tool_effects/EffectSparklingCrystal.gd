class_name EffectSparklingCrystal
extends BaseEffect


func get_attack_any_cost_modifier(attacker: PokemonSlot, _attack: Dictionary, _state: GameState) -> int:
	var card_data: CardData = attacker.get_card_data()
	if card_data == null:
		return 0
	return -1 if card_data.ancient_trait == "Tera" else 0


func get_description() -> String:
	return "The attacks of the attached Tera Pokemon cost 1 less Energy."
