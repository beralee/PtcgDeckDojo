class_name TestSuiteFilter
extends RefCounted


static func parse_suite_filter(args: PackedStringArray) -> Dictionary:
	var selected: Dictionary = {}
	for raw_arg: String in args:
		if not raw_arg.begins_with("--suite="):
			continue
		var raw_value := raw_arg.split("=", false, 1)[1]
		for suite_name: String in raw_value.split(",", false):
			var normalized := normalize_suite_name(suite_name)
			if normalized == "":
				continue
			selected[normalized] = true
	return selected


static func should_run_suite(selected: Dictionary, suite_name: String) -> bool:
	if selected.is_empty():
		return true
	return bool(selected.get(normalize_suite_name(suite_name), false))


static func normalize_suite_name(suite_name: String) -> String:
	return suite_name.strip_edges().to_lower()
