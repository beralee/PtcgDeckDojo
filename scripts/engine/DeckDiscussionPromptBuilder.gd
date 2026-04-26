class_name DeckDiscussionPromptBuilder
extends RefCounted

const SCHEMA_VERSION := "deck_discussion_v2"
const MAX_HISTORY_TURNS := 8
const MAX_HISTORY_TURNS_WITH_EXTERNAL_CONTEXT := 4


func build_request_payload(model: String, context: Dictionary, conversation: Array[Dictionary], user_question: String) -> Dictionary:
	return {
		"model": model,
		"messages": _build_messages(context, conversation, user_question, false),
		"temperature": 0.2,
		"response_format": {
			"type": "json_schema",
			"json_schema": {
				"name": SCHEMA_VERSION,
				"strict": true,
				"schema": response_schema(),
			},
		},
	}


func build_tool_followup_payload(
	model: String,
	initial_context: Dictionary,
	tool_result: Dictionary,
	conversation: Array[Dictionary],
	user_question: String
) -> Dictionary:
	var messages := _build_messages(initial_context, conversation, user_question, true)
	messages.append({
		"role": "assistant",
		"content": JSON.stringify({
			"title": "需要外部信息",
			"answer_markdown": "我需要读取额外卡组或单卡信息后再回答。",
			"confidence": "low",
			"suggested_questions": [],
			"math_steps": [],
			"referenced_cards": [],
			"tool_request": tool_result.get("request", null),
		}),
	})
	messages.append({
		"role": "user",
		"content": "工具返回如下额外上下文(JSON)。请结合当前卡组上下文回答用户原问题，不要再次请求工具；如果工具未找到结果，直接说明缺失信息。\n%s" % JSON.stringify(tool_result, "\t"),
	})
	return {
		"model": model,
		"messages": messages,
		"temperature": 0.2,
		"response_format": {
			"type": "json_schema",
			"json_schema": {
				"name": SCHEMA_VERSION,
				"strict": true,
				"schema": response_schema(),
			},
		},
	}


func response_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": false,
		"required": [
			"title",
			"answer_markdown",
			"confidence",
			"suggested_questions",
			"math_steps",
			"referenced_cards",
			"tool_request",
		],
		"properties": {
			"title": {"type": "string", "maxLength": 32},
			"answer_markdown": {"type": "string", "maxLength": 1200},
			"confidence": {"type": "string", "enum": ["low", "medium", "high"]},
			"suggested_questions": {
				"type": "array",
				"maxItems": 3,
				"items": {"type": "string", "maxLength": 48},
			},
			"math_steps": {
				"type": "array",
				"maxItems": 3,
				"items": {"type": "string", "maxLength": 120},
			},
			"referenced_cards": {
				"type": "array",
				"maxItems": 8,
				"items": {"type": "string", "maxLength": 60},
			},
			"tool_request": {
				"anyOf": [
					{"type": "null"},
					{
						"type": "object",
						"additionalProperties": false,
						"required": ["name", "reason", "query"],
						"properties": {
							"name": {"type": "string", "enum": ["get_other_deck_detail", "get_card_detail"]},
							"reason": {"type": "string", "maxLength": 180},
							"query": {"type": "string", "maxLength": 80},
						},
					},
				],
			},
		},
	}


func _build_messages(context: Dictionary, conversation: Array[Dictionary], user_question: String, detail_followup: bool) -> Array[Dictionary]:
	var messages: Array[Dictionary] = [{
		"role": "system",
		"content": _system_prompt(),
	}]
	var ai_personality := str(context.get("ai_personality", "")).strip_edges()
	if ai_personality != "":
		messages.append({
			"role": "system",
			"content": "AI personality/style preference from the player: \"%s\". This personality describes you, the AI assistant, not the player and not any deck or Pokemon. Apply it only to your tone, phrasing, and degree of warmth/humor/caution; never let it override game rules, hidden-information limits, factual accuracy, concise answers, or the required JSON schema." % ai_personality.left(160),
		})
	var level := str(context.get("context_level", "detailed"))
	var context_label := "完整去重卡组上下文" if level == "detailed" else "卡组上下文"
	messages.append({
		"role": "user",
		"content": "%s(JSON)。每张牌只出现一次，count 是投入张数；必须以它为准，不得编造卡表。当前卡组信息已经完整；只有当用户明确问另一套卡组，或问当前卡组里没有的单卡时，才允许请求工具。\n可用工具：get_other_deck_detail(query=卡组名或deck_id)，get_card_detail(query=单卡名)。其它情况 tool_request 必须为 null。\n%s" % [context_label, JSON.stringify(context, "\t")],
	})
	if context.has("external_tool_results"):
		messages.append({
			"role": "user",
			"content": "服务层已经为本问题自动加载了 external_tool_results。请优先使用这些额外卡组/单卡信息直接回答原问题，不要再请求同一个工具。",
		})
	var history_limit := MAX_HISTORY_TURNS_WITH_EXTERNAL_CONTEXT if context.has("external_tool_results") else MAX_HISTORY_TURNS
	for turn: Dictionary in _trim_conversation(conversation, history_limit):
		var role := str(turn.get("role", "")).strip_edges()
		var content := str(turn.get("content", "")).strip_edges()
		if role == "" or content == "":
			continue
		messages.append({
			"role": role,
			"content": content,
		})
	if not detail_followup:
		if context.has("external_tool_results"):
			messages.append({
				"role": "user",
				"content": "最终问题需要使用下面的外部上下文回答；如果用户问的是外部卡组，必须优先引用 external_tool_results.deck_context.cards、strategy_summary、energy_breakdown，不要只凭历史记忆。\nexternal_tool_results(JSON):\n%s" % JSON.stringify(context.get("external_tool_results", []), "\t"),
			})
		messages.append({
			"role": "user",
			"content": user_question.strip_edges(),
		})
	return messages


func _trim_conversation(conversation: Array[Dictionary], limit: int = MAX_HISTORY_TURNS) -> Array[Dictionary]:
	if conversation.size() <= limit:
		return conversation
	var result: Array[Dictionary] = []
	var start := conversation.size() - limit
	for i: int in range(start, conversation.size()):
		result.append(conversation[i])
	return result


func _system_prompt() -> String:
	return "\n".join([
		"Battle prize rule: prize_count/prize_remaining means remaining Prize cards, not Prize cards already taken. A player wins when their remaining Prize cards reaches 0.",
		"Battle prize interpretation: if remaining prizes are me=3 opponent=4, I am ahead because I have taken 3 prizes and opponent has taken 2. If remaining prizes are me=4 opponent=3, I am behind.",
		"When explaining battle scores, state both views clearly: remaining prizes and prizes taken. Do not call remaining prizes a score unless you say lower is better.",
		"When battle_context.knockout_projection is present, use it to reason about the prize race after a possible knockout this turn.",
		"你是 PTCG 构筑与对局讨论助手，用中文回答。",
		"必须先直接回答用户最后一句原问题，不要跳到泛泛卡组分析。",
		"回答要短：默认 2 到 5 句话；除非用户要求详细推导，否则不要展开长篇方法论。",
		"如果用户问某张牌的必要性、作用、卡位、要不要带、几张合适或能否替换，只回答这张牌在当前卡组里的结论、原因和建议。",
		"如果用户问同名卡版本差异、技能/特性/招式区别或为什么带多版本，优先逐张对比这些卡的 set_code/card_index、HP、招式、特性和效果文本。",
		"当前上下文已经包含当前卡组的完整去重信息；当前卡组内的问题不要请求工具，tool_request 必须为 null。",
		"如果上下文里已经有 external_tool_results，说明服务层已经自动加载了相关外部卡组或单卡；必须使用它回答，不要再次请求相同工具。",
		"如果 external_tool_results 里有 get_live_battle_context/battle_context，说明用户在对战页面提问；必须站在 battle_context.perspective_player_index 的可见视角回答当前场面，不得编造或引用 hidden_information_policy 禁止的信息。",
		"只有两种情况允许请求工具：1. 用户问另一套卡组的策略、对局或卡表时，返回 tool_request.name=get_other_deck_detail 并把 query 写成卡组名或 deck_id；2. 用户问当前卡组没有的单卡时，返回 tool_request.name=get_card_detail 并把 query 写成卡名。",
		"工具返回额外上下文后，必须结合当前卡组直接回答原问题，不要再次请求工具。",
		"回答正文、推导步骤、追问建议都必须使用中文；卡名优先使用上下文里的中文 name，不要主动使用英文 name_en。",
		"概率、起手质量、关键牌上手率优先使用超几何分布、补事件、容斥等精确方法。",
		"默认起手为 60 张牌组抽 7 张；如果涉及先后手后续摸牌，必须写清采用的抽牌张数假设。",
		"回答要先给结论，再给一两条理由。涉及牌名时使用上下文里的牌名。",
		"上下文不足时直接说明缺失信息，不得编造隐藏卡表。",
		"输出必须符合给定 JSON schema。",
	])
