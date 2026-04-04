class_name TestBattleAdvicePromptBuilder
extends TestBase

const PromptBuilderPath := "res://scripts/engine/BattleAdvicePromptBuilder.gd"


func _load_builder_script() -> Variant:
	if not ResourceLoader.exists(PromptBuilderPath):
		return null
	return load(PromptBuilderPath)


func _new_builder() -> Variant:
	var script: Variant = _load_builder_script()
	if script == null:
		return {"ok": false, "error": "BattleAdvicePromptBuilder script is missing"}

	var builder = (script as GDScript).new()
	if builder == null:
		return {"ok": false, "error": "BattleAdvicePromptBuilder could not be instantiated"}

	return {"ok": true, "value": builder}


func test_build_request_payload_sets_battle_advice_v1() -> String:
	var builder_result: Variant = _new_builder()
	if builder_result is Dictionary and not bool((builder_result as Dictionary).get("ok", false)):
		return str((builder_result as Dictionary).get("error", "BattleAdvicePromptBuilder setup failed"))

	var builder: Object = (builder_result as Dictionary).get("value") as Object
	if not builder.has_method("build_request_payload"):
		return "BattleAdvicePromptBuilder is missing build_request_payload"

	var payload: Variant = builder.call(
		"build_request_payload",
		{"session_id": "match_1"},
		{"known": ["board"], "unknown": ["opponent_hand"]},
		{"current_position": {}},
		{"delta_since_last_advice": {}}
	)
	if not payload is Dictionary:
		return "build_request_payload should return a Dictionary"

	return run_checks([
		assert_eq(String((payload as Dictionary).get("schema_version", "")), "battle_advice_v1", "Prompt payload should use the fixed schema version"),
		assert_true((payload as Dictionary).has("response_format"), "Prompt payload should expose a strict JSON schema"),
		assert_true((payload as Dictionary).has("visibility_rules"), "Prompt payload should include visibility_rules"),
	])


func test_response_schema_defines_step_object_shape() -> String:
	var builder_result: Variant = _new_builder()
	if builder_result is Dictionary and not bool((builder_result as Dictionary).get("ok", false)):
		return str((builder_result as Dictionary).get("error", "BattleAdvicePromptBuilder setup failed"))

	var builder: Object = (builder_result as Dictionary).get("value") as Object
	if not builder.has_method("response_schema"):
		return "BattleAdvicePromptBuilder is missing response_schema"

	var schema: Variant = builder.call("response_schema")
	if not schema is Dictionary:
		return "response_schema should return a Dictionary"

	var current_turn_items := (((schema as Dictionary).get("properties", {}) as Dictionary).get("current_turn_main_line", {}) as Dictionary).get("items", {}) as Dictionary
	return run_checks([
		assert_true(current_turn_items.has("properties"), "Current-turn main line items should be object-shaped"),
	])


func test_response_schema_requires_layered_advice_sections() -> String:
	var builder_result: Variant = _new_builder()
	if builder_result is Dictionary and not bool((builder_result as Dictionary).get("ok", false)):
		return str((builder_result as Dictionary).get("error", "BattleAdvicePromptBuilder setup failed"))

	var builder: Object = (builder_result as Dictionary).get("value") as Object
	if not builder.has_method("response_schema"):
		return "BattleAdvicePromptBuilder is missing response_schema"

	var schema: Variant = builder.call("response_schema")
	if not schema is Dictionary:
		return "response_schema should return a Dictionary"

	var required := (schema as Dictionary).get("required", []) as Array
	var properties := (schema as Dictionary).get("properties", {}) as Dictionary
	return run_checks([
		assert_false(bool((schema as Dictionary).get("additionalProperties", true)), "Advice schema should forbid additional top-level properties"),
		assert_true(required.has("strategic_thesis"), "Advice schema should require strategic_thesis"),
		assert_true(required.has("current_turn_main_line"), "Advice schema should require current_turn_main_line"),
		assert_true(required.has("conditional_branches"), "Advice schema should require conditional_branches"),
		assert_true(required.has("prize_plan"), "Advice schema should require prize_plan"),
		assert_true(required.has("why_this_line"), "Advice schema should require why_this_line"),
		assert_true(required.has("risk_watchouts"), "Advice schema should require risk_watchouts"),
		assert_true(required.has("confidence"), "Advice schema should require confidence"),
		assert_true(required.has("summary_for_next_request"), "Advice schema should require summary_for_next_request"),
		assert_true((((properties.get("risk_watchouts", {}) as Dictionary).get("items", {}) as Dictionary).has("properties")), "Risk watchouts should use explicit object items"),
	])


func test_instructions_prioritize_setup_and_concise_prize_driven_lines() -> String:
	var builder_result: Variant = _new_builder()
	if builder_result is Dictionary and not bool((builder_result as Dictionary).get("ok", false)):
		return str((builder_result as Dictionary).get("error", "BattleAdvicePromptBuilder setup failed"))

	var builder: Object = (builder_result as Dictionary).get("value") as Object
	if not builder.has_method("instructions"):
		return "BattleAdvicePromptBuilder is missing instructions"

	var instructions_variant: Variant = builder.call("instructions")
	if not instructions_variant is PackedStringArray:
		return "instructions should return a PackedStringArray"

	var instructions_text := "\n".join((instructions_variant as PackedStringArray))
	return run_checks([
		assert_true("setup" in instructions_text.to_lower(), "Instructions should explicitly prioritize setup and engine development"),
		assert_true("prize" in instructions_text.to_lower(), "Instructions should explicitly mention prize planning or prize trade"),
		assert_true("concise" in instructions_text.to_lower(), "Instructions should explicitly constrain verbosity"),
		assert_true("chip damage" in instructions_text.to_lower(), "Instructions should tell the model not to default to low-value chip damage lines"),
	])
