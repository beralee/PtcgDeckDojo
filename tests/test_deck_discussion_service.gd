class_name TestDeckDiscussionService
extends TestBase

const ServiceScript := preload("res://scripts/engine/DeckDiscussionService.gd")
const ContextBuilderScript := preload("res://scripts/engine/DeckDiscussionContextBuilder.gd")
const PromptBuilderScript := preload("res://scripts/engine/DeckDiscussionPromptBuilder.gd")
const StoreScript := preload("res://scripts/engine/DeckDiscussionSessionStore.gd")


class FakeClient:
	var payload_seen: Dictionary = {}
	var callback_seen: Callable
	var payloads: Array[Dictionary] = []
	var callbacks: Array[Callable] = []

	func set_timeout_seconds(_timeout_seconds: float) -> void:
		pass

	func request_json(_parent: Node, _endpoint: String, _api_key: String, payload: Dictionary, callback: Callable) -> int:
		payload_seen = payload.duplicate(true)
		callback_seen = callback
		payloads.append(payload.duplicate(true))
		callbacks.append(callback)
		return OK


func test_service_persists_successful_assistant_response() -> String:
	var service = ServiceScript.new()
	var client := FakeClient.new()
	var store = StoreScript.new()
	var deck := _make_test_deck(910001)
	store.clear_session(deck.id)
	service.configure_dependencies(client, ContextBuilderScript.new(), PromptBuilderScript.new(), store)
	var parent := Node.new()

	var result: Dictionary = service.ask(
		parent,
		deck,
		"起手稳定吗？",
		{
			"endpoint": "https://example.invalid/v1",
			"api_key": "test-key",
			"model": "test-model",
		}
	)
	client.callback_seen.call({
		"title": "起手稳定性",
		"answer_markdown": "基础数量足够，起手稳定。",
		"confidence": "high",
		"suggested_questions": ["同时有能量的概率是多少？"],
		"math_steps": ["P=1-C(52,7)/C(60,7)"],
		"referenced_cards": ["Charmander"],
		"tool_request": null,
	})
	var messages := store.load_messages(deck.id)
	var assistant_text := str(messages[1].get("content", "")) if messages.size() > 1 else ""
	parent.free()
	store.clear_session(deck.id)

	return run_checks([
		assert_eq(str(result.get("status", "")), "running", "请求启动后应处于 running 状态"),
		assert_true(client.payload_seen.has("messages"), "请求应发送 chat messages"),
		assert_eq(messages.size(), 2, "成功回调后应保存用户和 AI 两条消息"),
		assert_eq(assistant_text, "基础数量足够，起手稳定。", "应保存 AI 回答正文"),
	])


func test_service_includes_ai_personality_in_prompt() -> String:
	var service = ServiceScript.new()
	var client := FakeClient.new()
	var store = StoreScript.new()
	var deck := _make_test_deck(910011)
	store.clear_session(deck.id)
	service.configure_dependencies(client, ContextBuilderScript.new(), PromptBuilderScript.new(), store)
	var parent := Node.new()

	service.ask(
		parent,
		deck,
		"这回合怎么打？",
		{
			"endpoint": "https://example.invalid/v1",
			"api_key": "test-key",
			"model": "test-model",
			"ai_personality": "谨慎但搞笑",
		}
	)
	var payload_text := JSON.stringify(client.payload_seen)
	parent.free()
	store.clear_session(deck.id)

	return run_checks([
		assert_true(payload_text.contains("谨慎但搞笑"), "Deck discussion prompt should include the configured AI personality"),
		assert_true(payload_text.contains("describes you, the AI assistant"), "AI personality should clearly apply to the assistant"),
		assert_true(payload_text.contains("Apply it only to your tone"), "AI personality should be constrained to style only"),
	])


func test_service_sends_compact_full_context_first_without_tool_roundtrip() -> String:
	var service = ServiceScript.new()
	var client := FakeClient.new()
	var store = StoreScript.new()
	var deck := _make_test_deck(910002)
	store.clear_session(deck.id)
	service.configure_dependencies(client, ContextBuilderScript.new(), PromptBuilderScript.new(), store)
	var parent := Node.new()

	service.ask(
		parent,
		deck,
		"喷火龙和大比鸟的进化链是否够？",
		{
			"endpoint": "https://example.invalid/v1",
			"api_key": "test-key",
			"model": "test-model",
		}
	)
	var first_messages: Array = client.payloads[0].get("messages", [])
	var first_context_text := str((first_messages[1] as Dictionary).get("content", ""))
	client.callbacks[0].call({
		"title": "进化链评估",
		"answer_markdown": "小火龙和喷火龙ex数量偏薄，需要结合神奇糖果评估。",
		"confidence": "medium",
		"suggested_questions": [],
		"math_steps": [],
		"referenced_cards": ["Charmander", "Charizard ex"],
		"tool_request": null,
	})
	var messages := store.load_messages(deck.id)
	parent.free()
	store.clear_session(deck.id)

	return run_checks([
		assert_eq(client.payloads.size(), 1, "deck discussion should send full context in the first request"),
		assert_true(first_context_text.contains("\"context_level\": \"detailed\""), "first request should use detailed context"),
		assert_true(first_context_text.contains("\"set_code\""), "full context should include per-card identity"),
		assert_true(first_context_text.contains("\"count\""), "full context should include card counts instead of duplicating repeated cards"),
		assert_true(first_context_text.contains("小火龙"), "context should prefer Chinese card names"),
		assert_true(first_context_text.contains("get_other_deck_detail"), "prompt should expose other-deck lookup tool"),
		assert_true(first_context_text.contains("get_card_detail"), "prompt should expose external card lookup tool"),
		assert_eq(messages.size(), 2, "only user question and final answer should be saved"),
	])


func test_play_guide_question_uses_play_guide_context_without_tool_roundtrip() -> String:
	var service = ServiceScript.new()
	var client := FakeClient.new()
	var store = StoreScript.new()
	var deck := _make_test_deck(910003)
	store.clear_session(deck.id)
	service.configure_dependencies(client, ContextBuilderScript.new(), PromptBuilderScript.new(), store)
	var parent := Node.new()

	service.ask(
		parent,
		deck,
		"这卡怎么玩？",
		{
			"endpoint": "https://example.invalid/v1",
			"api_key": "test-key",
			"model": "test-model",
		}
	)
	var first_messages: Array = client.payloads[0].get("messages", [])
	var first_context_text := str((first_messages[1] as Dictionary).get("content", ""))
	client.callbacks[0].call({
		"title": "玩法",
		"answer_markdown": "先按核心宝可梦和引擎卡确认展开路线。",
		"confidence": "medium",
		"suggested_questions": [],
		"math_steps": [],
		"referenced_cards": [],
		"tool_request": null,
	})
	parent.free()
	store.clear_session(deck.id)

	return run_checks([
		assert_eq(client.payloads.size(), 1, "play guide question should not require an automatic second request"),
		assert_true(first_context_text.contains("\"context_level\": \"detailed\""), "play guide question should also use the full deck context"),
	])


func test_card_version_difference_question_uses_detailed_context_immediately() -> String:
	var service = ServiceScript.new()
	var client := FakeClient.new()
	var store = StoreScript.new()
	var deck := _make_test_deck(910005)
	store.clear_session(deck.id)
	service.configure_dependencies(client, ContextBuilderScript.new(), PromptBuilderScript.new(), store)
	var parent := Node.new()

	service.ask(
		parent,
		deck,
		"为什么现在带了2个不同的小火龙，他们的技能不同吗？",
		{
			"endpoint": "https://example.invalid/v1",
			"api_key": "test-key",
			"model": "test-model",
		}
	)
	var first_messages: Array = client.payloads[0].get("messages", [])
	var first_context_text := str((first_messages[1] as Dictionary).get("content", ""))
	parent.free()
	store.clear_session(deck.id)

	return run_checks([
		assert_eq(client.payloads.size(), 1, "card text comparison should not wait for a tool roundtrip"),
		assert_true(first_context_text.contains("\"context_level\": \"detailed\""), "card text comparison should start with detailed context"),
		assert_true(first_context_text.contains("\"attacks\""), "detailed context should include attacks for version comparison"),
		assert_true(first_context_text.contains("\"set_code\""), "detailed context should include card identity for version comparison"),
	])


func test_card_necessity_question_uses_detailed_context_immediately() -> String:
	var service = ServiceScript.new()
	var client := FakeClient.new()
	var store = StoreScript.new()
	var deck := _make_test_deck(910006)
	store.clear_session(deck.id)
	service.configure_dependencies(client, ContextBuilderScript.new(), PromptBuilderScript.new(), store)
	var parent := Node.new()

	service.ask(
		parent,
		deck,
		"洗翠沉重球有多大的必要性？",
		{
			"endpoint": "https://example.invalid/v1",
			"api_key": "test-key",
			"model": "test-model",
		}
	)
	var first_messages: Array = client.payloads[0].get("messages", [])
	var first_context_text := str((first_messages[1] as Dictionary).get("content", ""))
	parent.free()
	store.clear_session(deck.id)

	return run_checks([
		assert_eq(client.payloads.size(), 1, "card necessity questions should not wait for a tool roundtrip"),
		assert_true(first_context_text.contains("\"context_level\": \"detailed\""), "card necessity questions should start with detailed context"),
		assert_true(first_context_text.contains("\"set_code\""), "detailed context should include card identity for card-slot analysis"),
	])


func test_service_accepts_plain_text_model_response_for_discussion() -> String:
	var service = ServiceScript.new()
	var client := FakeClient.new()
	var store = StoreScript.new()
	var deck := _make_test_deck(910004)
	store.clear_session(deck.id)
	service.configure_dependencies(client, ContextBuilderScript.new(), PromptBuilderScript.new(), store)
	var parent := Node.new()

	service.ask(
		parent,
		deck,
		"how should I play this deck?",
		{
			"endpoint": "https://example.invalid/v1",
			"api_key": "test-key",
			"model": "deepseek/deepseek-v4-pro",
		}
	)
	client.callback_seen.call({
		"status": "error",
		"error_type": "invalid_content_json",
		"message": "ZenMux message content was not valid JSON",
		"raw_content": "Plain text answer from a model that ignored the JSON schema.",
	})
	var messages := store.load_messages(deck.id)
	var assistant_text := str(messages[1].get("content", "")) if messages.size() > 1 else ""
	parent.free()
	store.clear_session(deck.id)

	return run_checks([
		assert_eq(messages.size(), 2, "Plain text fallback should still save the user and assistant messages"),
		assert_eq(assistant_text, "Plain text answer from a model that ignored the JSON schema.", "Plain text fallback should preserve model content"),
		assert_false(service.is_busy(), "Plain text fallback should complete the service request"),
	])


func test_other_deck_tool_loads_matching_deck_context() -> String:
	var service = ServiceScript.new()
	var client := FakeClient.new()
	var store = StoreScript.new()
	var deck := _make_test_deck(910007)
	store.clear_session(deck.id)
	service.configure_dependencies(client, ContextBuilderScript.new(), PromptBuilderScript.new(), store)
	var parent := Node.new()

	service.ask(
		parent,
		deck,
		"这套牌打沙奈朵要怎么调整？",
		{
			"endpoint": "https://example.invalid/v1",
			"api_key": "test-key",
			"model": "test-model",
		}
	)
	var first_messages: Array = client.payloads[0].get("messages", [])
	var first_context_text := str((first_messages[1] as Dictionary).get("content", ""))
	var near_final_context_text := str((first_messages[first_messages.size() - 2] as Dictionary).get("content", "")) if first_messages.size() >= 2 else ""
	var auto_loaded := first_context_text.contains("\"external_tool_results\"") and first_context_text.contains("沙奈朵")
	client.callbacks[0].call({
		"title": "需要沙奈朵卡表",
		"answer_markdown": "需要先看沙奈朵。",
		"confidence": "low",
		"suggested_questions": [],
		"math_steps": [],
		"referenced_cards": [],
		"tool_request": {
			"name": "get_other_deck_detail",
			"reason": "用户询问另一套卡组",
			"query": "沙奈朵",
		},
	})
	var second_messages: Array = client.payloads[1].get("messages", [])
	var tool_context_text := str((second_messages.back() as Dictionary).get("content", ""))
	client.callbacks[1].call({
		"title": "对沙奈朵",
		"answer_markdown": "优先压制奇鲁莉安和弃能节奏。",
		"confidence": "medium",
		"suggested_questions": [],
		"math_steps": [],
		"referenced_cards": ["沙奈朵"],
		"tool_request": null,
	})
	var messages := store.load_messages(deck.id)
	parent.free()
	store.clear_session(deck.id)

	return run_checks([
		assert_eq(client.payloads.size(), 2, "other deck tool should trigger exactly one followup request"),
		assert_true(auto_loaded, "service should auto-load obvious other-deck context before waiting for model tool request"),
		assert_true(near_final_context_text.contains("external_tool_results") and near_final_context_text.contains("沙奈朵"), "auto-loaded other deck context should be repeated immediately before the final question"),
		assert_true(tool_context_text.contains("\"tool_name\": \"get_other_deck_detail\""), "tool result should identify the deck tool"),
		assert_true(tool_context_text.contains("\"status\": \"ok\""), "known deck query should resolve successfully"),
		assert_true(tool_context_text.contains("沙奈朵"), "tool result should include the requested deck context"),
		assert_eq(messages.size(), 2, "tool intermediate turn should not be stored"),
	])


func test_external_card_tool_loads_card_detail_context() -> String:
	var service = ServiceScript.new()
	var client := FakeClient.new()
	var store = StoreScript.new()
	var deck := _make_test_deck(910008)
	store.clear_session(deck.id)
	service.configure_dependencies(client, ContextBuilderScript.new(), PromptBuilderScript.new(), store)
	var parent := Node.new()

	service.ask(
		parent,
		deck,
		"铁臂膀能不能换成月月熊？",
		{
			"endpoint": "https://example.invalid/v1",
			"api_key": "test-key",
			"model": "test-model",
		}
	)
	var first_messages: Array = client.payloads[0].get("messages", [])
	var first_context_text := str((first_messages[1] as Dictionary).get("content", ""))
	var near_final_context_text := str((first_messages[first_messages.size() - 2] as Dictionary).get("content", "")) if first_messages.size() >= 2 else ""
	var auto_loaded := first_context_text.contains("\"external_tool_results\"") and (first_context_text.contains("月月熊") or first_context_text.contains("Bloodmoon Ursaluna"))
	client.callbacks[0].call({
		"title": "需要月月熊信息",
		"answer_markdown": "需要先看月月熊。",
		"confidence": "low",
		"suggested_questions": [],
		"math_steps": [],
		"referenced_cards": [],
		"tool_request": {
			"name": "get_card_detail",
			"reason": "用户询问当前卡组外单卡",
			"query": "月月熊",
		},
	})
	var second_messages: Array = client.payloads[1].get("messages", [])
	var tool_context_text := str((second_messages.back() as Dictionary).get("content", ""))
	client.callbacks[1].call({
		"title": "替换评估",
		"answer_markdown": "不建议直接等价替换，月月熊偏残局补刀。",
		"confidence": "medium",
		"suggested_questions": [],
		"math_steps": [],
		"referenced_cards": ["月月熊 赫月ex"],
		"tool_request": null,
	})
	var messages := store.load_messages(deck.id)
	parent.free()
	store.clear_session(deck.id)

	return run_checks([
		assert_eq(client.payloads.size(), 2, "external card tool should trigger exactly one followup request"),
		assert_true(auto_loaded, "service should auto-load obvious external-card context before waiting for model tool request"),
		assert_true(near_final_context_text.contains("external_tool_results") and (near_final_context_text.contains("月月熊") or near_final_context_text.contains("Bloodmoon Ursaluna")), "auto-loaded external card context should be repeated immediately before the final question"),
		assert_true(tool_context_text.contains("\"tool_name\": \"get_card_detail\""), "tool result should identify the card tool"),
		assert_true(tool_context_text.contains("\"status\": \"ok\""), "known card query should resolve successfully"),
		assert_true(tool_context_text.contains("月月熊") or tool_context_text.contains("Bloodmoon Ursaluna"), "tool result should include the requested card detail"),
		assert_true(tool_context_text.contains("\"cards\""), "tool result should include card detail payload"),
		assert_eq(messages.size(), 2, "tool intermediate turn should not be stored"),
	])


func _make_test_deck(deck_id: int) -> DeckData:
	var deck := DeckData.new()
	deck.id = deck_id
	deck.deck_name = "乱码测试卡组"
	deck.total_cards = 60
	deck.cards = [
		{"set_code": "SVP", "card_index": "067", "count": 3, "card_type": "Pokemon", "name": "bad-name-1", "name_en": "Charmander"},
		{"set_code": "CSV5C", "card_index": "075", "count": 2, "card_type": "Pokemon", "name": "bad-name-2", "name_en": "Charizard ex"},
		{"set_code": "CSV4C", "card_index": "101", "count": 2, "card_type": "Pokemon", "name": "bad-name-3", "name_en": "Pidgeot ex"},
		{"set_code": "CSV7C", "card_index": "177", "count": 4, "card_type": "Item", "name": "bad-name-4", "name_en": "Buddy-Buddy Poffin"},
		{"set_code": "CSVE1C", "card_index": "FIR", "count": 5, "card_type": "Basic Energy", "name": "bad-name-5", "name_en": "Fire Energy"},
	]
	return deck
