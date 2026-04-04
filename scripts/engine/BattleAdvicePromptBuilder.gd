class_name BattleAdvicePromptBuilder
extends RefCounted

const BATTLE_ADVICE_SCHEMA_VERSION := "battle_advice_v1"


func build_request_payload(session_block: Dictionary, visibility_rules: Dictionary, current_position: Dictionary, delta_block: Dictionary) -> Dictionary:
	return {
		"schema_version": BATTLE_ADVICE_SCHEMA_VERSION,
		"system_prompt_version": BATTLE_ADVICE_SCHEMA_VERSION,
		"response_format": response_schema(),
		"instructions": instructions(),
		"session": session_block.duplicate(true),
		"visibility_rules": visibility_rules.duplicate(true),
		"current_position": current_position.duplicate(true),
		"delta_since_last_advice": delta_block.duplicate(true),
	}


func instructions() -> PackedStringArray:
	return PackedStringArray([
		"You are advising the current-turn player in a live PTCG match.",
		"Use only the provided visible board information, public state, action history, and both full decklists.",
		"Do not infer or claim knowledge of the opponent's hidden hand, prize identities, or deck order.",
		"Return JSON only with the agreed schema.",
		"Keep current-turn actions separate from conditional branches and longer-horizon prize planning.",
		"Lead with the strongest current-turn line, and prioritize setup, evolution engines, energy setup, prize trade, and resource preservation over low-value chip damage.",
		"If a support card or search sequence obviously advances the deck's engine, name the concrete cards and targets instead of giving generic advice.",
		"Treat this like high-level tournament coaching: explain the line in tempo, resource, and prize-map terms, but stay concise and specific.",
		"Do not recommend attacking for trivial damage unless that damage materially changes the prize map, a knockout setup, or the opponent's sequencing.",
		"Keep the answer compact: main line should usually be 3 to 5 meaningful steps, branches should stay limited, and each explanation should be short.",
	])


func response_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": false,
		"required": [
			"strategic_thesis",
			"current_turn_main_line",
			"conditional_branches",
			"prize_plan",
			"why_this_line",
			"risk_watchouts",
			"confidence",
			"summary_for_next_request",
		],
		"properties": {
			"strategic_thesis": {"type": "string"},
			"current_turn_main_line": {
				"type": "array",
				"maxItems": 5,
				"items": _step_schema(),
			},
			"conditional_branches": {
				"type": "array",
				"maxItems": 3,
				"items": _branch_schema(),
			},
			"prize_plan": {
				"type": "array",
				"maxItems": 3,
				"items": _prize_plan_schema(),
			},
			"why_this_line": _bounded_string_array_schema(4),
			"risk_watchouts": {
				"type": "array",
				"maxItems": 3,
				"items": _risk_schema(),
			},
			"confidence": {
				"type": "string",
				"enum": ["low", "medium", "high"],
			},
			"summary_for_next_request": {"type": "string"},
		},
	}


func _step_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": false,
		"required": ["step", "action", "why"],
		"properties": {
			"step": {"type": "integer"},
			"action": {"type": "string", "maxLength": 120},
			"why": {"type": "string", "maxLength": 180},
		},
	}


func _branch_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": false,
		"required": ["if", "then"],
		"properties": {
			"if": {"type": "string", "maxLength": 120},
			"then": _bounded_string_array_schema(2),
		},
	}


func _prize_plan_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": false,
		"required": ["horizon", "goal"],
		"properties": {
			"horizon": {
				"type": "string",
				"enum": ["this_turn", "next_turn", "next_two_turns"],
			},
			"goal": {"type": "string", "maxLength": 140},
		},
	}


func _risk_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": false,
		"required": ["risk", "mitigation"],
		"properties": {
			"risk": {"type": "string", "maxLength": 140},
			"mitigation": {"type": "string", "maxLength": 160},
		},
	}


func _string_array_schema() -> Dictionary:
	return {
		"type": "array",
		"items": {"type": "string"},
	}


func _bounded_string_array_schema(max_items: int) -> Dictionary:
	var schema := _string_array_schema()
	schema["maxItems"] = max_items
	schema["items"] = {"type": "string", "maxLength": 160}
	return schema
