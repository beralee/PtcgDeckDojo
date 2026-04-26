class_name TestScenarioRunnerSmoke
extends TestBase


const ScenarioCatalogScript = preload("res://tests/scenarios/ScenarioCatalog.gd")
const ScenarioRunnerScript = preload("res://tests/scenarios/ScenarioRunner.gd")
const GameActionScript = preload("res://scripts/engine/GameAction.gd")

const FIXTURE_DIR := "res://tests/scenarios/fixtures"
const MISSING_DEPENDENCIES_FIXTURE := "res://tests/scenarios/fixtures/minimal_missing_dependencies.json"
const IGNORED_REVIEW_FIXTURE := "res://tests/scenarios/fixtures/review_queue/pending/ignored_review_seed.json"


func test_scenario_catalog_lists_fixture_json_files() -> String:
	var files: Array[String] = ScenarioCatalogScript.list_scenario_files(FIXTURE_DIR)
	return run_checks([
		assert_true(not files.is_empty(), "Scenario catalog should discover fixture json files"),
		assert_contains(files, MISSING_DEPENDENCIES_FIXTURE, "Scenario catalog should include the smoke fixture"),
		assert_false(files.has(IGNORED_REVIEW_FIXTURE), "Scenario catalog should skip review queue bookkeeping json files"),
	])


func test_scenario_catalog_loads_fixture_dictionary() -> String:
	var scenario: Dictionary = ScenarioCatalogScript.load_scenario(MISSING_DEPENDENCIES_FIXTURE)
	return run_checks([
		assert_eq(str(scenario.get("scenario_id", "")), "smoke_missing_dependencies", "Scenario catalog should decode the fixture scenario id"),
		assert_eq(int(scenario.get("deck_id", -1)), 569061, "Scenario catalog should decode deck_id from json"),
		assert_eq(str(scenario.get("_path", "")), MISSING_DEPENDENCIES_FIXTURE, "Scenario catalog should attach the loaded path for diagnostics"),
	])


func test_scenario_runner_can_execute_minimal_fixture_end_to_end() -> String:
	var runner = ScenarioRunnerScript.new()
	var result: Dictionary = runner.run_scenario(MISSING_DEPENDENCIES_FIXTURE)
	return run_checks([
		assert_eq(str(result.get("status", "")), "PASS", "Scenario runner should execute the minimal fixture once runner dependencies are wired"),
		assert_eq(int((result.get("runtime_result", {}) as Dictionary).get("steps", -1)), 1, "Minimal fixture should consume exactly one end_turn step"),
	])


func test_scenario_runner_rejects_malformed_loaded_scenario() -> String:
	var runner = ScenarioRunnerScript.new()
	var result: Dictionary = runner.run_loaded_scenario({
		"scenario_id": "",
		"state_at_turn_start": {},
		"expected_end_state": {},
		"approved_divergent_end_states": [],
	})
	var errors: Array = result.get("errors", [])
	return run_checks([
		assert_eq(str(result.get("status", "")), "ERROR", "Malformed scenarios should still fail with a structured error payload"),
		assert_true(not errors.is_empty(), "Malformed scenario errors should not be empty"),
	])


func test_scenario_runner_rewinds_next_turn_draw_for_end_state_comparison() -> String:
	var runner = ScenarioRunnerScript.new()
	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in range(2):
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	gsm.game_state = state
	var existing := _make_trainer_card("Existing", 1, "Item")
	var drawn := _make_trainer_card("Drawn", 1, "Item")
	state.players[1].hand = [existing, drawn]
	gsm.action_log.append(GameActionScript.create(
		GameAction.ActionType.DRAW_CARD,
		1,
		{"count": 1, "card_names": ["Drawn"]},
		2,
		"draw"
	))
	var comparison_state: GameState = runner._build_comparison_game_state(gsm, 0, {"start_turn": 1, "turn_number": 2, "current_player_index": 1})
	return run_checks([
		assert_not_null(comparison_state, "Comparison state should be rebuilt"),
		assert_eq(comparison_state.players[1].hand.size(), 1, "Comparison state should remove the opponent's next-turn draw before comparing end state"),
		assert_eq(str(comparison_state.players[1].hand[0].card_data.name), "Existing", "Only the pre-draw hand should remain after rewind"),
		assert_eq(state.players[1].hand.size(), 2, "Rewinding should not mutate the live runtime state"),
	])


func _make_trainer_card(card_name: String, owner_index: int, card_type: String) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = card_name
	card_data.card_type = card_type
	return CardInstance.create(card_data, owner_index)
