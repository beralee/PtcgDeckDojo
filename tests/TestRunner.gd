## 简单测试运行器
extends Control

const TestEffectInteractionFlow = preload("res://tests/test_effect_interaction_flow.gd")
const TestCardSemanticMatrix = preload("res://tests/test_card_semantic_matrix.gd")
const TestCardCatalogAudit = preload("res://tests/test_card_catalog_audit.gd")
const TestCardDatabaseSeed = preload("res://tests/test_card_database_seed.gd")
const TestSourceEncodingAudit = preload("res://tests/test_source_encoding_audit.gd")
const TestMissingCardBatch202603 = preload("res://tests/test_missing_card_batch_2026_03.gd")
const TestBattleUIHandoverRegression = preload("res://tests/test_battle_ui_handover_regression.gd")
const TestAttackSearchAndAttachRegression = preload("res://tests/test_attack_search_and_attach_regression.gd")
const TestGardevoirDeck = preload("res://tests/test_gardevoir_deck.gd")
const TestAIBaseline = preload("res://tests/test_ai_baseline.gd")
const TestAIFeatureExtractor = preload("res://tests/test_ai_feature_extractor.gd")
const TestAIDecisionTrace = preload("res://tests/test_ai_decision_trace.gd")
const TestHeadlessMatchBridge = preload("res://tests/test_headless_match_bridge.gd")
const TestAIBenchmark = preload("res://tests/test_ai_benchmark.gd")
const TestAIPhase2Benchmark = preload("res://tests/test_ai_phase2_benchmark.gd")
const TestDeckIdentityTracker = preload("res://tests/test_deck_identity_tracker.gd")
const TestBenchmarkEvaluator = preload("res://tests/test_benchmark_evaluator.gd")
const TestDeckManager = preload("res://tests/test_deck_manager.gd")
const TestAIPhase3Regression = preload("res://tests/test_ai_phase3_regression.gd")

@onready var result_label: RichTextLabel = %ResultLabel
@onready var summary_label: Label = %SummaryLabel

var _total_tests: int = 0
var _passed_tests: int = 0
var _failed_tests: int = 0
var _output: String = ""


func _ready() -> void:
	_output = "[b]===== PTCG Train Unit Tests =====[/b]\n\n"

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
	_run_test_suite("DeckIdentityTracker", TestDeckIdentityTracker.new())
	_run_test_suite("BenchmarkEvaluator", TestBenchmarkEvaluator.new())
	_run_test_suite("DeckManager", TestDeckManager.new())
	_run_test_suite("AIPhase3Regression", TestAIPhase3Regression.new())
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
