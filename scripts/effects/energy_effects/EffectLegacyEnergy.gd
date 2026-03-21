class_name EffectLegacyEnergy
extends BaseEffect

const CONSUMED_KEY := "legacy_energy_prize_reduction_used"


func provides_any_type() -> bool:
	return true


func get_energy_count() -> int:
	return 1


func get_knockout_prize_modifier(slot: PokemonSlot, state: GameState) -> int:
	if slot == null or slot.get_top_card() == null:
		return 0
	var owner_index: int = slot.get_top_card().owner_index
	var key := "%s_%d" % [CONSUMED_KEY, owner_index]
	return 0 if bool(state.shared_turn_flags.get(key, false)) else -1


func mark_knockout_prize_modifier_consumed(slot: PokemonSlot, state: GameState) -> void:
	if slot == null or slot.get_top_card() == null:
		return
	var owner_index: int = slot.get_top_card().owner_index
	var key := "%s_%d" % [CONSUMED_KEY, owner_index]
	state.shared_turn_flags[key] = true


func get_description() -> String:
	return "Provides every type of Energy. The attached Pokemon gives up 1 fewer Prize card once per game."
