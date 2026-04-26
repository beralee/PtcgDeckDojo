class_name AbilityBasicVLock
extends BaseEffect

const SPIRITOMB_EFFECT_ID := "db7b9902fd4fed3b6f9d94a7ee7a12ba"


static func is_locked(slot: PokemonSlot, state: GameState) -> bool:
	if slot == null or state == null:
		return false
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return false
	if cd.stage != "Basic":
		return false
	if cd.mechanic != "V":
		return false
	for pi: int in state.players.size():
		for source_slot: PokemonSlot in state.players[pi].get_all_pokemon():
			if _is_live_lock_source(source_slot, state):
				return true
	return false


static func _is_live_lock_source(slot: PokemonSlot, state: GameState) -> bool:
	if slot == null:
		return false
	var cd: CardData = slot.get_card_data()
	if cd == null or cd.effect_id != SPIRITOMB_EFFECT_ID:
		return false
	if _is_lock_source_suppressed(slot, state):
		return false
	return true


static func _is_lock_source_suppressed(slot: PokemonSlot, state: GameState) -> bool:
	for eff: Dictionary in slot.effects:
		if eff.get("type", "") == "ability_disabled" and int(eff.get("turn", -999)) == state.turn_number:
			return true
	if AbilityBasicLock.is_locked_by_basic_lock(slot, state):
		return true
	if AbilityDisableOpponentAbility.is_locked_by_dark_wing(slot, state):
		return true
	return false


func get_description() -> String:
	return "只要这只宝可梦在场上，双方场上的基础宝可梦【V】的特性全部消除。"
