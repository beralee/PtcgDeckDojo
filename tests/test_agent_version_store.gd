class_name TestAgentVersionStore
extends TestBase

const AgentVersionStoreScript = preload("res://scripts/ai/AgentVersionStore.gd")


func _make_test_config() -> Dictionary:
	return {
		"heuristic_weights": {
			"attack_knockout": 1000.0,
			"attack_base": 500.0,
		},
		"mcts_config": {
			"branch_factor": 3,
			"rollouts_per_sequence": 20,
		},
	}


func _cleanup_test_dir() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.dir_exists("ai_agents_test"):
		dir.change_dir("ai_agents_test")
		var files := dir.get_files()
		for file_name: String in files:
			dir.remove(file_name)
		dir.change_dir("..")
		dir.remove("ai_agents_test")


func test_save_and_load_roundtrip() -> String:
	_cleanup_test_dir()
	var store := AgentVersionStoreScript.new()
	store.base_dir = "user://ai_agents_test"
	var config := _make_test_config()
	var metadata := {"generation": 5, "parent_version": "", "win_rate_vs_parent": 0.583}
	var path: String = store.save_version(config, metadata)
	var loaded: Dictionary = store.load_version(path)
	_cleanup_test_dir()
	return run_checks([
		assert_true(path != "", "save_version 应返回非空路径"),
		assert_eq(loaded.get("generation"), 5, "应保留 generation"),
		assert_true(abs(float(loaded.get("win_rate_vs_parent", 0.0)) - 0.583) < 0.001, "应保留 win_rate_vs_parent"),
		assert_true(loaded.has("heuristic_weights"), "应包含 heuristic_weights"),
		assert_eq(loaded.get("heuristic_weights", {}).get("attack_knockout"), 1000.0, "权重值应完整保留"),
		assert_true(loaded.has("mcts_config"), "应包含 mcts_config"),
		assert_eq(loaded.get("mcts_config", {}).get("branch_factor"), 3, "MCTS 参数应完整保留"),
		assert_true(loaded.has("version"), "应包含 version 字段"),
		assert_true(loaded.has("timestamp"), "应包含 timestamp 字段"),
	])


func test_load_latest_returns_most_recent() -> String:
	_cleanup_test_dir()
	var store := AgentVersionStoreScript.new()
	store.base_dir = "user://ai_agents_test"
	var config_a := _make_test_config()
	store.save_version(config_a, {"generation": 1, "parent_version": "", "win_rate_vs_parent": 0.52})
	var config_b := _make_test_config()
	config_b["heuristic_weights"]["attack_knockout"] = 9999.0
	store.save_version(config_b, {"generation": 2, "parent_version": "", "win_rate_vs_parent": 0.55})
	var latest: Dictionary = store.load_latest()
	_cleanup_test_dir()
	return run_checks([
		assert_eq(latest.get("generation"), 2, "load_latest 应返回最新一代"),
		assert_eq(latest.get("heuristic_weights", {}).get("attack_knockout"), 9999.0, "应返回最新权重"),
	])


func test_list_versions_returns_sorted() -> String:
	_cleanup_test_dir()
	var store := AgentVersionStoreScript.new()
	store.base_dir = "user://ai_agents_test"
	store.save_version(_make_test_config(), {"generation": 1, "parent_version": "", "win_rate_vs_parent": 0.51})
	store.save_version(_make_test_config(), {"generation": 2, "parent_version": "", "win_rate_vs_parent": 0.53})
	store.save_version(_make_test_config(), {"generation": 3, "parent_version": "", "win_rate_vs_parent": 0.56})
	var versions: Array[Dictionary] = store.list_versions()
	_cleanup_test_dir()
	return run_checks([
		assert_eq(versions.size(), 3, "应列出 3 个版本"),
		assert_eq(versions[0].get("generation"), 1, "第一个应是最早的版本"),
		assert_eq(versions[2].get("generation"), 3, "最后一个应是最新的版本"),
	])


func test_load_latest_returns_empty_when_no_versions() -> String:
	_cleanup_test_dir()
	var store := AgentVersionStoreScript.new()
	store.base_dir = "user://ai_agents_test"
	var latest: Dictionary = store.load_latest()
	_cleanup_test_dir()
	return run_checks([
		assert_true(latest.is_empty(), "无版本时 load_latest 应返回空字典"),
	])
