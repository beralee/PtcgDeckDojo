class_name TestScriptLoadRegressions
extends TestBase


func test_rare_candy_and_card_semantic_matrix_scripts_load() -> String:
	var rare_candy_script := load("res://scripts/effects/trainer_effects/EffectRareCandy.gd")
	var semantic_matrix_script := load("res://tests/test_card_semantic_matrix.gd")
	var rare_candy_instance = rare_candy_script.new() if rare_candy_script != null and rare_candy_script.can_instantiate() else null
	var semantic_matrix_instance = semantic_matrix_script.new() if semantic_matrix_script != null and semantic_matrix_script.can_instantiate() else null

	return run_checks([
		assert_not_null(rare_candy_script, "EffectRareCandy.gd should load without compile errors"),
		assert_not_null(semantic_matrix_script, "test_card_semantic_matrix.gd should load without compile errors"),
		assert_not_null(rare_candy_instance, "EffectRareCandy.gd should instantiate without compile errors"),
		assert_not_null(semantic_matrix_instance, "test_card_semantic_matrix.gd should instantiate without compile errors"),
	])
