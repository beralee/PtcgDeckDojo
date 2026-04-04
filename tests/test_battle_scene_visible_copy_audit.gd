class_name TestBattleSceneVisibleCopyAudit
extends TestBase


const BATTLE_SCENE_PATH := "res://scenes/battle/BattleScene.gd"
const SUSPICIOUS_MARKERS := [
	"�",
	"锟",
	"瀵规",
	"鐜╁",
	"褰撳",
	"宸插",
	"閫夋",
	"鏍瑰洜",
	"鏈€浣",
	"鏆傛",
	"鍥炲",
	"缁",
]


func test_battle_scene_visible_copy_contains_no_mojibake() -> String:
	var source := FileAccess.get_file_as_string(BATTLE_SCENE_PATH)
	var lines := source.split("\n")
	var hits: Array[String] = []
	for i: int in lines.size():
		var line := lines[i]
		for marker: String in SUSPICIOUS_MARKERS:
			if marker in line:
				hits.append("%d:%s" % [i + 1, line.strip_edges()])
				break
	if hits.is_empty():
		return ""
	return "BattleScene 仍有乱码行:\n%s" % "\n".join(hits)
