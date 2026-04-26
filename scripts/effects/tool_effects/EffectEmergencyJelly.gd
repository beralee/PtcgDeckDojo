class_name EffectEmergencyJelly
extends BaseEffect


func discard_at_end_of_turn(slot: PokemonSlot, _state: GameState) -> bool:
	if slot == null or slot.damage_counters <= 0:
		return false
	if slot.get_remaining_hp() > 30:
		return false
	slot.damage_counters = maxi(0, slot.damage_counters - 120)
	return true
