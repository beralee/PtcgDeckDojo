class_name TestDeckDiscussionSessionStore
extends TestBase

const StoreScript := preload("res://scripts/engine/DeckDiscussionSessionStore.gd")


func test_session_store_persists_messages() -> String:
	var store = StoreScript.new()
	var deck_id := 800001
	store.clear_session(deck_id)

	store.append_turn(deck_id, "user", "这套牌稳定吗？")
	store.append_turn(deck_id, "assistant", "先看基础数量和起手概率。", {"confidence": "medium"})
	var messages := store.load_messages(deck_id)

	var first_role := str(messages[0].get("role", "")) if messages.size() > 0 else ""
	var second_role := str(messages[1].get("role", "")) if messages.size() > 1 else ""
	var second_metadata: Dictionary = messages[1].get("metadata", {}) if messages.size() > 1 else {}

	store.clear_session(deck_id)
	return run_checks([
		assert_eq(messages.size(), 2, "应持久化两条消息"),
		assert_eq(first_role, "user", "第一条应为用户消息"),
		assert_eq(second_role, "assistant", "第二条应为 AI 消息"),
		assert_eq(str(second_metadata.get("confidence", "")), "medium", "应保留元数据"),
	])


func test_clear_session_removes_history() -> String:
	var store = StoreScript.new()
	var deck_id := 800002
	store.append_turn(deck_id, "user", "测试")
	store.clear_session(deck_id)
	var messages := store.load_messages(deck_id)
	store.clear_session(deck_id)

	return run_checks([
		assert_eq(messages.size(), 0, "清空后不应保留历史"),
	])
