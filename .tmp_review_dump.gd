extends SceneTree

const TestScript = preload("res://tests/test_battle_ui_features.gd")

func _initialize() -> void:
	var suite = TestScript.new()
	var scene = suite._make_battle_scene_stub()
	var review_text: String = scene.call("_format_battle_review", {
		"status": "partial_success",
		"selected_turns": [
			{"turn_number": 5, "reason": "winner swing", "side": "winner"},
			{"turn_number": 6, "reason": "loser stumble", "side": "loser"}
		],
		"turn_reviews": [
			{
				"turn_number": 5,
				"player_index": 0,
				"judgment": "suboptimal",
				"why_current_line_falls_short": ["winner issue"],
				"better_line": {"goal": "win cleaner", "steps": ["take prize", "hold gust"]},
				"why_better": ["safer map"]
			},
			{
				"turn_number": 6,
				"player_index": 1,
				"judgment": "suboptimal",
				"why_current_line_falls_short": ["loser issue"],
				"better_line": {"goal": "stabilize", "steps": ["bench less"]},
				"why_better": ["deny swing"]
			}
		]
	})
	print(review_text)
	quit()
