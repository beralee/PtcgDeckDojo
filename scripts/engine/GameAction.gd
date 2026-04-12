class_name GameAction
extends RefCounted


enum ActionType {
	GAME_START,
	GAME_END,
	TURN_START,
	TURN_END,
	DRAW_CARD,
	MULLIGAN,
	SETUP_PLACE_ACTIVE,
	SETUP_PLACE_BENCH,
	SETUP_SET_PRIZES,
	PLAY_POKEMON,
	EVOLVE,
	ATTACH_ENERGY,
	PLAY_TRAINER,
	PLAY_TOOL,
	PLAY_STADIUM,
	USE_STADIUM,
	USE_ABILITY,
	RETREAT,
	ATTACK,
	COIN_FLIP,
	KNOCKOUT,
	TAKE_PRIZE,
	SEND_OUT,
	STATUS_APPLIED,
	STATUS_REMOVED,
	DAMAGE_DEALT,
	HEAL,
	POKEMON_CHECK,
	DISCARD,
	SHUFFLE_DECK,
	PUBLIC_REVEAL,
}


var action_type: ActionType
var player_index: int = -1
var data: Dictionary = {}
var turn_number: int = 0
var description: String = ""


static func create(
	type: ActionType,
	player: int,
	action_data: Dictionary,
	turn: int,
	desc: String = ""
) -> GameAction:
	var action := GameAction.new()
	action.action_type = type
	action.player_index = player
	action.data = action_data
	action.turn_number = turn
	action.description = desc
	return action


func to_dict() -> Dictionary:
	return {
		"action_type": action_type,
		"player_index": player_index,
		"data": data,
		"turn_number": turn_number,
		"description": description,
	}
