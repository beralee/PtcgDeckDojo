class_name AIOpponent
extends RefCounted

var player_index: int = 1
var difficulty: int = 1


func configure(next_player_index: int, next_difficulty: int) -> void:
	player_index = next_player_index
	difficulty = next_difficulty


func should_control_turn(game_state: GameState, ui_blocked: bool) -> bool:
	if game_state == null or ui_blocked:
		return false
	return game_state.current_player_index == player_index


func run_single_step(_battle_scene: Control, _gsm: GameStateMachine) -> bool:
	return false
