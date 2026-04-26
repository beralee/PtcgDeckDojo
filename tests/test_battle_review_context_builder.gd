class_name TestBattleReviewContextBuilder
extends TestBase

const FixturePath := "res://tests/fixtures/match_review_fixture"
const ExtractorPath := "res://scripts/engine/BattleReviewTurnExtractor.gd"
const ContextBuilderPath := "res://scripts/engine/BattleReviewContextBuilder.gd"


func _new_extractor() -> Variant:
	if not ResourceLoader.exists(ExtractorPath):
		return {"ok": false, "error": "BattleReviewTurnExtractor script is missing"}
	var script: GDScript = load(ExtractorPath)
	var extractor = script.new()
	if extractor == null:
		return {"ok": false, "error": "BattleReviewTurnExtractor could not be instantiated"}
	return {"ok": true, "value": extractor}


func _new_context_builder() -> Variant:
	if not ResourceLoader.exists(ContextBuilderPath):
		return {"ok": false, "error": "BattleReviewContextBuilder script is missing"}
	var script: GDScript = load(ContextBuilderPath)
	var builder = script.new()
	if builder == null:
		return {"ok": false, "error": "BattleReviewContextBuilder could not be instantiated"}
	return {"ok": true, "value": builder}


func _fixture_turn_slice() -> Variant:
	var extractor_result: Variant = _new_extractor()
	if extractor_result is Dictionary and not bool((extractor_result as Dictionary).get("ok", false)):
		return extractor_result
	var extractor: Object = (extractor_result as Dictionary).get("value") as Object
	return extractor.call("extract_turn", FixturePath, 5)


func test_build_turn_packet_includes_board_and_zone_context() -> String:
	var builder_result: Variant = _new_context_builder()
	if builder_result is Dictionary and not bool((builder_result as Dictionary).get("ok", false)):
		return str((builder_result as Dictionary).get("error", "BattleReviewContextBuilder setup failed"))

	var slice: Variant = _fixture_turn_slice()
	if slice is Dictionary and bool((slice as Dictionary).get("ok", true)) == false:
		return str((slice as Dictionary).get("error", "Fixture turn slice failed"))

	var builder: Object = (builder_result as Dictionary).get("value") as Object
	if not builder.has_method("build_turn_packet"):
		return "BattleReviewContextBuilder is missing build_turn_packet"

	var packet: Variant = builder.call("build_turn_packet", slice)
	if not packet is Dictionary:
		return "build_turn_packet should return a Dictionary"

	return run_checks([
		assert_eq(int((packet as Dictionary).get("turn_number", 0)), 5, "Turn packet should preserve turn number"),
		assert_eq(int((packet as Dictionary).get("player_index", -1)), 0, "Turn packet should infer acting player"),
		assert_true((packet as Dictionary).has("board_before_turn"), "Turn packet should include board_before_turn"),
		assert_true((packet as Dictionary).has("zones_before_turn"), "Turn packet should include zones_before_turn"),
		assert_true((packet as Dictionary).has("deck_context"), "Turn packet should include deck_context"),
		assert_true((packet as Dictionary).has("strategic_context"), "Turn packet should include strategic_context"),
		assert_true(((packet as Dictionary).get("strategic_context", {}) as Dictionary).has("prior_turn_summaries"), "Turn packet should include multiple prior turn summaries for root-cause analysis"),
		assert_false(JSON.stringify((packet as Dictionary).get("board_before_turn", {})).contains("description"), "Board summary should not keep full card descriptions"),
		assert_false(JSON.stringify((packet as Dictionary).get("zones_before_turn", {})).contains("attacks"), "Zone summary should not keep full attack definitions"),
	])


func test_build_turn_packet_preserves_choices_actions_and_tags() -> String:
	var builder_result: Variant = _new_context_builder()
	if builder_result is Dictionary and not bool((builder_result as Dictionary).get("ok", false)):
		return str((builder_result as Dictionary).get("error", "BattleReviewContextBuilder setup failed"))

	var slice: Variant = _fixture_turn_slice()
	if slice is Dictionary and bool((slice as Dictionary).get("ok", true)) == false:
		return str((slice as Dictionary).get("error", "Fixture turn slice failed"))

	var builder: Object = (builder_result as Dictionary).get("value") as Object
	var packet: Variant = builder.call("build_turn_packet", slice)
	if not packet is Dictionary:
		return "build_turn_packet should return a Dictionary"

	var legal_choice_contexts: Array = (packet as Dictionary).get("legal_choice_contexts", [])
	var actions_and_choices: Array = (packet as Dictionary).get("actions_and_choices", [])
	var first_choice: Dictionary = legal_choice_contexts[0] if not legal_choice_contexts.is_empty() else {}
	return run_checks([
		assert_gt(legal_choice_contexts.size(), 0, "Turn packet should include legal_choice_contexts"),
		assert_gt(actions_and_choices.size(), 0, "Turn packet should include actions_and_choices"),
		assert_eq(String(first_choice.get("title", "")), "Ultra Ball", "Choice context should preserve the prompt title"),
		assert_eq((actions_and_choices[1] as Dictionary).get("selected_labels", []), ["Pidgeot ex"], "Selected labels should be preserved for model analysis"),
		assert_true((packet as Dictionary).has("heuristic_tags"), "Turn packet should include heuristic tags"),
	])


func test_build_turn_packet_summarizes_heavy_choice_payloads() -> String:
	var builder_result: Variant = _new_context_builder()
	if builder_result is Dictionary and not bool((builder_result as Dictionary).get("ok", false)):
		return str((builder_result as Dictionary).get("error", "BattleReviewContextBuilder setup failed"))

	var builder: Object = (builder_result as Dictionary).get("value") as Object
	var turn_slice := {
		"turn_number": 14,
		"events": [
			{
				"event_type": "choice_context",
				"title": "Complex prompt",
				"prompt_type": "pokemon_action",
				"selection_source": "dialog",
				"items": ["Option A", "Option B"],
				"extra_data": {
					"actions": [
						{
							"label": "Attack",
							"slot": {
								"pokemon_name": "Huge Pokemon",
								"attached_energy": [{"card_name": "Basic Psychic Energy"}],
								"pokemon_stack": [{"card_name": "Huge Pokemon"}],
							},
						}
					],
					"card_items": [{"card_name": "Huge Pokemon"}],
				},
				"player_index": 1,
				"turn_number": 14,
				"phase": "main",
			},
			{
				"event_type": "action_selected",
				"selection_source": "dialog",
				"selected_index": 0,
				"selected_labels": ["Attack"],
				"selected_indices": [0],
				"title": "Complex prompt",
				"turn_number": 14,
				"player_index": 1,
				"phase": "main",
				"assignments": [
					{
						"source": {"card_name": "Energy A"},
						"target": {"pokemon_name": "Huge Pokemon"},
					}
				],
			},
		],
		"before_snapshot": {
			"state": {
				"players": [],
			},
		},
		"match_meta": {},
		"match_result": {"winner_index": 0},
	}

	var packet: Variant = builder.call("build_turn_packet", turn_slice)
	if not packet is Dictionary:
		return "build_turn_packet should return a Dictionary"

	var legal_choice_contexts: Array = (packet as Dictionary).get("legal_choice_contexts", [])
	var actions_and_choices: Array = (packet as Dictionary).get("actions_and_choices", [])
	var choice_context: Dictionary = legal_choice_contexts[0] if not legal_choice_contexts.is_empty() else {}
	var action_selected: Dictionary = actions_and_choices[1] if actions_and_choices.size() > 1 else {}
	var serialized_size := JSON.stringify(packet).length()
	return run_checks([
		assert_eq(choice_context.get("option_labels", []), ["Option A", "Option B"], "Choice contexts should keep compact option labels"),
		assert_false(choice_context.has("items"), "Choice contexts should not keep raw item payloads"),
		assert_false(choice_context.has("extra_data"), "Choice contexts should not keep raw extra_data payloads"),
		assert_eq(action_selected.get("selected_labels", []), ["Attack"], "Action summaries should keep selected labels"),
		assert_eq(action_selected.get("assignments", []), ["Energy A -> Huge Pokemon"], "Action summaries should compact assignments into labels"),
		assert_true(serialized_size < 5000, "Summarized turn packets should stay compact even with heavy raw event payloads"),
	])


func test_build_turn_packet_includes_matchup_and_root_cause_context() -> String:
	var builder_result: Variant = _new_context_builder()
	if builder_result is Dictionary and not bool((builder_result as Dictionary).get("ok", false)):
		return str((builder_result as Dictionary).get("error", "BattleReviewContextBuilder setup failed"))

	var builder: Object = (builder_result as Dictionary).get("value") as Object
	var turn_slice := {
		"turn_number": 11,
		"events": [{"event_type": "action_selected", "player_index": 1, "turn_number": 11}],
		"before_snapshot": {
			"state": {
				"players": [
					{
						"player_index": 0,
						"hand": [{"card_name": "Professor's Research"}],
						"discard": [{"card_name": "Rare Candy"}],
						"prize_count": 4,
						"deck_count": 19,
					},
					{
						"player_index": 1,
						"hand": [{"card_name": "Boss's Orders"}],
						"discard": [{"card_name": "Ultra Ball"}],
						"prize_count": 2,
						"deck_count": 11,
					},
				],
			},
		},
		"match_meta": {
			"player_labels": ["player_0", "player_1"],
			"player_archetypes": {
				"0": "Charizard ex",
				"1": "Miraidon ex",
			},
			"first_player_index": 0,
		},
		"match_result": {"winner_index": 0},
		"previous_turn_summary": {"turn_number": 10, "key_actions": [{"description": "Player 1 used Boss's Orders"}]},
		"current_turn_summary": {"turn_number": 11, "key_actions": [{"description": "Player 1 attacked"}]},
		"prior_turn_summaries": [
			{"turn_number": 9, "key_actions": [{"description": "Player 0 evolved Charizard ex"}]},
			{"turn_number": 10, "key_actions": [{"description": "Player 1 used Boss's Orders"}]},
		],
	}

	var packet: Variant = builder.call("build_turn_packet", turn_slice)
	if not packet is Dictionary:
		return "build_turn_packet should return a Dictionary"

	var deck_context: Dictionary = (packet as Dictionary).get("deck_context", {})
	var strategic_context: Dictionary = (packet as Dictionary).get("strategic_context", {})
	var matchup_context: Dictionary = (packet as Dictionary).get("matchup_context", {})
	var prior_turn_summaries: Array = strategic_context.get("prior_turn_summaries", [])
	var first_prior_summary: Dictionary = prior_turn_summaries[0] if prior_turn_summaries.size() > 0 and prior_turn_summaries[0] is Dictionary else {}
	var first_prior_key_actions: Array = first_prior_summary.get("key_actions", [])
	var first_prior_key_action: Dictionary = first_prior_key_actions[0] if first_prior_key_actions.size() > 0 and first_prior_key_actions[0] is Dictionary else {}
	return run_checks([
		assert_eq(String(deck_context.get("acting_player_archetype", "")), "Miraidon ex", "Deck context should expose the acting player's archetype"),
		assert_eq(String(deck_context.get("opponent_archetype", "")), "Charizard ex", "Deck context should expose the opponent archetype"),
		assert_eq(String(matchup_context.get("pairing", "")), "Miraidon ex vs Charizard ex", "Turn packet should expose the matchup pairing"),
		assert_eq(prior_turn_summaries.size(), 2, "Strategic context should preserve up to two prior turn summaries"),
		assert_eq(String(first_prior_key_action.get("description", "")), "Player 0 evolved Charizard ex", "Prior turn summaries should preserve root-cause context"),
	])


func test_build_turn_packet_keeps_board_and_hand_compact_for_model_latency() -> String:
	var builder_result: Variant = _new_context_builder()
	if builder_result is Dictionary and not bool((builder_result as Dictionary).get("ok", false)):
		return str((builder_result as Dictionary).get("error", "BattleReviewContextBuilder setup failed"))

	var builder: Object = (builder_result as Dictionary).get("value") as Object
	var turn_slice := {
		"turn_number": 2,
		"events": [],
		"before_snapshot": {
			"state": {
				"players": [
					{
						"player_index": 0,
						"active": {
							"pokemon_name": "Dragapult ex",
							"pokemon_stack": [{
								"card_name": "Dragapult ex",
								"description": "Very long card description",
								"attacks": [{"name": "Phantom Dive", "text": "Attack text"}],
							}],
							"attached_energy": [{"card_name": "Basic Fire Energy"}],
						},
						"bench": [{
							"pokemon_name": "Drakloak",
							"pokemon_stack": [{
								"card_name": "Drakloak",
								"description": "Another long text",
							}],
						}],
						"hand": [
							{"card_name": "Boss's Orders", "description": "Long support text"},
							{"card_name": "Ultra Ball", "description": "Long item text"},
						],
						"discard": [
							{"card_name": "Rare Candy", "description": "Long candy text"},
						],
						"prize_count": 4,
						"deck_count": 20,
					},
					{
						"player_index": 1,
						"active": {"pokemon_name": "Raging Bolt ex", "pokemon_stack": [{"card_name": "Raging Bolt ex"}]},
						"bench": [],
						"hand": [{"card_name": "Professor Sada's Vitality"}],
						"discard": [],
						"prize_count": 5,
						"deck_count": 18,
					},
				],
			},
		},
		"match_meta": {"player_labels": ["Dragapult", "Bolt"]},
		"match_result": {"winner_index": 1},
	}

	var packet: Variant = builder.call("build_turn_packet", turn_slice)
	if not packet is Dictionary:
		return "build_turn_packet should return a Dictionary"

	var serialized := JSON.stringify(packet)
	return run_checks([
		assert_true(serialized.length() < 4000, "Turn packet should stay compact after board and hand summarization"),
		assert_false(serialized.contains("Very long card description"), "Turn packet should drop long active card descriptions"),
		assert_false(serialized.contains("Long support text"), "Turn packet should drop long hand card descriptions"),
		assert_true(serialized.contains("Boss's Orders"), "Turn packet should keep high-signal hand card names"),
	])

