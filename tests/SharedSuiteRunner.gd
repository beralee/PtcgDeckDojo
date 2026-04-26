class_name SharedSuiteRunner
extends RefCounted

const TestSuiteFilterScript = preload("res://scripts/tools/TestSuiteFilter.gd")


static func run_suites(
	suites: Array[Dictionary],
	selected_suites: Dictionary = {},
	title: String = "PTCG Train Unit Tests"
) -> Dictionary:
	var total := 0
	var passed := 0
	var failed := 0
	var lines: Array[String] = ["===== %s =====" % title, ""]

	if not selected_suites.is_empty():
		lines.append("Selected suites: %s" % ", ".join(selected_suites.keys()))
		lines.append("")

	for suite: Dictionary in suites:
		var suite_name := str(suite.get("name", ""))
		if not TestSuiteFilterScript.should_run_suite(selected_suites, suite_name):
			continue

		lines.append("--- %s ---" % suite_name)
		var suite_script: GDScript = ResourceLoader.load(
			str(suite.get("path", "")),
			"GDScript",
			ResourceLoader.CACHE_MODE_IGNORE_DEEP
		)
		if suite_script == null:
			total += 1
			failed += 1
			lines.append("FAIL _suite_load :: Unable to load suite script")
			lines.append("")
			continue

		var test_obj = suite_script.new()
		if test_obj == null:
			total += 1
			failed += 1
			lines.append("FAIL _suite_init :: Unable to instantiate suite")
			lines.append("")
			continue

		var methods: Array[Dictionary] = test_obj.get_method_list()
		for method: Dictionary in methods:
			var method_name := str(method.get("name", ""))
			if not method_name.begins_with("test_"):
				continue

			total += 1
			var root_snapshot := _capture_root_children()
			var orphan_snapshot := _capture_orphan_nodes()
			var result: Variant = test_obj.call(method_name)
			var message := str(result)
			if message == "":
				passed += 1
				lines.append("PASS %s" % method_name)
			else:
				failed += 1
				lines.append("FAIL %s :: %s" % [method_name, message])
				print("FAIL: %s.%s: %s" % [suite_name, method_name, message])

			await _cleanup_root_children(root_snapshot)
			_cleanup_orphan_nodes(orphan_snapshot)
			var tree := Engine.get_main_loop() as SceneTree
			if tree != null:
				await tree.process_frame
				await tree.process_frame

		lines.append("")
		test_obj = null
		suite_script = null
		var suite_tree := Engine.get_main_loop() as SceneTree
		if suite_tree != null:
			await suite_tree.process_frame
			await suite_tree.process_frame

	lines.append("===== Summary =====")
	lines.append("Total: %d | Passed: %d | Failed: %d" % [total, passed, failed])
	if failed == 0:
		lines.append("All tests passed!")
	else:
		lines.append("%d tests failed!" % failed)

	return {
		"total": total,
		"passed": passed,
		"failed": failed,
		"output": "\n".join(lines),
	}


static func _capture_root_children() -> Dictionary:
	var snapshot := {}
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return snapshot
	for child: Node in tree.root.get_children():
		snapshot[child.get_instance_id()] = true
	return snapshot


static func _cleanup_root_children(before_snapshot: Dictionary) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	for child: Node in tree.root.get_children():
		if before_snapshot.has(child.get_instance_id()):
			continue
		child.queue_free()


static func _capture_orphan_nodes() -> Dictionary:
	var snapshot := {}
	for orphan_id: int in Node.get_orphan_node_ids():
		snapshot[orphan_id] = true
	return snapshot


static func _cleanup_orphan_nodes(before_snapshot: Dictionary) -> void:
	for orphan_id: int in Node.get_orphan_node_ids():
		if before_snapshot.has(orphan_id):
			continue
		var obj := instance_from_id(orphan_id)
		if obj is Node:
			(obj as Node).free()
