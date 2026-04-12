class_name TrainingExportPath
extends RefCounted


static func sanitize_token(raw: String) -> String:
	var text := raw.strip_edges()
	if text == "":
		return ""
	var regex := RegEx.new()
	regex.compile("[^A-Za-z0-9_\\-]+")
	text = regex.sub(text, "_", true)
	while text.find("__") >= 0:
		text = text.replace("__", "_")
	while text.begins_with("_"):
		text = text.substr(1)
	while text.ends_with("_"):
		text = text.left(text.length() - 1)
	return text


static func build_match_id(deck_a_id: int, deck_b_id: int, seed_value: int, seat_tag: String) -> String:
	var safe_seat := sanitize_token(seat_tag)
	if safe_seat == "":
		safe_seat = "a0"
	return "self_play_%d_vs_%d_s%d_%s" % [deck_a_id, deck_b_id, seed_value, safe_seat]


static func build_unique_user_json_path(base_dir: String, stem: String, prefix: String = "") -> String:
	var safe_stem := sanitize_token(stem)
	var safe_prefix := sanitize_token(prefix)
	if safe_stem == "":
		safe_stem = _fallback_stem(safe_prefix)
	elif safe_prefix != "" and not safe_stem.begins_with("%s_" % safe_prefix):
		safe_stem = "%s_%s" % [safe_prefix, safe_stem]

	var candidate := base_dir.path_join("%s.json" % safe_stem)
	if not _user_path_exists(candidate):
		return candidate

	var suffix: int = 1
	while true:
		var dedup := base_dir.path_join("%s_%02d.json" % [safe_stem, suffix])
		if not _user_path_exists(dedup):
			return dedup
		suffix += 1
	return candidate


static func _user_path_exists(user_path: String) -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path(user_path))


static func _fallback_stem(prefix: String) -> String:
	var base_prefix := prefix if prefix != "" else "export"
	return "%s_%d_%d_%d" % [
		base_prefix,
		int(Time.get_unix_time_from_system()),
		int(Time.get_ticks_msec()),
		int(OS.get_process_id()),
	]
