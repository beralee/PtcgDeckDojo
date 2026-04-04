class_name BattleSummaryFormatter
extends RefCounted

const GameActionScript = preload("res://scripts/engine/GameAction.gd")


func format_event(event_data: Dictionary) -> String:
	var kind: String = _event_kind(event_data)
	match kind:
		"attack", "attack_resolved":
			return _format_attack(event_data)
		"damage_dealt":
			return _format_damage(event_data)
		"knockout":
			return _format_knockout(event_data)
		"take_prize", "prize_taken":
			return _format_prize_taken(event_data)
		"send_out":
			return _format_send_out(event_data)
		"evolve":
			return _format_evolve(event_data)
		"attach_energy":
			return _format_attach_energy(event_data)
		"play_trainer":
			return _format_play_trainer(event_data)
		_:
			return _format_fallback(event_data, kind)


func _event_kind(event_data: Dictionary) -> String:
	var kind: Variant = event_data.get("event_type", event_data.get("kind", event_data.get("action_type", "")))
	if kind is int:
		return _action_type_name(int(kind))
	return String(kind).strip_edges().to_lower()


func _format_attack(event_data: Dictionary) -> String:
	var attack_name: String = _first_text(event_data, ["attack_name", "attack", "name"], "attack")
	var damage: String = _first_number_text(event_data, ["damage", "damage_amount", "damage_dealt", "amount"])
	if damage != "":
		return "%s dealt %s damage." % [attack_name, damage]
	return "%s was used." % attack_name


func _format_damage(event_data: Dictionary) -> String:
	var damage: String = _first_number_text(event_data, ["damage", "damage_amount", "damage_dealt", "amount"])
	var target_name: String = _first_text(event_data, ["target_pokemon_name", "pokemon_name", "target_name", "target", "name"], "the target Pokemon")
	if damage != "":
		return "%s damage was dealt to %s." % [damage, target_name]
	return "Damage was dealt to %s." % target_name


func _format_knockout(event_data: Dictionary) -> String:
	var pokemon_name: String = _first_text(event_data, ["knocked_out_pokemon_name", "pokemon_name", "target_name", "name"], "the Pokemon")
	return "%s was knocked out." % pokemon_name


func _format_prize_taken(event_data: Dictionary) -> String:
	var prize_count: String = _first_number_text(event_data, ["prize_count", "count", "prizes"], "1")
	return "Took %s Prize card%s." % [prize_count, "" if prize_count == "1" else "s"]


func _format_send_out(event_data: Dictionary) -> String:
	var pokemon_name: String = _first_text(event_data, ["replacement_pokemon_name", "pokemon_name", "target_name", "name"], "a replacement Pokemon")
	return "Sent out %s." % pokemon_name


func _format_evolve(event_data: Dictionary) -> String:
	var from_name: String = _first_text(event_data, ["from_pokemon_name", "base_pokemon_name", "base", "pokemon_name", "name"], "")
	var to_name: String = _first_text(event_data, ["evolved_pokemon_name", "evolution_name", "evolution", "card_name"], "")
	if from_name != "" and to_name != "":
		return "%s evolved into %s." % [from_name, to_name]
	if to_name != "":
		return "Evolved into %s." % to_name
	if from_name != "":
		return "%s evolved." % from_name
	return "Pokemon evolved."


func _format_attach_energy(event_data: Dictionary) -> String:
	var transfer_tool: String = _first_text(event_data, ["tool"], "")
	var transfer_count: String = _first_number_text(event_data, ["count"], "")
	if transfer_tool != "" or transfer_count != "":
		var moved_count: String = transfer_count if transfer_count != "" else "1"
		var moved_target: String = _first_text(event_data, ["target_pokemon_name", "pokemon_name", "target_name", "target"], "the Pokemon")
		if transfer_tool != "":
			return "Moved %s Energy with %s to %s." % [moved_count, transfer_tool, moved_target]
		return "Moved %s Energy to %s." % [moved_count, moved_target]
	var energy_name: String = _first_text(event_data, ["energy_name", "card_name", "energy_type", "energy", "name"], "Energy")
	var target_name: String = _first_text(event_data, ["target_pokemon_name", "pokemon_name", "target_name", "target"], "the Pokemon")
	return "Attached %s to %s." % [energy_name, target_name]


func _format_play_trainer(event_data: Dictionary) -> String:
	var trainer_name: String = _first_text(event_data, ["trainer_name", "card_name", "name"], "Trainer")
	return "Played %s." % trainer_name


func _format_fallback(event_data: Dictionary, kind: String) -> String:
	if kind != "":
		var subject: String = _first_text(event_data, ["name", "card_name", "pokemon_name"], "")
		if subject != "":
			return "%s: %s" % [kind.capitalize(), subject]
		return kind.capitalize()
	return str(event_data)


func _first_text(event_data: Dictionary, keys: Array[String], fallback: String) -> String:
	for key: String in keys:
		var value: Variant = _lookup_value(event_data, key)
		if value == null:
			continue
		var text: String = String(value).strip_edges()
		if text != "":
			return text
	return fallback


func _first_number_text(event_data: Dictionary, keys: Array[String], fallback: String = "") -> String:
	for key: String in keys:
		var value: Variant = _lookup_value(event_data, key)
		if value == null:
			continue
		if value is int or value is float:
			return str(value)
		var text: String = String(value).strip_edges()
		if text != "":
			return text
	return fallback


func _lookup_value(event_data: Dictionary, key: String) -> Variant:
	if event_data.has(key):
		return event_data.get(key)
	var nested_data: Variant = event_data.get("data", null)
	if nested_data is Dictionary and nested_data.has(key):
		return nested_data.get(key)
	return null


func _action_type_name(action_type: int) -> String:
	match action_type:
		GameActionScript.ActionType.ATTACK:
			return "attack"
		GameActionScript.ActionType.DAMAGE_DEALT:
			return "damage_dealt"
		GameActionScript.ActionType.KNOCKOUT:
			return "knockout"
		GameActionScript.ActionType.TAKE_PRIZE:
			return "take_prize"
		GameActionScript.ActionType.SEND_OUT:
			return "send_out"
		GameActionScript.ActionType.EVOLVE:
			return "evolve"
		GameActionScript.ActionType.ATTACH_ENERGY:
			return "attach_energy"
		GameActionScript.ActionType.PLAY_TRAINER:
			return "play_trainer"
		_:
			return ""
