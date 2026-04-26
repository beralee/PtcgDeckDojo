extends Control

const SharedSuiteRunnerScript = preload("res://tests/SharedSuiteRunner.gd")
const TestSuiteCatalogScript = preload("res://tests/TestSuiteCatalog.gd")
const TestQuitHelperScript = preload("res://tests/TestQuitHelper.gd")
const TestSuiteFilterScript = preload("res://scripts/tools/TestSuiteFilter.gd")

@onready var result_label: RichTextLabel = %ResultLabel
@onready var summary_label: Label = %SummaryLabel

var _failed_tests: int = 0


func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var args := OS.get_cmdline_user_args()
	var selected_suites := TestSuiteFilterScript.parse_suite_filter(args)
	var selected_groups := TestSuiteFilterScript.parse_group_filter(args)
	var suites := TestSuiteCatalogScript.get_suites(selected_groups)
	var report := await SharedSuiteRunnerScript.run_suites(suites, selected_suites, "PTCG Train Unit Tests")

	_failed_tests = int(report.get("failed", 0))
	result_label.text = str(report.get("output", ""))

	if _failed_tests == 0:
		summary_label.text = "All %d tests passed" % int(report.get("total", 0))
		summary_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		summary_label.text = "%d/%d tests failed" % [_failed_tests, int(report.get("total", 0))]
		summary_label.add_theme_color_override("font_color", Color.RED)

	print(str(report.get("output", "")))

	if DisplayServer.get_name() == "headless":
		call_deferred("_schedule_headless_quit")


func _schedule_headless_quit() -> void:
	var helper := TestQuitHelperScript.new()
	helper.exit_code = 0 if _failed_tests == 0 else 1
	get_tree().root.add_child(helper)
	if get_tree().current_scene == self:
		get_tree().current_scene = null
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()
