class_name EffectGravityMountain
extends BaseEffect


func get_hp_modifier(slot: PokemonSlot, _state: GameState) -> int:
	var card_data: CardData = slot.get_card_data()
	if card_data == null:
		return 0
	return -30 if card_data.stage == "Stage 2" else 0


func get_description() -> String:
	return "All Stage 2 Pokemon have 30 less HP."
