extends SceneTree

func _init() -> void:
	var script: GDScript = load("res://scenes/battle/BattleScene.gd")
	if script == null:
		push_error("script_load_failed")
		quit(1)
		return
	print("battle_script_loaded")
	quit(0)
