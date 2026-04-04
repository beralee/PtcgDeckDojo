class_name AIDecisionTrace
extends RefCounted

var turn_number: int = -1
var phase: String = ""
var player_index: int = -1
var state_features: Array = []
var legal_actions: Array = []
var scored_actions: Array = []
var chosen_action: Dictionary = {}
var reason_tags: Array = []
var used_mcts: bool = false


func clone():
	var copy: Object = get_script().new()
	copy.turn_number = turn_number
	copy.phase = phase
	copy.player_index = player_index
	copy.state_features = state_features.duplicate(true)
	copy.legal_actions = legal_actions.duplicate(true)
	copy.scored_actions = scored_actions.duplicate(true)
	copy.chosen_action = chosen_action.duplicate(true)
	copy.reason_tags = reason_tags.duplicate(true)
	copy.used_mcts = used_mcts
	return copy


func to_dictionary() -> Dictionary:
	return {
		"turn_number": turn_number,
		"phase": phase,
		"player_index": player_index,
		"state_features": state_features.duplicate(true),
		"legal_actions": legal_actions.duplicate(true),
		"scored_actions": scored_actions.duplicate(true),
		"chosen_action": chosen_action.duplicate(true),
		"reason_tags": reason_tags.duplicate(true),
		"used_mcts": used_mcts,
	}
