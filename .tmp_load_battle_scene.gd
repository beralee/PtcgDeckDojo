extends SceneTree

func _init() -> void:
	var packed: PackedScene = load("res://scenes/battle/BattleScene.tscn")
	if packed == null:
		push_error("load_failed")
		quit(1)
		return
	var inst: Node = packed.instantiate()
	if inst == null:
		push_error("instantiate_failed")
		quit(2)
		return
	print("battle_scene_loaded")
	inst.queue_free()
	quit(0)
