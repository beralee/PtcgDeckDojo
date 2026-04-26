class_name TestScenarioRunnerE2E
extends TestBase


const ScenarioRunnerScript = preload("res://tests/scenarios/ScenarioRunner.gd")
const FIXTURE := "res://tests/scenarios/fixtures/e2e_valid_scenario.json"


func test_e2e_fixture_runs_cleanly_with_derived_expected_end_state() -> String:
	var runner = ScenarioRunnerScript.new()
	var result: Dictionary = runner.run_scenario(FIXTURE)
	return run_checks([
		assert_eq(str(result.get("status", "")), "PASS", "E2E fixture should pass once expected end state can be derived from the human end snapshot"),
		assert_eq(int((result.get("runtime_result", {}) as Dictionary).get("steps", -1)), 1, "Minimal E2E fixture should resolve as a single end_turn decision"),
	])
