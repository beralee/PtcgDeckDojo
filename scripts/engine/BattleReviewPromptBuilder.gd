class_name BattleReviewPromptBuilder
extends RefCounted

const STAGE1_PROMPT_VERSION := "battle_review_stage1_v3"
const STAGE2_PROMPT_VERSION := "battle_review_stage2_v3"


func build_stage1_payload(compact_match: Dictionary) -> Dictionary:
	return {
		"system_prompt_version": STAGE1_PROMPT_VERSION,
		"response_format": _stage1_schema(),
		"instructions": _stage1_instructions(),
		"match": compact_match,
	}


func build_stage2_payload(turn_packet: Dictionary) -> Dictionary:
	return {
		"system_prompt_version": STAGE2_PROMPT_VERSION,
		"response_format": _stage2_schema(),
		"instructions": _stage2_instructions(),
		"turn_packet": turn_packet,
	}


func _stage1_instructions() -> PackedStringArray:
	return PackedStringArray([
		"Use only the provided match data.",
		"Use full hidden information from both players for post-game analysis.",
		"Summarize the matchup in one short sentence before selecting turns.",
		"Select exactly one key turn for each side.",
		"Keep reasons concise and concrete.",
		"Avoid generic strategic filler.",
		"Return JSON only with the agreed keys.",
		"Explain briefly why each chosen turn is worth deeper review.",
	])


func _stage2_instructions() -> PackedStringArray:
	return PackedStringArray([
		"You are reviewing a completed PTCG match as a world-class post-game coach.",
		"Use only the provided turn packet.",
		"Use full hidden information from both players to identify the truly strongest practical line.",
		"Reason from board state, hand, discard, deck plan, prize map, action order, and opponent counterplay.",
		"Before recommending a better line, verify the opponent's earliest realistic punish turn and reject lines that only work under fake timing assumptions.",
		"If the played line is already close to optimal, say so instead of forcing a counterfactual.",
		"Keep the whole response concise: one short summary, at most two mistakes, at most four steps, and one takeaway.",
		"Avoid generic strategic filler.",
		"Account for hand, discard, board, action order, available choices, and deck plan.",
		"Return JSON only with the agreed keys.",
	])


func _stage1_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": false,
		"required": [
			"winner_index",
			"loser_index",
			"matchup_summary",
			"winner_turns",
			"loser_turns",
		],
		"properties": {
			"winner_index": {"type": "integer"},
			"loser_index": {"type": "integer"},
			"matchup_summary": {"type": "string", "maxLength": 180},
			"winner_turns": {
				"type": "array",
				"minItems": 1,
				"maxItems": 1,
				"items": _selected_turn_schema(),
			},
			"loser_turns": {
				"type": "array",
				"minItems": 1,
				"maxItems": 1,
				"items": _selected_turn_schema(),
			},
		},
	}


func _stage2_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": false,
		"required": [
			"turn_number",
			"player_index",
			"judgment",
			"turn_goal",
			"timing_window",
			"why_current_line_falls_short",
			"best_line",
			"coach_takeaway",
			"confidence",
		],
		"properties": {
			"turn_number": {"type": "integer"},
			"player_index": {"type": "integer"},
			"judgment": {"type": "string", "enum": ["optimal", "close_to_optimal", "suboptimal", "missed_line"]},
			"turn_goal": {"type": "string", "maxLength": 140},
			"timing_window": {
				"type": "object",
				"additionalProperties": false,
				"required": ["earliest_opponent_pressure_turn", "assessment"],
				"properties": {
					"earliest_opponent_pressure_turn": {"type": "integer"},
					"assessment": {"type": "string", "maxLength": 180},
				},
			},
			"why_current_line_falls_short": {
				"type": "array",
				"maxItems": 2,
				"items": {"type": "string", "maxLength": 180},
			},
			"best_line": {
				"type": "object",
				"additionalProperties": false,
				"required": ["summary", "steps"],
				"properties": {
					"summary": {"type": "string", "maxLength": 180},
					"steps": {
						"type": "array",
						"maxItems": 4,
						"items": {"type": "string", "maxLength": 180},
					},
				},
			},
			"coach_takeaway": {"type": "string", "maxLength": 180},
			"confidence": {"type": "string"},
		},
	}


func _selected_turn_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": false,
		"required": ["turn_number", "reason"],
		"properties": {
			"turn_number": {"type": "integer"},
			"reason": {"type": "string", "maxLength": 180},
		},
	}


func _string_array_schema() -> Dictionary:
	return {
		"type": "array",
		"items": {"type": "string"},
	}
