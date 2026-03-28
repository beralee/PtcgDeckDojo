class_name TestAIVersionRegistry
extends TestBase

const RegistryScript = preload("res://scripts/ai/AIVersionRegistry.gd")


func _cleanup() -> void:
	var dir_path := ProjectSettings.globalize_path("user://ai_versions_test")
	if DirAccess.dir_exists_absolute(dir_path):
		DirAccess.remove_absolute(dir_path.path_join("index.json"))
		DirAccess.remove_absolute(dir_path)


func test_save_and_load_version_roundtrip() -> String:
	_cleanup()
	var registry := RegistryScript.new()
	registry.base_dir = "user://ai_versions_test"
	var record := {
		"version_id": "AI-20260328-01",
		"display_name": "v015 + value1",
		"status": "playable",
		"agent_config_path": "user://ai_agents/agent_v015.json",
		"value_net_path": "user://ai_models/value_net_v1.json",
		"benchmark_summary": {"win_rate_vs_current_best": 0.57}
	}
	var ok: bool = registry.save_version(record)
	var loaded: Dictionary = registry.get_version("AI-20260328-01")
	_cleanup()
	return run_checks([
		assert_true(ok, "save_version 应成功"),
		assert_eq(loaded.get("display_name", ""), "v015 + value1", "应保留 display_name"),
		assert_eq(loaded.get("status", ""), "playable", "应保留 status"),
		assert_true(str(loaded.get("created_at", "")).length() > 0, "应自动填充 created_at"),
	])


func test_list_playable_versions_filters_trainable() -> String:
	_cleanup()
	var registry := RegistryScript.new()
	registry.base_dir = "user://ai_versions_test"
	registry.save_version({"version_id": "AI-1", "display_name": "one", "status": "trainable"})
	registry.save_version({"version_id": "AI-2", "display_name": "two", "status": "playable"})
	var versions: Array[Dictionary] = registry.list_playable_versions()
	_cleanup()
	var first_version_id: String = ""
	if not versions.is_empty():
		first_version_id = str(versions[0].get("version_id", ""))
	return run_checks([
		assert_eq(versions.size(), 1, "只应返回 playable 版本"),
		assert_eq(first_version_id, "AI-2", "应返回 playable 版本"),
	])


func test_get_latest_playable_version_ignores_non_playable() -> String:
	_cleanup()
	var registry := RegistryScript.new()
	registry.base_dir = "user://ai_versions_test"
	registry.save_version({"version_id": "AI-1", "display_name": "one", "status": "playable"})
	registry.save_version({"version_id": "AI-2", "display_name": "two", "status": "trainable"})
	registry.save_version({"version_id": "AI-3", "display_name": "three", "status": "playable"})
	var latest: Dictionary = registry.get_latest_playable_version()
	_cleanup()
	return run_checks([
		assert_eq(latest.get("version_id", ""), "AI-3", "latest playable 应忽略 trainable 记录"),
	])


func test_get_latest_playable_version_uses_save_order_for_same_second_records() -> String:
	_cleanup()
	var registry := RegistryScript.new()
	registry.base_dir = "user://ai_versions_test"
	registry.save_version({"version_id": "AI-1", "display_name": "one", "status": "playable", "created_at": "2026-03-28T12:00:00"})
	registry.save_version({"version_id": "AI-2", "display_name": "two", "status": "playable", "created_at": "2026-03-28T12:00:00"})
	var latest: Dictionary = registry.get_latest_playable_version()
	_cleanup()
	return run_checks([
		assert_eq(latest.get("version_id", ""), "AI-2", "相同 created_at 时应按保存顺序选择最新版本"),
	])
