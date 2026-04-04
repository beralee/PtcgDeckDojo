extends SceneTree

func _init() -> void:
	var suite_script: GDScript = load("res://tests/test_battle_ui_features.gd")
	if suite_script == null:
		push_error("suite_load_failed")
		quit(1)
		return
	print("suite_loaded")
	var suite: Variant = suite_script.new()
	if suite == null:
		push_error("suite_new_failed")
		quit(2)
		return
	print("suite_instantiated")
	quit(0)
