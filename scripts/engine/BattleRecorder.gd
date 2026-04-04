class_name BattleRecorder
extends RefCounted

const BattleEventBuilderScript = preload("res://scripts/engine/BattleEventBuilder.gd")
const BattleRecordExporterScript = preload("res://scripts/engine/BattleRecordExporter.gd")
const BattleSummaryFormatterScript = preload("res://scripts/engine/BattleSummaryFormatter.gd")

var base_dir: String = "user://match_records"

var _builder = BattleEventBuilderScript.new()
var _exporter = BattleRecordExporterScript.new()
var _summary_formatter = BattleSummaryFormatterScript.new()
var _match_id: String = ""
var _match_dir: String = ""
var _meta: Dictionary = {}
var _initial_state: Dictionary = {}
var _result: Dictionary = {}
var _events: Array = []
var _event_index: int = 0
var _active: bool = false
var _recording_failed: bool = false


func set_output_root(root_path: String) -> void:
	base_dir = root_path


func start_match(match_meta: Dictionary, initial_state: Dictionary = {}) -> void:
	_reset_session()
	_meta = match_meta.duplicate(true)
	_initial_state = initial_state.duplicate(true)
	_match_id = _builder.make_match_id()
	_match_dir = base_dir.path_join(_match_id)

	if not _ensure_directory(base_dir):
		_active = false
		return
	if not _ensure_directory(_match_dir):
		_active = false
		return

	_active = true


func update_match_context(match_meta: Dictionary, initial_state: Dictionary = {}) -> void:
	if not _active:
		return
	_meta = match_meta.duplicate(true)
	_initial_state = initial_state.duplicate(true)


func record_event(event_data: Dictionary) -> void:
	if not _active or _recording_failed:
		return

	var normalized: Dictionary = _builder.build_event(event_data, _match_id, _event_index)
	_event_index += 1
	_events.append(normalized)
	if not _append_json_line(_match_dir.path_join("detail.jsonl"), normalized):
		_recording_failed = true
		return
	if not _append_summary_line(_match_dir.path_join("summary.log"), _summary_formatter.format_event(normalized)):
		_recording_failed = true


func finalize_match(result_data: Dictionary) -> void:
	if not _active:
		_result = result_data.duplicate(true)
		return

	_result = result_data.duplicate(true)
	if not _recording_failed:
		_recording_failed = not _exporter.export_match(_match_dir, _meta, _initial_state, _events, _result)
	_active = false


func get_match_dir() -> String:
	return _match_dir


func _reset_session() -> void:
	_match_id = ""
	_match_dir = ""
	_meta = {}
	_initial_state = {}
	_result = {}
	_events.clear()
	_event_index = 0
	_active = false
	_recording_failed = false


func _ensure_directory(path: String) -> bool:
	var global_path := ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(global_path):
		return true
	if FileAccess.file_exists(global_path):
		return false
	if not _can_create_directory(global_path):
		return false
	return DirAccess.make_dir_recursive_absolute(global_path) == OK


func _can_create_directory(global_path: String) -> bool:
	var current := global_path
	while true:
		var parent := current.get_base_dir()
		if parent == "" or parent == current:
			return true
		if FileAccess.file_exists(parent):
			return false
		if DirAccess.dir_exists_absolute(parent):
			return true
		current = parent
	return false


func _append_json_line(path: String, data: Dictionary) -> bool:
	return _append_line(path, JSON.stringify(data))


func _append_summary_line(path: String, line: String) -> bool:
	return _append_line(path, line)


func _append_line(path: String, line: String) -> bool:
	var global_path := ProjectSettings.globalize_path(path)
	var dir_path := global_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var mkdir_error := DirAccess.make_dir_recursive_absolute(dir_path)
		if mkdir_error != OK:
			return false

	if not FileAccess.file_exists(global_path):
		var create_file := FileAccess.open(path, FileAccess.WRITE)
		if create_file == null:
			return false
		create_file.close()

	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		return false

	file.seek_end()
	var wrote := file.store_line(line)
	file.flush()
	var write_ok := wrote and file.get_error() == OK
	file.close()
	return write_ok
