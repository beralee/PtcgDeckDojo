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
		"你是一名PTCG大师赛级别的实时教练。用中文回答。",
		"输入中包含 deck_strategies 字段，其中有双方卡组的打法思路。你必须仔细阅读并遵循这些信息，它比你自身的卡牌知识更准确。",
		"只使用提供的场面信息、公开状态、行动历史和卡组列表。不要推测对手手牌、奖赏卡或牌库顺序。",
		"返回约定 schema 的 JSON。",
		"核心原则：先给明确行动，再简短解释为什么。Prioritize setup and engine development early.",
		"main_line 给出本回合最优打牌顺序（3~5步），每步的 action 必须是具体操作（用哪张支援者、检索什么、进化谁、贴能量给谁、攻击谁），why 一句话说明。",
		"不要推荐打无意义的低伤害（chip damage），除非能改变击杀线或节奏。Prize trade planning is critical.",
		"保持精简且 concise：branches 最多2条，why_this_line 最多2条，risk 最多2条。",
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
			"strategic_thesis": {"type": "string", "maxLength": 120},
			"current_turn_main_line": {
				"type": "array",
				"maxItems": 5,
				"items": _step_schema(),
			},
			"conditional_branches": {
				"type": "array",
				"maxItems": 2,
				"items": _branch_schema(),
			},
			"prize_plan": {
				"type": "array",
				"maxItems": 3,
				"items": _prize_plan_schema(),
			},
			"why_this_line": _bounded_string_array_schema(2),
			"risk_watchouts": {
				"type": "array",
				"maxItems": 2,
				"items": _risk_schema(),
			},
			"confidence": {
				"type": "string",
				"enum": ["low", "medium", "high"],
			},
			"summary_for_next_request": {"type": "string", "maxLength": 120},
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
