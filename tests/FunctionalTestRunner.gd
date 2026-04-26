extends SceneTree

const TestSuiteCatalogScript = preload("res://tests/TestSuiteCatalog.gd")
const SharedSuiteRunnerScript = preload("res://tests/SharedSuiteRunner.gd")
const TestSuiteFilterScript = preload("res://scripts/tools/TestSuiteFilter.gd")


func _initialize() -> void:
	var selected_suites := TestSuiteFilterScript.parse_suite_filter(OS.get_cmdline_user_args())
	var suites := TestSuiteCatalogScript.get_suites_for_group(TestSuiteCatalogScript.GROUP_FUNCTIONAL)
	var report := await SharedSuiteRunnerScript.run_suites(suites, selected_suites, "PTCG Train Functional Tests")
	print(report.get("output", ""))
	quit(1 if int(report.get("failed", 0)) > 0 else 0)
