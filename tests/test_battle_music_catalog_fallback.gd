class_name TestBattleMusicCatalogFallback
extends TestBase

const BattleMusicManagerScript := preload("res://scripts/autoload/BattleMusicManager.gd")


func _make_manager() -> Node:
	var manager: Node = BattleMusicManagerScript.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(manager)
	manager.call("_ready")
	return manager


func _cleanup_manager(manager: Node) -> void:
	if manager != null and is_instance_valid(manager):
		manager.queue_free()


func test_fallback_builtin_tracks_keep_catalog_choices_available() -> String:
	var manager := _make_manager()
	var tracks: Array = manager.call("_fallback_builtin_tracks")
	_cleanup_manager(manager)

	return run_checks([
		assert_true(tracks.size() >= 3, "Fallback builtin catalog should expose bundled battle tracks"),
		assert_true(tracks.any(func(track: Dictionary) -> bool: return str(track.get("id", "")) == "pokemon_sv_battle_zeiyu"), "Fallback builtin catalog should include zeiyu track"),
		assert_true(tracks.any(func(track: Dictionary) -> bool: return str(track.get("id", "")) == "pokemon_sv_battle_gym_leader"), "Fallback builtin catalog should include gym leader track"),
		assert_true(tracks.any(func(track: Dictionary) -> bool: return str(track.get("id", "")) == "pokemon_sv_battle_star_barrage"), "Fallback builtin catalog should include star barrage track"),
	])
