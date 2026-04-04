extends SceneTree


func _initialize() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var suite_script_path: String = str(args.get("suite-script", ""))
	if suite_script_path == "":
		print("Missing --suite-script")
		quit(2)
		return

	var suite_script: GDScript = load(suite_script_path)
	if suite_script == null:
		print("Unable to load suite script: %s" % suite_script_path)
		quit(2)
		return

	var suite = suite_script.new()
	if suite == null:
		print("Unable to instantiate suite: %s" % suite_script_path)
		quit(2)
		return

	var methods: Array[Dictionary] = suite.get_method_list()
	var total: int = 0
	var failed: int = 0

	for method: Dictionary in methods:
		var method_name: String = str(method.get("name", ""))
		if not method_name.begins_with("test_"):
			continue
		total += 1
		var result: Variant = suite.call(method_name)
		var message: String = str(result)
		if message == "":
			print("PASS %s" % method_name)
		else:
			failed += 1
			print("FAIL %s :: %s" % [method_name, message])

	print("Total: %d | Failed: %d" % [total, failed])
	quit(1 if failed > 0 else 0)


func _parse_args(raw_args: PackedStringArray) -> Dictionary:
	var parsed := {}
	for raw_arg: String in raw_args:
		if not raw_arg.begins_with("--"):
			continue
		var eq_index: int = raw_arg.find("=")
		if eq_index <= 2:
			continue
		var key: String = raw_arg.substr(2, eq_index - 2)
		var value: String = raw_arg.substr(eq_index + 1)
		parsed[key] = value
	return parsed
