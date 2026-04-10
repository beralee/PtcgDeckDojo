class_name BattleDrawRevealController
extends RefCounted


func enqueue_reveal(scene: Object, action: GameAction) -> void:
	if scene == null or action == null:
		return
	var queue: Array = scene.get("_draw_reveal_queue")
	queue.append(action)
	scene.set("_draw_reveal_queue", queue)
	scene.set("_draw_reveal_active", true)
	scene.set("_draw_reveal_pending_hand_refresh", true)
	scene.set("_draw_reveal_waiting_for_confirm", false)
	var overlay: Control = scene.get("_draw_reveal_overlay")
	if overlay == null:
		overlay = _build_overlay()
		scene.set("_draw_reveal_overlay", overlay)
		if overlay.get_parent() == null and scene is Node:
			(scene as Node).add_child(overlay)
	if overlay != null:
		overlay.visible = true


func is_active(scene: Object) -> bool:
	return bool(scene.get("_draw_reveal_active"))


func _build_overlay() -> Control:
	var overlay := Control.new()
	overlay.name = "DrawRevealOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 120

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	return overlay
