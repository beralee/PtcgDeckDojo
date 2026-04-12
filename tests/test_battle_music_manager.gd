class_name TestBattleMusicManager
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


func _clear_directory(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	var dir := DirAccess.open(absolute_path)
	if dir == null:
		DirAccess.make_dir_recursive_absolute(absolute_path)
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if dir.current_is_dir():
			continue
		DirAccess.remove_absolute("%s/%s" % [absolute_path.trim_suffix("/"), name])
	dir.list_dir_end()


func test_available_battle_tracks_include_none_and_custom_files() -> String:
	var temp_dir := "user://test_custom_bgm_tracks"
	_clear_directory(temp_dir)
	var file := FileAccess.open("%s/sample.ogg" % temp_dir, FileAccess.WRITE)
	if file != null:
		file.store_buffer(PackedByteArray([0]))
		file.close()

	var manager := _make_manager()
	manager.call("set_custom_music_dir_override_for_test", temp_dir)
	var tracks: Array = manager.call("get_available_battle_tracks")
	_cleanup_manager(manager)
	_clear_directory(temp_dir)

	return run_checks([
		assert_eq(str(tracks[0].get("id", "")), "none", "第一项应始终是无音乐"),
		assert_true(tracks.any(func(track: Dictionary) -> bool: return str(track.get("id", "")) == "custom:sample.ogg"), "应扫描到自定义音频文件"),
	])


func test_sanitize_track_id_falls_back_to_none_for_missing_tracks() -> String:
	var manager := _make_manager()
	var sanitized := str(manager.call("sanitize_track_id", "missing-track"))
	_cleanup_manager(manager)

	return run_checks([
		assert_eq(sanitized, "none", "不存在的曲目应回退到无音乐"),
	])


func test_builtin_catalog_exposes_registered_tracks() -> String:
	var manager := _make_manager()
	var tracks: Array = manager.call("get_available_battle_tracks")
	_cleanup_manager(manager)

	return run_checks([
		assert_true(tracks.any(func(track: Dictionary) -> bool: return str(track.get("id", "")) == "pokemon_sv_battle_zeiyu"), "内置曲目注册表应暴露已登记的基础音乐"),
	])


func test_builtin_res_tracks_load_from_packed_resource_path() -> String:
	var manager := _make_manager()
	var stream: Variant = manager.call("_load_stream_from_path", "res://assets/audio/bgm/pokemon_sv_battle_zeiyu.mp3")
	_cleanup_manager(manager)

	return run_checks([
		assert_true(stream is AudioStream, "鍐呯疆瀵规垬 BGM 搴斿彲鐩存帴浠?res:// 鎵撳寘璧勬簮鍔犺浇"),
	])


func test_builtin_tracks_are_mirrored_to_user_music_directory() -> String:
	var temp_dir := "user://test_builtin_bgm_mirror"
	_clear_directory(temp_dir)
	var manager := _make_manager()
	manager.call("set_builtin_music_mirror_dir_override_for_test", temp_dir)
	manager.call("ensure_builtin_music_mirror")
	var mirror_absolute := ProjectSettings.globalize_path(temp_dir)
	var mirrored_zeiyu := FileAccess.file_exists("%s/pokemon_sv_battle_zeiyu.mp3" % mirror_absolute)
	var mirrored_gym := FileAccess.file_exists("%s/pokemon_sv_battle_gym_leader.mp3" % mirror_absolute)
	var mirrored_star := FileAccess.file_exists("%s/pokemon_sv_battle_star_barrage.mp3" % mirror_absolute)
	_cleanup_manager(manager)
	_clear_directory(temp_dir)

	return run_checks([
		assert_true(mirrored_zeiyu, "鍐呯疆 BGM 搴斿湪棣栨鍚姩鏃堕暅鍍忓埌鐜╁鐩綍"),
		assert_true(mirrored_gym, "閬嗛鎴樻洸搴斿悓姝ュ埌鐜╁鐩綍"),
		assert_true(mirrored_star, "澶╂槦闃熸洸搴斿悓姝ュ埌鐜╁鐩綍"),
	])


func test_volume_percent_maps_to_audio_player_db() -> String:
	var manager := _make_manager()
	manager.call("set_battle_music_volume_percent", 100)
	var audio_player := manager.get_node("BattleMusicPlayer") as AudioStreamPlayer
	var full_volume := float(audio_player.volume_db)
	manager.call("set_battle_music_volume_percent", 0)
	var muted_volume := float(audio_player.volume_db)
	_cleanup_manager(manager)

	return run_checks([
		assert_true(full_volume > -0.2 and full_volume < 0.2, "100% 音量应接近 0 dB"),
		assert_true(muted_volume <= -79.0, "0% 音量应接近静音"),
	])
