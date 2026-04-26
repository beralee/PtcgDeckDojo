extends Node

const BUILTIN_CATALOG_PATH := "res://data/battle_music_catalog.json"
const CUSTOM_BGM_DIR := "user://custom_bgm"
const BUILTIN_MIRROR_DIR := "user://music/battle_bgm"
const TRACK_ID_NONE := "none"
const SUPPORTED_EXTENSIONS := ["ogg", "mp3", "wav"]
const MIN_VOLUME_DB := -80.0
const BUILTIN_TRACKS_FALLBACK: Array[Dictionary] = [
	{
		"id": "pokemon_sv_battle_zeiyu",
		"label": "宝可梦 朱紫：战斗！妮莫",
		"path": "res://assets/audio/bgm/pokemon_sv_battle_zeiyu.mp3",
		"source": "builtin",
	},
	{
		"id": "pokemon_sv_battle_gym_leader",
		"label": "宝可梦 朱紫：战斗！道馆馆主",
		"path": "res://assets/audio/bgm/pokemon_sv_battle_gym_leader.mp3",
		"source": "builtin",
	},
	{
		"id": "pokemon_sv_battle_star_barrage",
		"label": "宝可梦 朱紫：战斗！天星队",
		"path": "res://assets/audio/bgm/pokemon_sv_battle_star_barrage.mp3",
		"source": "builtin",
	},
]

var _audio_player: AudioStreamPlayer = null
var _builtin_tracks_override: Array[Dictionary] = []
var _custom_dir_override: String = ""
var _builtin_mirror_dir_override: String = ""
var _current_track_id: String = TRACK_ID_NONE


func _ready() -> void:
	_ensure_audio_player()
	ensure_custom_music_dir()
	ensure_builtin_music_mirror()


func ensure_custom_music_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(get_custom_music_dir_path()))


func ensure_builtin_music_mirror() -> void:
	var mirror_dir := get_builtin_music_mirror_absolute_dir_path()
	DirAccess.make_dir_recursive_absolute(mirror_dir)
	for track: Dictionary in _load_builtin_tracks():
		var source_path := str(track.get("path", ""))
		if not source_path.begins_with("res://"):
			continue
		var source_file := FileAccess.open(source_path, FileAccess.READ)
		if source_file == null:
			continue
		var target_path := mirror_dir.path_join(source_path.get_file())
		if FileAccess.file_exists(target_path):
			source_file.close()
			continue
		var target_file := FileAccess.open(target_path, FileAccess.WRITE)
		if target_file == null:
			source_file.close()
			continue
		target_file.store_buffer(source_file.get_buffer(source_file.get_length()))
		target_file.close()
		source_file.close()


func get_custom_music_dir_path() -> String:
	return _custom_dir_override if _custom_dir_override != "" else CUSTOM_BGM_DIR


func get_custom_music_absolute_dir_path() -> String:
	return ProjectSettings.globalize_path(get_custom_music_dir_path())


func get_builtin_music_mirror_dir_path() -> String:
	return _builtin_mirror_dir_override if _builtin_mirror_dir_override != "" else BUILTIN_MIRROR_DIR


func get_builtin_music_mirror_absolute_dir_path() -> String:
	return ProjectSettings.globalize_path(get_builtin_music_mirror_dir_path())


func set_builtin_tracks_override_for_test(tracks: Array[Dictionary]) -> void:
	_builtin_tracks_override = tracks.duplicate(true)


func set_custom_music_dir_override_for_test(path: String) -> void:
	_custom_dir_override = path


func set_builtin_music_mirror_dir_override_for_test(path: String) -> void:
	_builtin_mirror_dir_override = path


func clear_test_overrides() -> void:
	_builtin_tracks_override.clear()
	_custom_dir_override = ""
	_builtin_mirror_dir_override = ""


func get_available_battle_tracks() -> Array[Dictionary]:
	var tracks: Array[Dictionary] = [{
		"id": TRACK_ID_NONE,
		"label": "无音乐",
		"path": "",
		"source": "system",
	}]

	for built_in_track: Dictionary in _load_builtin_tracks():
		if _is_valid_track_entry(built_in_track):
			tracks.append(built_in_track)

	for custom_track: Dictionary in _scan_custom_tracks():
		if _is_valid_track_entry(custom_track):
			tracks.append(custom_track)

	return tracks


func get_track_by_id(track_id: String) -> Dictionary:
	for track: Dictionary in get_available_battle_tracks():
		if str(track.get("id", "")) == track_id:
			return track.duplicate(true)
	return {}


func is_battle_music_playing() -> bool:
	return _audio_player != null and _audio_player.stream != null and _current_track_id != TRACK_ID_NONE


func get_current_track_id() -> String:
	return _current_track_id


func sanitize_track_id(track_id: String) -> String:
	if track_id == "":
		return TRACK_ID_NONE
	return track_id if not get_track_by_id(track_id).is_empty() else TRACK_ID_NONE


func play_battle_music(track_id: String) -> bool:
	_ensure_audio_player()
	var safe_track_id := sanitize_track_id(track_id)
	if safe_track_id == TRACK_ID_NONE:
		stop_battle_music()
		return true

	var track := get_track_by_id(safe_track_id)
	if track.is_empty():
		stop_battle_music()
		return false

	var stream := _load_stream_from_path(str(track.get("path", "")))
	if stream == null:
		stop_battle_music()
		return false

	_audio_player.stop()
	_audio_player.stream = stream
	if stream.has_method("set_loop"):
		stream.call("set_loop", true)
	_current_track_id = safe_track_id
	if _audio_player.is_inside_tree():
		_audio_player.play()
	return true


func set_battle_music_volume_percent(percent: int) -> void:
	_ensure_audio_player()
	_audio_player.volume_db = _volume_db_from_percent(percent)


func stop_battle_music() -> void:
	if _audio_player == null:
		return
	_audio_player.stop()
	_audio_player.stream = null
	_current_track_id = TRACK_ID_NONE


func _ensure_audio_player() -> void:
	if _audio_player != null and is_instance_valid(_audio_player):
		return
	var existing := get_node_or_null("BattleMusicPlayer") as AudioStreamPlayer
	if existing != null:
		_audio_player = existing
		return
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "BattleMusicPlayer"
	_audio_player.bus = "Master"
	_audio_player.autoplay = false
	_audio_player.stream_paused = false
	add_child(_audio_player)


func _load_builtin_tracks() -> Array[Dictionary]:
	if not _builtin_tracks_override.is_empty():
		return _builtin_tracks_override.duplicate(true)

	if not FileAccess.file_exists(BUILTIN_CATALOG_PATH):
		return _fallback_builtin_tracks()
	var file := FileAccess.open(BUILTIN_CATALOG_PATH, FileAccess.READ)
	if file == null:
		return _fallback_builtin_tracks()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	var normalized: Array[Dictionary] = []
	if typeof(parsed) == TYPE_ARRAY:
		normalized = _normalize_track_entries(parsed as Array)
	elif typeof(parsed) == TYPE_DICTIONARY:
		normalized = _normalize_track_entries((parsed as Dictionary).get("tracks", []))
	if normalized.is_empty():
		return _fallback_builtin_tracks()
	return normalized


func _fallback_builtin_tracks() -> Array[Dictionary]:
	return _normalize_track_entries(BUILTIN_TRACKS_FALLBACK)


func _normalize_track_entries(raw_entries: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(raw_entries) != TYPE_ARRAY:
		return result
	for entry_variant: Variant in raw_entries:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var path := str(entry.get("path", ""))
		var path_exists := false
		if path.begins_with("res://") or path.begins_with("user://"):
			path_exists = FileAccess.file_exists(ProjectSettings.globalize_path(path))
		else:
			path_exists = FileAccess.file_exists(path)
		if path == "" or (not ResourceLoader.exists(path) and not path_exists):
			continue
		result.append({
			"id": str(entry.get("id", path)),
			"label": str(entry.get("label", path.get_file().get_basename())),
			"path": path,
			"source": str(entry.get("source", "builtin")),
		})
	return result


func _scan_custom_tracks() -> Array[Dictionary]:
	ensure_custom_music_dir()
	var custom_dir := get_custom_music_dir_path()
	var absolute_dir := ProjectSettings.globalize_path(custom_dir)
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return []

	var file_names: Array[String] = []
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue
		var extension := file_name.get_extension().to_lower()
		if SUPPORTED_EXTENSIONS.has(extension):
			file_names.append(file_name)
	dir.list_dir_end()
	file_names.sort()

	var tracks: Array[Dictionary] = []
	for file_name: String in file_names:
		var user_path := "%s/%s" % [custom_dir.trim_suffix("/"), file_name]
		tracks.append({
			"id": "custom:%s" % file_name,
			"label": "自定义 | %s" % file_name.get_basename(),
			"path": user_path,
			"source": "custom",
		})
	return tracks


func _load_stream_from_path(path: String) -> AudioStream:
	if path == "":
		return null
	if path.begins_with("res://"):
		var packed_resource := load(path)
		if packed_resource is AudioStream:
			return packed_resource
	var extension := path.get_extension().to_lower()
	var resolved_path := path
	if path.begins_with("user://") or path.begins_with("res://"):
		resolved_path = ProjectSettings.globalize_path(path)

	match extension:
		"ogg":
			return AudioStreamOggVorbis.load_from_file(resolved_path)
		"mp3":
			return AudioStreamMP3.load_from_file(resolved_path)
		"wav":
			return AudioStreamWAV.load_from_file(resolved_path)
		_:
			if ResourceLoader.exists(path):
				var resource := load(path)
				return resource if resource is AudioStream else null
	return null


func _volume_db_from_percent(percent: int) -> float:
	var clamped_percent := clampi(percent, 0, 100)
	if clamped_percent <= 0:
		return MIN_VOLUME_DB
	return linear_to_db(float(clamped_percent) / 100.0)


func _is_valid_track_entry(track: Dictionary) -> bool:
	return str(track.get("id", "")) != "" and str(track.get("label", "")) != "" and track.has("path")
