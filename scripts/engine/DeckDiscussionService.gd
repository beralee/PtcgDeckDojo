class_name DeckDiscussionService
extends RefCounted

signal status_changed(status: String, context: Dictionary)
signal message_completed(result: Dictionary)

const ZENMUX_CLIENT_PATH := "res://scripts/network/ZenMuxClient.gd"
const ContextBuilderScript = preload("res://scripts/engine/DeckDiscussionContextBuilder.gd")
const PromptBuilderScript = preload("res://scripts/engine/DeckDiscussionPromptBuilder.gd")
const SessionStoreScript = preload("res://scripts/engine/DeckDiscussionSessionStore.gd")

const EXTERNAL_TOOL_NAMES := {
	"get_other_deck_detail": true,
	"get_card_detail": true,
}

const DECK_QUERY_ALIASES := {
	"喷火龙": 575716,
	"喷火龙大比鸟": 575716,
	"喷火龙 大比鸟": 575716,
	"charizard": 575716,
	"密勒顿": 575720,
	"miraidon": 575720,
	"阿尔宙斯": 569061,
	"阿尔宙斯骑拉帝纳": 569061,
	"阿尔宙斯 骑拉帝纳": 569061,
	"arceus": 569061,
	"沙奈朵": 578647,
	"gardevoir": 578647,
	"多龙巴鲁托": 575657,
	"多龙巴鲁托黑夜魔灵": 575657,
	"多龙巴鲁托 黑夜魔灵": 575657,
	"dragapult": 575657,
	"猛雷鼓": 575718,
	"raging bolt": 575718,
}

const CARD_QUERY_ALIASES := {
	"月月熊": "Bloodmoon Ursaluna ex",
	"赫月": "Bloodmoon Ursaluna ex",
	"赫月月月熊": "Bloodmoon Ursaluna ex",
	"铁臂膀": "Iron Hands ex",
	"鐵臂膀": "Iron Hands ex",
	"达克莱伊": "Darkrai VSTAR",
	"达克莱伊vstar": "Darkrai VSTAR",
	"darkrai": "Darkrai VSTAR",
	"ursaluna": "Bloodmoon Ursaluna ex",
	"bloodmoon": "Bloodmoon Ursaluna ex",
}

var _client = null
var _context_builder = ContextBuilderScript.new()
var _prompt_builder = PromptBuilderScript.new()
var _store = SessionStoreScript.new()
var _busy := false


func configure_dependencies(client: Variant, context_builder: Variant, prompt_builder: Variant, store: Variant) -> void:
	if client != null:
		_client = client
	if context_builder != null:
		_context_builder = context_builder
	if prompt_builder != null:
		_prompt_builder = prompt_builder
	if store != null:
		_store = store


func is_busy() -> bool:
	return _busy


func load_history(deck_id: int) -> Array[Dictionary]:
	return _store.load_messages(deck_id)


func clear_history(deck_id: int) -> void:
	_store.clear_session(deck_id)


func build_context(deck: DeckData) -> Dictionary:
	return _context_builder.build_detailed_context(deck)


func build_quick_summary(deck: DeckData) -> String:
	return _context_builder.build_quick_summary(build_context(deck))


func ask(parent: Node, deck: DeckData, user_question: String, api_config: Dictionary, forced_external_tool_results: Array[Dictionary] = []) -> Dictionary:
	if _busy:
		return {"status": "ignored", "message": "busy"}
	if deck == null:
		return {"status": "error", "message": "missing_deck"}
	var endpoint: String = str(api_config.get("endpoint", "")).strip_edges()
	var api_key: String = str(api_config.get("api_key", "")).strip_edges()
	if endpoint == "" or api_key == "":
		return {"status": "error", "message": "missing_api_config"}

	_busy = true
	var client = _get_client()
	if client == null:
		_busy = false
		var missing_client: Dictionary = {
			"status": "error",
			"message": "ai_client_load_failed",
		}
		_set_status("failed", missing_client)
		message_completed.emit(missing_client)
		return missing_client

	client.set_timeout_seconds(maxf(float(api_config.get("timeout_seconds", 60.0)), 90.0))
	var context: Dictionary = _context_for_question(deck, user_question, forced_external_tool_results)
	context["ai_personality"] = str(api_config.get("ai_personality", "")).strip_edges()
	_write_debug_log({
		"event": "request_start",
		"deck_id": deck.id,
		"question": user_question,
		"context_level": str(context.get("context_level", "")),
		"auto_external_tool_results": _summarize_tool_results(context.get("external_tool_results", [])),
	})
	var history: Array[Dictionary] = _store.load_messages(deck.id)
	var payload: Dictionary = _prompt_builder.build_request_payload(str(api_config.get("model", "")), context, history, user_question)
	_set_status("running", {"deck_id": deck.id, "context_level": str(context.get("context_level", ""))})
	var request_error: int = client.request_json(
		parent,
		endpoint,
		api_key,
		payload,
		_on_response.bind(parent, deck, user_question, api_config, context, false)
	)
	if request_error != OK:
		_busy = false
		var failed: Dictionary = {
			"status": "error",
			"message": "request_start_failed",
			"request_error": request_error,
		}
		_set_status("failed", failed)
		message_completed.emit(failed)
		return failed
	return {"status": "running"}


func _on_response(
	response: Dictionary,
	parent: Node,
	deck: DeckData,
	user_question: String,
	api_config: Dictionary,
	initial_context: Dictionary,
	detail_already_sent: bool
) -> void:
	if String(response.get("status", "")) == "error":
		if _is_plain_text_fallback_response(response):
			var recovered := _plain_text_fallback_response(response)
			_complete_successful_response(deck, user_question, recovered)
			return
		_busy = false
		_set_status("failed", response)
		message_completed.emit(response)
		return

	if _is_external_tool_requested(response) and not detail_already_sent:
		var tool_request := (response.get("tool_request", {}) as Dictionary).duplicate(true)
		var tool_result := _resolve_external_tool(tool_request, deck)
		var client = _get_client()
		if client == null:
			_busy = false
			var missing_client := {
				"status": "error",
				"message": "ai_client_load_failed",
			}
			_set_status("failed", missing_client)
			message_completed.emit(missing_client)
			return
		var history: Array[Dictionary] = _store.load_messages(deck.id)
		var followup_payload: Dictionary = _prompt_builder.build_tool_followup_payload(
			str(api_config.get("model", "")),
			initial_context,
			tool_result,
			history,
			user_question
		)
		_set_status("loading_external_tool", {
			"deck_id": deck.id,
			"tool_name": str(tool_request.get("name", "")),
			"query": str(tool_request.get("query", "")),
			"status": str(tool_result.get("status", "")),
		})
		var request_error: int = client.request_json(
			parent,
			str(api_config.get("endpoint", "")).strip_edges(),
			str(api_config.get("api_key", "")).strip_edges(),
			followup_payload,
			_on_response.bind(parent, deck, user_question, api_config, initial_context, true)
		)
		if request_error != OK:
			_busy = false
			var failed := {
				"status": "error",
				"message": "external_tool_request_start_failed",
				"request_error": request_error,
			}
			_set_status("failed", failed)
			message_completed.emit(failed)
		return

	if _is_external_tool_requested(response):
		response = response.duplicate(true)
		response["tool_request"] = null

	_complete_successful_response(deck, user_question, response)


func _complete_successful_response(deck: DeckData, user_question: String, response: Dictionary) -> void:
	_busy = false
	_store.append_turn(deck.id, "user", user_question)
	_store.append_turn(deck.id, "assistant", str(response.get("answer_markdown", "")), {
		"title": str(response.get("title", "")),
		"confidence": str(response.get("confidence", "")),
		"suggested_questions": response.get("suggested_questions", []),
		"math_steps": response.get("math_steps", []),
		"referenced_cards": response.get("referenced_cards", []),
	})
	_set_status("completed", {"deck_id": deck.id})
	message_completed.emit(response)


func _set_status(status: String, context: Dictionary) -> void:
	_write_debug_log({
		"event": "status",
		"status": status,
		"context": context,
	})
	status_changed.emit(status, context)


func _is_plain_text_fallback_response(response: Dictionary) -> bool:
	if str(response.get("error_type", "")) != "invalid_content_json":
		return false
	return _raw_text_from_invalid_json_response(response).strip_edges() != ""


func _plain_text_fallback_response(response: Dictionary) -> Dictionary:
	var answer := _raw_text_from_invalid_json_response(response).strip_edges()
	return {
		"title": "AI 回答",
		"answer_markdown": answer,
		"confidence": "medium",
		"suggested_questions": [],
		"math_steps": [],
		"referenced_cards": [],
		"tool_request": null,
		"fallback_from_plain_text": true,
	}


func _raw_text_from_invalid_json_response(response: Dictionary) -> String:
	var raw_content := str(response.get("raw_content", "")).strip_edges()
	if raw_content != "":
		return raw_content
	return str(response.get("raw_body", "")).strip_edges()


func _get_client() -> Variant:
	if _client == null:
		var script := load(ZENMUX_CLIENT_PATH)
		if script != null:
			_client = script.new()
	return _client


func _is_external_tool_requested(response: Dictionary) -> bool:
	var tool_request: Variant = response.get("tool_request", null)
	if not tool_request is Dictionary:
		return false
	return EXTERNAL_TOOL_NAMES.has(str((tool_request as Dictionary).get("name", "")))


func _tool_request_reason(response: Dictionary) -> String:
	var tool_request: Variant = response.get("tool_request", null)
	if tool_request is Dictionary:
		var reason := str((tool_request as Dictionary).get("reason", "")).strip_edges()
		if reason != "":
			return reason
	return "需要完整卡组信息"


func _resolve_external_tool(tool_request: Dictionary, current_deck: DeckData) -> Dictionary:
	var name := str(tool_request.get("name", "")).strip_edges()
	var query := str(tool_request.get("query", "")).strip_edges()
	var result := {
		"request": tool_request.duplicate(true),
		"tool_name": name,
		"query": query,
		"status": "not_found",
	}
	match name:
		"get_other_deck_detail":
			var other_deck := _find_deck_for_query(query)
			if other_deck == null:
				result["message"] = "未找到匹配卡组"
				return result
			result["status"] = "ok"
			result["deck_context"] = _context_builder.build_detailed_context(other_deck)
			return result
		"get_card_detail":
			var cards := _find_cards_for_query(query)
			if cards.is_empty():
				result["message"] = "未找到匹配单卡"
				return result
			var card_contexts: Array[Dictionary] = []
			for card: CardData in cards:
				card_contexts.append(_context_builder.build_card_detail_context(card, _count_card_in_deck(card, current_deck)))
			result["status"] = "ok"
			result["cards"] = card_contexts
			return result
		_:
			result["status"] = "unsupported_tool"
			result["message"] = "不支持的工具"
			return result


func _find_deck_for_query(query: String) -> DeckData:
	var normalized := _normalize_query(query)
	if normalized == "":
		return null
	if normalized.is_valid_int():
		var deck_id := int(normalized)
		var ai_deck: DeckData = CardDatabase.get_ai_deck(deck_id)
		if ai_deck != null:
			return ai_deck
		return CardDatabase.get_deck(deck_id)
	for alias: String in DECK_QUERY_ALIASES.keys():
		if normalized == _normalize_query(alias) or normalized.contains(_normalize_query(alias)):
			var alias_deck_id := int(DECK_QUERY_ALIASES[alias])
			var alias_ai_deck: DeckData = CardDatabase.get_ai_deck(alias_deck_id)
			if alias_ai_deck != null:
				return alias_ai_deck
			return CardDatabase.get_deck(alias_deck_id)
	var best_deck: DeckData = null
	for deck: DeckData in _all_known_decks():
		var names := [
			str(deck.id),
			deck.deck_name,
			deck.variant_name,
			str(ContextBuilderScript.DECK_NAME_OVERRIDES.get(deck.id, "")),
		]
		for deck_name: String in names:
			var normalized_name := _normalize_query(deck_name)
			if normalized_name == "":
				continue
			if normalized == normalized_name or normalized_name.contains(normalized) or normalized.contains(normalized_name):
				return deck
			if best_deck == null and _query_tokens_match(normalized, normalized_name):
				best_deck = deck
	return best_deck


func _all_known_decks() -> Array[DeckData]:
	var result: Array[DeckData] = []
	var seen := {}
	for deck: DeckData in CardDatabase.get_all_ai_decks():
		if deck == null or seen.has(deck.id):
			continue
		seen[deck.id] = true
		result.append(deck)
	for deck: DeckData in CardDatabase.get_all_decks():
		if deck == null or seen.has(deck.id):
			continue
		seen[deck.id] = true
		result.append(deck)
	return result


func _find_cards_for_query(query: String) -> Array[CardData]:
	var normalized := _normalize_query(query)
	if normalized == "":
		return []
	for alias: String in CARD_QUERY_ALIASES.keys():
		if normalized == _normalize_query(alias) or normalized.contains(_normalize_query(alias)):
			normalized = _normalize_query(str(CARD_QUERY_ALIASES[alias]))
			break
	var exact: Array[CardData] = []
	var partial: Array[CardData] = []
	for card: CardData in CardDatabase.get_all_cards():
		if card == null:
			continue
		var names := [
			card.name,
			card.name_en,
			card.get_uid(),
			str(ContextBuilderScript.CARD_NAME_ZH_OVERRIDES.get(card.name_en, "")),
		]
		var matched_exact := false
		var matched_partial := false
		for card_name: String in names:
			var normalized_name := _normalize_query(card_name)
			if normalized_name == "":
				continue
			if normalized == normalized_name:
				matched_exact = true
				break
			if normalized_name.contains(normalized) or normalized.contains(normalized_name) or _query_tokens_match(normalized, normalized_name):
				matched_partial = true
		if matched_exact:
			exact.append(card)
		elif matched_partial:
			partial.append(card)
	var matches := exact if not exact.is_empty() else partial
	matches.sort_custom(func(a: CardData, b: CardData) -> bool:
		return a.get_uid() < b.get_uid()
	)
	if matches.size() > 8:
		matches = matches.slice(0, 8)
	return matches


func _count_card_in_deck(card: CardData, deck: DeckData) -> int:
	if card == null or deck == null:
		return 0
	var total := 0
	for entry: Dictionary in deck.cards:
		var set_code := str(entry.get("set_code", ""))
		var card_index := str(entry.get("card_index", ""))
		if set_code == card.set_code and card_index == card.card_index:
			total += int(entry.get("count", 0))
	return total


func _normalize_query(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	for token: String in [" ", "\t", "\n", "\r", "·", "・", ".", "-", "_", "　"]:
		normalized = normalized.replace(token, "")
	return normalized


func _query_tokens_match(query: String, candidate: String) -> bool:
	if query == "" or candidate == "":
		return false
	if query.length() < 3:
		return false
	return candidate.contains(query) or query.contains(candidate)


func _summarize_tool_results(tool_results_variant: Variant) -> Array[Dictionary]:
	var summary: Array[Dictionary] = []
	if not tool_results_variant is Array:
		return summary
	for item_variant: Variant in tool_results_variant as Array:
		if not item_variant is Dictionary:
			continue
		var item := item_variant as Dictionary
		var row := {
			"tool_name": str(item.get("tool_name", "")),
			"query": str(item.get("query", "")),
			"status": str(item.get("status", "")),
		}
		if item.has("deck_context") and item.get("deck_context") is Dictionary:
			var deck_context := item.get("deck_context") as Dictionary
			row["deck_id"] = int(deck_context.get("deck_id", 0))
			row["deck_name"] = str(deck_context.get("deck_name", ""))
		if item.has("cards") and item.get("cards") is Array:
			var names: Array[String] = []
			for card_variant: Variant in item.get("cards") as Array:
				if card_variant is Dictionary:
					names.append(str((card_variant as Dictionary).get("name", "")))
			row["cards"] = names
		summary.append(row)
	return summary


func _write_debug_log(entry: Dictionary) -> void:
	entry["time"] = Time.get_datetime_string_from_system()
	if str(entry.get("event", "")) == "request_start":
		print("[DeckDiscussion] request_start deck_id=%s question=%s auto_tools=%s" % [
			str(entry.get("deck_id", "")),
			str(entry.get("question", "")),
			JSON.stringify(entry.get("auto_external_tool_results", [])),
		])
	var dir := "user://deck_discussions"
	var absolute_dir := ProjectSettings.globalize_path(dir)
	if not DirAccess.dir_exists_absolute(absolute_dir):
		var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
		if mkdir_error != OK:
			push_warning("Deck discussion debug log mkdir failed: %s error=%s" % [absolute_dir, mkdir_error])
			return
	var path := absolute_dir.trim_suffix("/") + "/deck_discussion_debug.log"
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	var open_error := FileAccess.get_open_error()
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
		open_error = FileAccess.get_open_error()
	if file == null:
		path = "user://deck_discussions/deck_discussion_debug.log"
		file = FileAccess.open(path, FileAccess.READ_WRITE)
		open_error = FileAccess.get_open_error()
		if file == null:
			file = FileAccess.open(path, FileAccess.WRITE)
			open_error = FileAccess.get_open_error()
	if file == null:
		path = ProjectSettings.globalize_path("res://tmp/deck_discussion_debug.log")
		file = FileAccess.open(path, FileAccess.READ_WRITE)
		open_error = FileAccess.get_open_error()
		if file == null:
			file = FileAccess.open(path, FileAccess.WRITE)
			open_error = FileAccess.get_open_error()
	if file == null:
		push_warning("Deck discussion debug log write failed: %s error=%s" % [path, open_error])
		return
	file.seek_end()
	file.store_line(JSON.stringify(entry))
	file.close()


func _context_for_question(deck: DeckData, user_question: String, forced_external_tool_results: Array[Dictionary] = []) -> Dictionary:
	# Deck discussion now sends the compact full deck list up front. The old
	# light-context/tool-fetch path caused short card-slot questions to drift
	# into generic deck analysis.
	var context: Dictionary = _context_builder.build_detailed_context(deck)
	var merged_results: Array[Dictionary] = []
	for forced_result: Dictionary in forced_external_tool_results:
		if not forced_result.is_empty():
			merged_results.append(forced_result.duplicate(true))
	var auto_results := _auto_resolve_external_tools(user_question, deck)
	merged_results.append_array(auto_results)
	if not merged_results.is_empty():
		context["external_tool_results"] = merged_results
	return context


func _auto_resolve_external_tools(user_question: String, current_deck: DeckData) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var other_deck_result := _auto_resolve_other_deck(user_question, current_deck)
	if not other_deck_result.is_empty():
		results.append(other_deck_result)
	var card_results := _auto_resolve_external_cards(user_question, current_deck)
	results.append_array(card_results)
	return results


func _auto_resolve_other_deck(user_question: String, current_deck: DeckData) -> Dictionary:
	var normalized_question := _normalize_query(user_question)
	if normalized_question == "":
		return {}
	for alias: String in DECK_QUERY_ALIASES.keys():
		var alias_normalized := _normalize_query(alias)
		if alias_normalized == "" or not normalized_question.contains(alias_normalized):
			continue
		var deck_id := int(DECK_QUERY_ALIASES[alias])
		if current_deck != null and current_deck.id == deck_id:
			continue
		return _resolve_external_tool({
			"name": "get_other_deck_detail",
			"reason": "服务层自动检测到用户询问另一套卡组",
			"query": alias,
		}, current_deck)
	return {}


func _auto_resolve_external_cards(user_question: String, current_deck: DeckData) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var seen := {}
	var candidates: Array[CardData] = []
	candidates.append_array(_find_cards_for_query(user_question))
	for alias: String in CARD_QUERY_ALIASES.keys():
		if _normalize_query(user_question).contains(_normalize_query(alias)):
			candidates.append_array(_find_cards_for_query(alias))
	for card: CardData in candidates:
		if card == null:
			continue
		var uid := card.get_uid()
		if seen.has(uid):
			continue
		seen[uid] = true
		if _count_card_in_deck(card, current_deck) > 0:
			continue
		results.append(_resolve_external_tool({
			"name": "get_card_detail",
			"reason": "服务层自动检测到用户询问当前卡组外单卡",
			"query": card.name if card.name != "" else card.name_en,
		}, current_deck))
		if results.size() >= 3:
			break
	return results


func _needs_detailed_card_text_question(user_question: String) -> bool:
	var q := user_question.strip_edges()
	var detail_markers := [
		"技能",
		"特性",
		"招式",
		"效果",
		"文本",
		"原文",
		"HP",
		"血量",
	]
	var comparison_markers := [
		"不同",
		"区别",
		"差别",
		"差异",
		"版本",
		"两",
		"2",
		"两个",
		"两张",
		"同名",
		"为什么带",
		"为何带",
	]
	var card_intent_markers := [
		"必要性",
		"有必要",
		"需要吗",
		"要不要",
		"为什么带",
		"为何带",
		"带不带",
		"该不该",
		"值不值",
		"作用",
		"用途",
		"用处",
		"干嘛",
		"有什么用",
		"重要吗",
		"强吗",
		"弱吗",
		"替换",
		"换掉",
		"删掉",
		"加入",
		"投入",
		"卡位",
		"几张",
		"多少张",
	]
	for detail_marker: String in detail_markers:
		if q.findn(detail_marker) < 0:
			continue
		return true
	for comparison_marker: String in comparison_markers:
		if q.findn(comparison_marker) >= 0:
			return true
	for card_intent_marker: String in card_intent_markers:
		if q.findn(card_intent_marker) >= 0:
			return true
	return false


func _is_play_guide_question(user_question: String) -> bool:
	var q := user_question.strip_edges()
	var markers := [
		"怎么玩",
		"怎么打",
		"打法",
		"思路",
		"运营",
		"起手",
		"展开",
		"节奏",
		"这卡",
		"这套",
		"play",
		"guide",
	]
	for marker: String in markers:
		if q.findn(marker) >= 0:
			return true
	return false
