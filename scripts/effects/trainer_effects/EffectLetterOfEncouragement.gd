class_name EffectLetterOfEncouragement
extends EffectSearchBasicEnergy


func _init() -> void:
	super(3, 0)


func can_execute(card: CardInstance, state: GameState) -> bool:
	if state.last_knockout_turn_against[card.owner_index] != state.turn_number - 1:
		return false
	return super.can_execute(card, state)


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	if state.last_knockout_turn_against[card.owner_index] != state.turn_number - 1:
		return false
	return super.can_headless_execute(card, state)
