class_name TestCardCatalogAudit
extends TestBase

const CardCatalogAuditRunner = preload("res://tests/CardCatalogAudit.gd")

var _cached_report: Dictionary = {}


func test_cached_cards_have_registry_and_smoke_coverage() -> String:
	if _cached_report.is_empty():
		_cached_report = CardCatalogAuditRunner.new().run()
		print(_cached_report.get("report_text", ""))

	var registry_failures: Array = _cached_report.get("registry_failures", [])
	var smoke_failures: Array = _cached_report.get("smoke_failures", [])
	var status_matrix_text: String = str(_cached_report.get("status_matrix_text", ""))
	var failure_parts: Array[String] = []

	if not registry_failures.is_empty():
		failure_parts.append("registry=%d" % registry_failures.size())
	if not smoke_failures.is_empty():
		failure_parts.append("smoke=%d" % smoke_failures.size())

	return run_checks([
		assert_gt(int(_cached_report.get("cached_cards", 0)), 0, "Should discover cached cards"),
		assert_true(status_matrix_text.contains("Card Status Matrix"), "Should generate status matrix report"),
		assert_true(failure_parts.is_empty(), "Card catalog audit failed: %s" % ", ".join(failure_parts)),
	])
