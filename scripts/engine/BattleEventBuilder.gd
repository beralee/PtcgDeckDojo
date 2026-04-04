class_name BattleEventBuilder
extends RefCounted

const GameActionScript = preload("res://scripts/engine/GameAction.gd")


func make_match_id() -> String:
	var timestamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var microseconds := Time.get_ticks_usec() % 1000000
	return "match_%s_%06d" % [timestamp, microseconds]


func build_event(event_data: Dictionary, match_id: String, event_index: int) -> Dictionary:
	var event := event_data.duplicate(true)
	event["match_id"] = match_id
	event["event_index"] = event_index
	event["timestamp"] = _string_field(event_data, ["timestamp"], Time.get_datetime_string_from_system())
	event["turn_number"] = _int_field(event_data, ["turn_number", "turn"], 0)
	event["phase"] = _string_field(event_data, ["phase"], "")
	event["player_index"] = _int_field(event_data, ["player_index", "player"], -1)
	event["event_type"] = _event_type(event_data)
	return event


func _event_type(event_data: Dictionary) -> String:
	var value: Variant = event_data.get("event_type", event_data.get("kind", event_data.get("action_type", "")))
	if value is int:
		var action_type_name := _action_type_name(int(value))
		if action_type_name != "":
			return action_type_name
		return "action_type_%d" % int(value)
	return String(value).strip_edges().to_lower()


func _action_type_name(action_type: int) -> String:
	match action_type:
		GameActionScript.ActionType.GAME_START:
			return "game_start"
		GameActionScript.ActionType.GAME_END:
			return "game_end"
		GameActionScript.ActionType.TURN_START:
			return "turn_start"
		GameActionScript.ActionType.TURN_END:
			return "turn_end"
		GameActionScript.ActionType.DRAW_CARD:
			return "draw_card"
		GameActionScript.ActionType.MULLIGAN:
			return "mulligan"
		GameActionScript.ActionType.SETUP_PLACE_ACTIVE:
			return "setup_place_active"
		GameActionScript.ActionType.SETUP_PLACE_BENCH:
			return "setup_place_bench"
		GameActionScript.ActionType.SETUP_SET_PRIZES:
			return "setup_set_prizes"
		GameActionScript.ActionType.PLAY_POKEMON:
			return "play_pokemon"
		GameActionScript.ActionType.EVOLVE:
			return "evolve"
		GameActionScript.ActionType.ATTACH_ENERGY:
			return "attach_energy"
		GameActionScript.ActionType.PLAY_TRAINER:
			return "play_trainer"
		GameActionScript.ActionType.PLAY_TOOL:
			return "play_tool"
		GameActionScript.ActionType.PLAY_STADIUM:
			return "play_stadium"
		GameActionScript.ActionType.USE_STADIUM:
			return "use_stadium"
		GameActionScript.ActionType.USE_ABILITY:
			return "use_ability"
		GameActionScript.ActionType.RETREAT:
			return "retreat"
		GameActionScript.ActionType.ATTACK:
			return "attack"
		GameActionScript.ActionType.COIN_FLIP:
			return "coin_flip"
		GameActionScript.ActionType.KNOCKOUT:
			return "knockout"
		GameActionScript.ActionType.TAKE_PRIZE:
			return "take_prize"
		GameActionScript.ActionType.SEND_OUT:
			return "send_out"
		GameActionScript.ActionType.STATUS_APPLIED:
			return "status_applied"
		GameActionScript.ActionType.STATUS_REMOVED:
			return "status_removed"
		GameActionScript.ActionType.DAMAGE_DEALT:
			return "damage_dealt"
		GameActionScript.ActionType.HEAL:
			return "heal"
		GameActionScript.ActionType.POKEMON_CHECK:
			return "pokemon_check"
		GameActionScript.ActionType.DISCARD:
			return "discard"
		GameActionScript.ActionType.SHUFFLE_DECK:
			return "shuffle_deck"
		_:
			return ""


func _string_field(event_data: Dictionary, keys: Array[String], fallback: String) -> String:
	for key: String in keys:
		if not event_data.has(key):
			continue
		var text := String(event_data.get(key, "")).strip_edges()
		if text != "":
			return text
	return fallback


func _int_field(event_data: Dictionary, keys: Array[String], fallback: int) -> int:
	for key: String in keys:
		if not event_data.has(key):
			continue
		var value: Variant = event_data.get(key)
		if value is int:
			return int(value)
		var text := String(value).strip_edges()
		if text.is_valid_int():
			return text.to_int()
	return fallback
