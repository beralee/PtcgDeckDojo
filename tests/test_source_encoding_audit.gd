## 源码编码审计测试 - 防止乱码和异常字符再次进入仓库
class_name TestSourceEncodingAudit
extends TestBase


const ROOT_TARGETS := [
	"res://scripts",
	"res://scenes",
	"res://tests",
	"res://docs",
	"res://project.godot",
	"res://README.md",
	"res://CONTRIBUTING.md",
	"res://SECURITY.md",
	"res://CLAUDE.md",
	"res://DEVELOPMENT_SPEC.md",
	"res://.editorconfig",
]

const ALLOWED_EXTENSIONS := {
	"gd": true,
	"tscn": true,
	"md": true,
	"json": true,
	"txt": true,
	"cfg": true,
}

const KNOWN_MOJIBAKE_CODEPOINTS := {
	0x95B8: true,
	0x940E: true,
	0x9368: true,
	0x7F01: true,
	0x8930: true,
	0x7035: true,
	0x6960: true,
	0x93CD: true,
	0x951F: true,
}

const BATTLE_SCENE_FORBIDDEN_UI_PHRASES := [
	"Cannot retreat right now",
	"Opponent Hand:",
	"Your Hand:",
	"Opponent Discard",
	"Your Discard",
	"Select action",
	"Waiting for opponent",
	"Missing selected deck data",
]


func test_no_suspicious_source_characters() -> String:
	var targets: Array[String] = []
	for root: String in ROOT_TARGETS:
		_collect_targets(root, targets)

	for path: String in targets:
		var error := _audit_file(path)
		if error != "":
			return error

	return ""


func _collect_targets(path: String, out: Array[String]) -> void:
	if FileAccess.file_exists(path):
		if _is_allowed_target(path):
			out.append(path)
		return

	if not DirAccess.dir_exists_absolute(path):
		return

	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue

		var child_path := path.path_join(name)
		if dir.current_is_dir():
			_collect_targets(child_path, out)
		elif _is_allowed_target(child_path):
			out.append(child_path)
	dir.list_dir_end()


func _is_allowed_target(path: String) -> bool:
	var ext := path.get_extension().to_lower()
	return ALLOWED_EXTENSIONS.has(ext)


func _audit_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "无法打开文件: %s" % path

	var text := file.get_as_text()
	var lines := text.split("\n")
	for i: int in lines.size():
		var line: String = lines[i]
		var forbidden_phrase_error := _check_forbidden_ui_phrases(path, i + 1, line)
		if forbidden_phrase_error != "":
			return forbidden_phrase_error

		var placeholder_error := _check_placeholder_question_marks(path, i + 1, line)
		if placeholder_error != "":
			return placeholder_error

		var marker_error := _check_known_mojibake(path, i + 1, line)
		if marker_error != "":
			return marker_error

		var char_error := _check_line_codepoints(path, i + 1, line)
		if char_error != "":
			return char_error

	return ""


func _check_placeholder_question_marks(path: String, line_number: int, line: String) -> String:
	var marker := "?" + "?" + "?"
	if marker in line:
		return "检测到疑似占位乱码 %s 于 %s:%d" % [marker, path, line_number]
	return ""


func _check_forbidden_ui_phrases(path: String, line_number: int, line: String) -> String:
	if not path.ends_with("scenes/battle/BattleScene.gd"):
		return ""
	for phrase: String in BATTLE_SCENE_FORBIDDEN_UI_PHRASES:
		if phrase in line:
			return "检测到 BattleScene 英文回退文案 \"%s\" 于 %s:%d" % [phrase, path, line_number]
	return ""


func _check_known_mojibake(path: String, line_number: int, line: String) -> String:
	for i: int in line.length():
		var cp := line.unicode_at(i)
		if KNOWN_MOJIBAKE_CODEPOINTS.has(cp):
			return "检测到疑似乱码标记 U+%04X 于 %s:%d" % [cp, path, line_number]
	return ""


func _check_line_codepoints(path: String, line_number: int, line: String) -> String:
	for j: int in line.length():
		var cp := line.unicode_at(j)
		if _is_allowed_codepoint(cp):
			continue
		return "检测到异常字符 U+%04X 于 %s:%d" % [cp, path, line_number]
	return ""


func _is_allowed_codepoint(codepoint: int) -> bool:
	if codepoint == 9:
		return true
	if codepoint == 13:
		return true
	if codepoint >= 32 and codepoint <= 126:
		return true
	if codepoint >= 0x00B7 and codepoint <= 0x00D7:
		return true
	if codepoint >= 0x2000 and codepoint <= 0x206F:
		return true
	if codepoint >= 0x2190 and codepoint <= 0x22FF:
		return true
	if codepoint >= 0x3000 and codepoint <= 0x303F:
		return true
	if codepoint >= 0x3040 and codepoint <= 0x30FF:
		return true
	if codepoint >= 0x3400 and codepoint <= 0x4DBF:
		return true
	if codepoint >= 0x4E00 and codepoint <= 0x9FFF:
		return true
	if codepoint >= 0xFF00 and codepoint <= 0xFFEF:
		return true
	return false
