class_name TestSuiteCatalogSuite
extends TestBase

const TestSuiteCatalogScript = preload("res://tests/TestSuiteCatalog.gd")


func test_catalog_discovers_every_test_file() -> String:
	var discovered := TestSuiteCatalogScript.all_suites()
	var discovered_paths := {}
	for suite: Dictionary in discovered:
		discovered_paths[str(suite.get("path", ""))] = true

	var missing: Array[String] = []
	_collect_missing("res://tests", "res://tests", discovered_paths, missing)

	return run_checks([
		assert_eq(missing.size(), 0, "Every test_*.gd file should be discoverable through the suite catalog"),
	])


func _collect_missing(root_dir: String, current_dir: String, discovered_paths: Dictionary, missing: Array[String]) -> void:
	var dir := DirAccess.open(current_dir)
	if dir == null:
		missing.append("%s::<open_failed>" % current_dir)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry in [".", ".."]:
			entry = dir.get_next()
			continue
		var script_path := current_dir.path_join(entry)
		if dir.current_is_dir():
			_collect_missing(root_dir, script_path, discovered_paths, missing)
		elif entry.begins_with("test_") and entry.ends_with(".gd"):
			if not bool(discovered_paths.get(script_path, false)):
				missing.append(script_path)
		entry = dir.get_next()
	dir.list_dir_end()


func test_functional_group_includes_previously_omitted_core_suites() -> String:
	var names := TestSuiteCatalogScript.get_suite_names_for_group(TestSuiteCatalogScript.GROUP_FUNCTIONAL)
	var name_set := {}
	for suite_name: String in names:
		name_set[suite_name] = true

	return run_checks([
		assert_true(bool(name_set.get("PersistentEffects", false)), "Functional group should include PersistentEffects"),
		assert_true(bool(name_set.get("RuleValidator", false)), "Functional group should include RuleValidator"),
		assert_true(bool(name_set.get("DamageCalculator", false)), "Functional group should include DamageCalculator"),
		assert_true(bool(name_set.get("SetupFlow", false)), "Functional group should include SetupFlow"),
		assert_true(bool(name_set.get("EffectRegistry", false)), "Functional group should include EffectRegistry"),
	])


func test_ai_training_group_is_isolated_from_functional_rule_suites() -> String:
	var names := TestSuiteCatalogScript.get_suite_names_for_group(TestSuiteCatalogScript.GROUP_AI_TRAINING)
	var name_set := {}
	for suite_name: String in names:
		name_set[suite_name] = true

	return run_checks([
		assert_true(bool(name_set.get("AIBaseline", false)), "AI/training group should include AI baseline coverage"),
		assert_true(bool(name_set.get("MCTSPlanner", false)), "AI/training group should include MCTS coverage"),
		assert_false(bool(name_set.get("RuleValidator", false)), "AI/training group should not include core rule validation tests"),
		assert_false(bool(name_set.get("BattleUIFeatures", false)), "AI/training group should not include Battle UI regression tests"),
	])
