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


func test_benchmark_runner_and_game_state_machine_scripts_load() -> String:
	var benchmark_runner_script := load("res://scripts/training/run_deck_benchmark.gd")
	var gsm_script := load("res://scripts/engine/GameStateMachine.gd")
	var benchmark_runner_instance = benchmark_runner_script.new() if benchmark_runner_script != null and benchmark_runner_script.can_instantiate() else null
	var gsm_instance = gsm_script.new() if gsm_script != null and gsm_script.can_instantiate() else null

	return run_checks([
		assert_not_null(benchmark_runner_script, "run_deck_benchmark.gd should load without compile errors"),
		assert_not_null(gsm_script, "GameStateMachine.gd should load without compile errors"),
		assert_not_null(benchmark_runner_instance, "run_deck_benchmark.gd should instantiate without compile errors"),
		assert_not_null(gsm_instance, "GameStateMachine.gd should instantiate without compile errors"),
	])


func test_raging_bolt_llm_self_play_tool_scripts_load() -> String:
	var tool_script := load("res://scripts/tools/RagingBoltLLMSelfPlayTool.gd")
	var runner_script := load("res://scripts/tools/run_raging_bolt_llm_self_play.gd")
	var tool_instance = tool_script.new() if tool_script != null and tool_script.can_instantiate() else null
	return run_checks([
		assert_not_null(tool_script, "RagingBoltLLMSelfPlayTool.gd should load without compile errors"),
		assert_not_null(runner_script, "run_raging_bolt_llm_self_play.gd should load without compile errors"),
		assert_not_null(tool_instance, "RagingBoltLLMSelfPlayTool.gd should instantiate without compile errors"),
	])
