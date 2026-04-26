class_name EffectLuxuriousCape
extends BaseEffect


func get_hp_modifier(slot: PokemonSlot, _state: GameState = null) -> int:
	if _applies(slot):
		return 100
	return 0


func get_knockout_prize_modifier(slot: PokemonSlot, _state: GameState) -> int:
	if _applies(slot):
		return 1
	return 0


func _applies(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	return not slot.get_card_data().is_rule_box_pokemon()
