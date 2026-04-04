## 简单测试运行器
extends Control

const TestSuiteFilterScript = preload("res://scripts/tools/TestSuiteFilter.gd")

const TestEffectInteractionFlow = preload("res://tests/test_effect_interaction_flow.gd")
const TestCardSemanticMatrix = preload("res://tests/test_card_semantic_matrix.gd")
const TestCardCatalogAudit = preload("res://tests/test_card_catalog_audit.gd")
const TestCardDatabaseSeed = preload("res://tests/test_card_database_seed.gd")
const TestSourceEncodingAudit = preload("res://tests/test_source_encoding_audit.gd")
const TestMissingCardBatch202603 = preload("res://tests/test_missing_card_batch_2026_03.gd")
const TestBattleUIFeatures = preload("res://tests/test_battle_ui_features.gd")
const TestBattleUIHandoverRegression = preload("res://tests/test_battle_ui_handover_regression.gd")
const TestBattleSummaryFormatter = preload("res://tests/test_battle_summary_formatter.gd")
const TestBattleRecorder = preload("res://tests/test_battle_recorder.gd")
const TestZenMuxClient = preload("res://tests/test_zenmux_client.gd")
const TestBattleReviewPromptBuilder = preload("res://tests/test_battle_review_prompt_builder.gd")
const TestBattleAdvicePromptBuilder = preload("res://tests/test_battle_advice_prompt_builder.gd")
const TestBattleAIAdviceCopy = preload("res://tests/test_battle_ai_advice_copy.gd")
const TestParserRegressions = preload("res://tests/test_parser_regressions.gd")
const TestBattleReviewTurnExtractor = preload("res://tests/test_battle_review_turn_extractor.gd")
const TestBattleReviewContextBuilder = preload("res://tests/test_battle_review_context_builder.gd")
const TestBattleAdviceContextBuilder = preload("res://tests/test_battle_advice_context_builder.gd")
const TestBattleReviewService = preload("res://tests/test_battle_review_service.gd")
const TestBattleAdviceService = preload("res://tests/test_battle_advice_service.gd")
const TestBattleAdviceSessionStore = preload("res://tests/test_battle_advice_session_store.gd")
const TestGameManager = preload("res://tests/test_game_manager.gd")
const TestAttackSearchAndAttachRegression = preload("res://tests/test_attack_search_and_attach_regression.gd")
const TestGardevoirDeck = preload("res://tests/test_gardevoir_deck.gd")
const TestAIBaseline = preload("res://tests/test_ai_baseline.gd")
const TestAIFeatureExtractor = preload("res://tests/test_ai_feature_extractor.gd")
const TestAIDecisionTrace = preload("res://tests/test_ai_decision_trace.gd")
const TestHeadlessMatchBridge = preload("res://tests/test_headless_match_bridge.gd")
const TestAIBenchmark = preload("res://tests/test_ai_benchmark.gd")
const TestAIPhase2Benchmark = preload("res://tests/test_ai_phase2_benchmark.gd")
const TestAIVersionRegistry = preload("res://tests/test_ai_version_registry.gd")
const TestTrainingRunRegistry = preload("res://tests/test_training_run_registry.gd")
const TestTunerRunnerArgs = preload("res://tests/test_tuner_runner_args.gd")
const TestDeckIdentityTracker = preload("res://tests/test_deck_identity_tracker.gd")
const TestBenchmarkEvaluator = preload("res://tests/test_benchmark_evaluator.gd")
const TestDeckManager = preload("res://tests/test_deck_manager.gd")
const TestAIPhase3Regression = preload("res://tests/test_ai_phase3_regression.gd")
const TestGameStateCloner = preload("res://tests/test_game_state_cloner.gd")
const TestRolloutSimulator = preload("res://tests/test_rollout_simulator.gd")
const TestMCTSPlanner = preload("res://tests/test_mcts_planner.gd")
const TestAgentVersionStore = preload("res://tests/test_agent_version_store.gd")
const TestSelfPlayRunner = preload("res://tests/test_self_play_runner.gd")
const TestEvolutionEngine = preload("res://tests/test_evolution_engine.gd")
const TestTrainingAnomalyArchive = preload("res://tests/test_training_anomaly_archive.gd")
const TestTrainingPipelineModes = preload("res://tests/test_training_pipeline_modes.gd")
const TestStateEncoder = preload("res://tests/test_state_encoder.gd")
const TestNeuralNetInference = preload("res://tests/test_neural_net_inference.gd")
const TestSelfPlayDataExporter = preload("res://tests/test_self_play_data_exporter.gd")
const TestTestRunnerFilter = preload("res://tests/test_test_runner_filter.gd")
const TestMCTSFailureDiagnostics = preload("res://tests/test_mcts_failure_diagnostics.gd")

@onready var result_label: RichTextLabel = %ResultLabel
@onready var summary_label: Label = %SummaryLabel

var _total_tests: int = 0
var _passed_tests: int = 0
var _failed_tests: int = 0
var _output: String = ""
var _selected_suites: Dictionary = {}


func _ready() -> void:
	_selected_suites = TestSuiteFilterScript.parse_suite_filter(OS.get_cmdline_user_args())
	_output = "[b]===== PTCG Train Unit Tests =====[/b]\n\n"
	if not _selected_suites.is_empty():
		_output += "Selected suites: %s\n\n" % ", ".join(_selected_suites.keys())

	_run_test_suite("CardData", TestCardData.new())
	_run_test_suite("DeckData", TestDeckData.new())
	_run_test_suite("CardDatabaseSeed", TestCardDatabaseSeed.new())
	_run_test_suite("CardInstance", TestCardInstance.new())
	_run_test_suite("PokemonSlot", TestPokemonSlot.new())
	_run_test_suite("PlayerState", TestPlayerState.new())
	_run_test_suite("GameState", TestGameState.new())
	_run_test_suite("DeckImporter", TestDeckImporter.new())
	_run_test_suite("CompileCheck", TestCompileCheck.new())
	_run_test_suite("SetupFlow", TestSetupFlow.new())
	_run_test_suite("GameStateMachine", TestGameStateMachine.new())
	_run_test_suite("BattleUIFeatures", TestBattleUIFeatures.new())
	_run_test_suite("BattleSummaryFormatter", TestBattleSummaryFormatter.new())
	_run_test_suite("ParserRegressions", TestParserRegressions.new())
	_run_test_suite("EffectSystem", TestEffectSystem.new())
	_run_test_suite("PersistentEffects", TestPersistentEffects.new())
	_run_test_suite("EffectRegistry", TestEffectRegistry.new())
	_run_test_suite("SpecializedEffects", TestSpecializedEffects.new())
	_run_test_suite("EffectInteractionFlow", TestEffectInteractionFlow.new())
	_run_test_suite("CardSemanticMatrix", TestCardSemanticMatrix.new())
	_run_test_suite("MissingCardBatch202603", TestMissingCardBatch202603.new())
	_run_test_suite("BattleUIHandoverRegression", TestBattleUIHandoverRegression.new())
	_run_test_suite("AttackSearchAndAttachRegression", TestAttackSearchAndAttachRegression.new())
	_run_test_suite("GardevoirDeck", TestGardevoirDeck.new())
	_run_test_suite("AIBaseline", TestAIBaseline.new())
	_run_test_suite("AIFeatureExtractor", TestAIFeatureExtractor.new())
	_run_test_suite("AIDecisionTrace", TestAIDecisionTrace.new())
	_run_test_suite("HeadlessMatchBridge", TestHeadlessMatchBridge.new())
	_run_test_suite("AIBenchmark", TestAIBenchmark.new())
	_run_test_suite("AIPhase2Benchmark", TestAIPhase2Benchmark.new())
	_run_test_suite("AIVersionRegistry", TestAIVersionRegistry.new())
	_run_test_suite("TrainingRunRegistry", TestTrainingRunRegistry.new())
	_run_test_suite("TunerRunnerArgs", TestTunerRunnerArgs.new())
	_run_test_suite("DeckIdentityTracker", TestDeckIdentityTracker.new())
	_run_test_suite("BenchmarkEvaluator", TestBenchmarkEvaluator.new())
	_run_test_suite("DeckManager", TestDeckManager.new())
	_run_test_suite("AIPhase3Regression", TestAIPhase3Regression.new())
	_run_test_suite("GameStateCloner", TestGameStateCloner.new())
	_run_test_suite("RolloutSimulator", TestRolloutSimulator.new())
	_run_test_suite("MCTSPlanner", TestMCTSPlanner.new())
	_run_test_suite("AgentVersionStore", TestAgentVersionStore.new())
	_run_test_suite("SelfPlayRunner", TestSelfPlayRunner.new())
	_run_test_suite("EvolutionEngine", TestEvolutionEngine.new())
	_run_test_suite("TrainingAnomalyArchive", TestTrainingAnomalyArchive.new())
	_run_test_suite("TrainingPipelineModes", TestTrainingPipelineModes.new())
	_run_test_suite("StateEncoder", TestStateEncoder.new())
	_run_test_suite("NeuralNetInference", TestNeuralNetInference.new())
	_run_test_suite("SelfPlayDataExporter", TestSelfPlayDataExporter.new())
	_run_test_suite("TestRunnerFilter", TestTestRunnerFilter.new())
	_run_test_suite("MCTSFailureDiagnostics", TestMCTSFailureDiagnostics.new())
	_run_test_suite("BattleRecorder", TestBattleRecorder.new())
	_run_test_suite("ZenMuxClient", TestZenMuxClient.new())
	_run_test_suite("BattleReviewPromptBuilder", TestBattleReviewPromptBuilder.new())
	_run_test_suite("BattleAdvicePromptBuilder", TestBattleAdvicePromptBuilder.new())
	_run_test_suite("BattleAIAdviceCopy", TestBattleAIAdviceCopy.new())
	_run_test_suite("BattleReviewTurnExtractor", TestBattleReviewTurnExtractor.new())
	_run_test_suite("BattleReviewContextBuilder", TestBattleReviewContextBuilder.new())
	_run_test_suite("BattleAdviceContextBuilder", TestBattleAdviceContextBuilder.new())
	_run_test_suite("BattleReviewService", TestBattleReviewService.new())
	_run_test_suite("BattleAdviceService", TestBattleAdviceService.new())
	_run_test_suite("BattleAdviceSessionStore", TestBattleAdviceSessionStore.new())
	_run_test_suite("GameManager", TestGameManager.new())
	_run_test_suite("CardCatalogAudit", TestCardCatalogAudit.new())
	_run_test_suite("SourceEncodingAudit", TestSourceEncodingAudit.new())

	_output += "\n[b]===== Summary =====[/b]\n"
	_output += "Total: %d | Passed: [color=green]%d[/color] | Failed: [color=red]%d[/color]\n" % [
		_total_tests, _passed_tests, _failed_tests
	]

	if _failed_tests == 0:
		_output += "\n[color=green][b]All tests passed[/b][/color]"
		summary_label.text = "All %d tests passed" % _total_tests
		summary_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		_output += "\n[color=red][b]%d tests failed[/b][/color]" % _failed_tests
		summary_label.text = "%d/%d tests failed" % [_failed_tests, _total_tests]
		summary_label.add_theme_color_override("font_color", Color.RED)

	result_label.text = _output

	print("\n===== PTCG Train Unit Tests =====")
	print("Total: %d | Passed: %d | Failed: %d" % [_total_tests, _passed_tests, _failed_tests])
	if _failed_tests > 0:
		print("!!! %d tests failed !!!" % _failed_tests)
	else:
		print("All tests passed!")

	if DisplayServer.get_name() == "headless":
		call_deferred("_quit_after_run")


func _run_test_suite(suite_name: String, test_obj: RefCounted) -> void:
	if not TestSuiteFilterScript.should_run_suite(_selected_suites, suite_name):
		return
	_output += "[b]--- %s ---[/b]\n" % suite_name

	var methods: Array[Dictionary] = test_obj.get_method_list()
	for method: Dictionary in methods:
		var method_name: String = method["name"]
		if not method_name.begins_with("test_"):
			continue

		_total_tests += 1
		var error_message := ""
		var result: Variant = test_obj.call(method_name)
		if result is String and result != "":
			error_message = result

		if error_message == "":
			_passed_tests += 1
			_output += "  [color=green]PASS[/color] %s\n" % method_name
		else:
			_failed_tests += 1
			_output += "  [color=red]FAIL %s: %s[/color]\n" % [method_name, error_message]
			print("FAIL: %s.%s: %s" % [suite_name, method_name, error_message])

	_output += "\n"


func _quit_after_run() -> void:
	get_tree().quit(0 if _failed_tests == 0 else 1)
