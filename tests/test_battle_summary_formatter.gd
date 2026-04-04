class_name TestBattleSummaryFormatter
extends TestBase

const BattleSummaryFormatterPath := "res://scripts/engine/BattleSummaryFormatter.gd"
const GameActionScript = preload("res://scripts/engine/GameAction.gd")


func _new_formatter() -> Variant:
	var script: GDScript = load(BattleSummaryFormatterPath)
	if script == null:
		return {"ok": false, "error": "BattleSummaryFormatter script is missing"}
	return script.new()


func _format_event(event_data: Dictionary) -> Variant:
	var formatter: Variant = _new_formatter()
	if formatter is Dictionary:
		return formatter
	if not formatter.has_method("format_event"):
		return {"ok": false, "error": "BattleSummaryFormatter is missing format_event()"}
	return {"ok": true, "value": formatter.call("format_event", event_data)}


func _extract_summary_line(result: Variant) -> Variant:
	if not (result is Dictionary):
		return {"ok": false, "error": "Formatter helper returned an unexpected result container"}
	if not bool(result.get("ok", false)):
		return result

	var line: Variant = result.get("value")
	if not _is_string_like(line):
		return {"ok": false, "error": "Expected summary line to be String or StringName, got %s" % type_string(typeof(line))}
	return {"ok": true, "value": String(line)}


func _is_string_like(value: Variant) -> bool:
	return value is String or value is StringName


func _contains_whole_number(text: String, number: int) -> bool:
	var regex := RegEx.new()
	var pattern := "\\b%s\\b" % str(number)
	if regex.compile(pattern) != OK:
		return false
	return regex.search(text) != null


# Builds a representative GameAction-shaped payload for formatter tests.
func _format_game_action(action_type: int, action_data: Dictionary) -> Variant:
	var action = GameActionScript.create(action_type, 0, action_data, 1)
	return _extract_summary_line(_format_event(action.to_dict()))


func test_format_attack_line_includes_attack_name_and_damage() -> String:
	var extracted: Variant = _extract_summary_line(_format_event({
		"event_type": "attack_resolved",
		"attack_name": "Thunderbolt",
		"damage": 120,
	}))
	if not bool(extracted.get("ok", false)):
		return str(extracted.get("error", "Summary line extraction failed"))
	var line_text := String(extracted.get("value"))
	return run_checks([
		assert_str_contains(line_text, "Thunderbolt", "attack summary should include the attack name"),
		assert_true(_contains_whole_number(line_text, 120), "attack summary should include the damage amount as a whole number"),
	])


func test_format_attack_line_supports_current_game_action_payload_shape() -> String:
	var extracted: Variant = _format_game_action(GameActionScript.ActionType.ATTACK, {
		"attack_name": "Thunderbolt",
	})
	if not bool(extracted.get("ok", false)):
		return str(extracted.get("error", "Summary line extraction failed"))
	var line_text := String(extracted.get("value"))
	return run_checks([
		assert_str_contains(line_text, "Thunderbolt", "attack summary should include the attack name from the current GameAction payload shape"),
	])


func test_format_evolve_line_supports_current_gamestatemachine_keys() -> String:
	var extracted: Variant = _format_game_action(GameActionScript.ActionType.EVOLVE, {
		"evolution": "Charmeleon",
		"base": "Charmander",
	})
	if not bool(extracted.get("ok", false)):
		return str(extracted.get("error", "Summary line extraction failed"))
	var line_text := String(extracted.get("value"))
	return run_checks([
		assert_str_contains(line_text, "Charmander", "evolve summary should include the base Pokemon from the current GameStateMachine key shape"),
		assert_str_contains(line_text, "Charmeleon", "evolve summary should include the evolution Pokemon from the current GameStateMachine key shape"),
	])


func test_format_attach_energy_line_supports_current_gamestatemachine_keys() -> String:
	var extracted: Variant = _format_game_action(GameActionScript.ActionType.ATTACH_ENERGY, {
		"energy": "Lightning Energy",
		"target": "Pikachu",
	})
	if not bool(extracted.get("ok", false)):
		return str(extracted.get("error", "Summary line extraction failed"))
	var line_text := String(extracted.get("value"))
	return run_checks([
		assert_str_contains(line_text, "Lightning Energy", "attach summary should include the energy name from the current GameStateMachine key shape"),
		assert_str_contains(line_text, "Pikachu", "attach summary should include the target Pokemon from the current GameStateMachine key shape"),
	])


func test_format_attach_energy_line_supports_current_transfer_style_payload_shape() -> String:
	var extracted: Variant = _format_game_action(GameActionScript.ActionType.ATTACH_ENERGY, {
		"tool": "Heavy Baton",
		"count": 2,
		"target": "Miraidon ex",
	})
	if not bool(extracted.get("ok", false)):
		return str(extracted.get("error", "Summary line extraction failed"))
	var line_text := String(extracted.get("value"))
	return run_checks([
		assert_str_contains(line_text, "Heavy Baton", "transfer summary should include the source tool name from the current transfer-style payload shape"),
		assert_true(_contains_whole_number(line_text, 2), "transfer summary should include the transferred energy count from the current transfer-style payload shape"),
		assert_str_contains(line_text, "Miraidon ex", "transfer summary should include the target Pokemon from the current transfer-style payload shape"),
		assert_str_contains(line_text.to_lower(), "moved", "transfer summary should describe moved energy for the current transfer-style payload shape"),
	])


func test_format_damage_line_supports_current_gamestatemachine_keys() -> String:
	var extracted: Variant = _format_game_action(GameActionScript.ActionType.DAMAGE_DEALT, {
		"target": "Eevee",
		"damage": 30,
	})
	if not bool(extracted.get("ok", false)):
		return str(extracted.get("error", "Summary line extraction failed"))
	var line_text := String(extracted.get("value"))
	return run_checks([
		assert_str_contains(line_text, "Eevee", "damage summary should include the target Pokemon from the current GameStateMachine key shape"),
		assert_true(_contains_whole_number(line_text, 30), "damage summary should include the damage amount from the current GameStateMachine key shape"),
	])


func test_format_knockout_line_includes_knocked_out_pokemon_name() -> String:
	var extracted: Variant = _extract_summary_line(_format_event({
		"event_type": "knockout",
		"knocked_out_pokemon_name": "Bulbasaur",
	}))
	if not bool(extracted.get("ok", false)):
		return str(extracted.get("error", "Summary line extraction failed"))
	var line_text := String(extracted.get("value"))
	return run_checks([
		assert_str_contains(line_text, "Bulbasaur", "knockout summary should include the knocked out Pokemon name"),
	])


func test_format_prize_taking_line_includes_prize_count() -> String:
	var extracted: Variant = _extract_summary_line(_format_event({
		"event_type": "prize_taken",
		"prize_count": 2,
	}))
	if not bool(extracted.get("ok", false)):
		return str(extracted.get("error", "Summary line extraction failed"))
	var line_text := String(extracted.get("value"))
	return run_checks([
		assert_true(_contains_whole_number(line_text, 2), "prize summary should include the prize count as a whole number"),
	])


func test_format_send_out_line_includes_replacement_pokemon_name() -> String:
	var extracted: Variant = _extract_summary_line(_format_event({
		"event_type": "send_out",
		"replacement_pokemon_name": "Pidgeotto",
	}))
	if not bool(extracted.get("ok", false)):
		return str(extracted.get("error", "Summary line extraction failed"))
	var line_text := String(extracted.get("value"))
	return run_checks([
		assert_str_contains(line_text, "Pidgeotto", "send-out summary should include the replacement Pokemon name"),
	])
