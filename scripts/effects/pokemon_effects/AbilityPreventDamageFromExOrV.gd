class_name AbilityPreventDamageFromExOrV
extends BaseEffect


func prevents_damage_from(attacker: PokemonSlot, _defender: PokemonSlot, _state: GameState) -> bool:
	return _is_ex_or_v(attacker)


func get_description() -> String:
	return "这只宝可梦，不受到对手宝可梦【ex】・【V】的招式的伤害。"


func _is_ex_or_v(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	var data: CardData = slot.get_card_data()
	if data == null:
		return false
	return data.mechanic == "ex" or data.mechanic == "V"
