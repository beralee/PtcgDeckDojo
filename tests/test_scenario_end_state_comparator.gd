class_name TestScenarioEndStateComparator
extends TestBase

const RegistryScript = preload("res://scripts/ai/scenario_comparator/ScenarioEquivalenceRegistry.gd")
const ComparatorScript = preload("res://scripts/ai/scenario_comparator/ScenarioEndStateComparator.gd")


func _make_pokemon_data(name: String, hp: int, stage: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = hp
	card.energy_type = "P"
	return card


func _make_energy_data(bucket: String) -> CardData:
	var card := CardData.new()
	card.name = "%s Energy" % bucket
	card.card_type = "Basic Energy"
	card.energy_provides = bucket
	return card


func _make_tool_data(name: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Tool"
	return card


func _make_misc_card_data(name: String, card_type: String = "Item") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = card_type
	return card


func _make_slot(
	owner_index: int,
	stack_names: Array[String],
	top_hp: int = 200,
	damage: int = 0,
	energy_types: Array[String] = [],
	tool_name: String = ""
) -> PokemonSlot:
	var slot := PokemonSlot.new()
	for i in range(stack_names.size()):
		var stage := "Basic"
		if i == 1:
			stage = "Stage 1"
		elif i >= 2:
			stage = "Stage 2"
		var hp := top_hp if i == stack_names.size() - 1 else maxi(40, top_hp - 40)
		slot.pokemon_stack.append(CardInstance.create(_make_pokemon_data(stack_names[i], hp, stage), owner_index))
	for energy_type: String in energy_types:
		slot.attached_energy.append(CardInstance.create(_make_energy_data(energy_type), owner_index))
	if tool_name != "":
		slot.attached_tool = CardInstance.create(_make_tool_data(tool_name), owner_index)
	slot.damage_counters = damage
	return slot


func _make_player(
	player_index: int,
	active_slot: PokemonSlot,
	bench_slots: Array,
	hand_names: Array[String],
	prize_count: int,
	discard_names: Array[String] = []
) -> PlayerState:
	var player := PlayerState.new()
	player.player_index = player_index
	player.active_pokemon = active_slot
	for slot_variant: Variant in bench_slots:
		player.bench.append(slot_variant as PokemonSlot)
	for card_name: String in hand_names:
		player.hand.append(CardInstance.create(_make_misc_card_data(card_name), player_index))
	for i in range(prize_count):
		player.prizes.append(CardInstance.create(_make_misc_card_data("Prize%d_%d" % [player_index, i]), player_index))
	for card_name: String in discard_names:
		player.discard_pile.append(CardInstance.create(_make_misc_card_data(card_name), player_index))
	return player


func _make_game_state(tracked_player: PlayerState, opponent_player: PlayerState) -> GameState:
	var game_state := GameState.new()
	game_state.players = [tracked_player, opponent_player]
	game_state.current_player_index = 0
	game_state.first_player_index = 0
	game_state.turn_number = 3
	return game_state


func _extract_end_state(game_state: GameState, tracked_player_index: int, scenario_id: String = "scenario_fixture") -> Dictionary:
	return {
		"scenario_id": scenario_id,
		"primary": RegistryScript.extract_primary(game_state, tracked_player_index),
		"secondary": RegistryScript.extract_secondary(game_state, tracked_player_index),
	}


func _diff_has_path(verdict: Dictionary, path_fragment: String) -> bool:
	var diff: Array = verdict.get("diff", [])
	for entry_variant: Variant in diff:
		if not entry_variant is Dictionary:
			continue
		if path_fragment in str((entry_variant as Dictionary).get("path", "")):
			return true
	return false


func test_extract_primary_and_secondary_capture_contract() -> String:
	CardInstance.reset_id_counter()
	var tracked_player := _make_player(
		0,
		_make_slot(0, ["Ralts", "Kirlia"], 90, 20, ["P", "P"], "Luxurious Cape"),
		[_make_slot(0, ["Munkidori"], 110, 0, ["D"])],
		["Rare Candy", "Ultra Ball"],
		4,
		["Professor's Research"]
	)
	var opponent_player := _make_player(
		1,
		_make_slot(1, ["Miraidon ex"], 220, 50, ["L", "L"], ""),
		[],
		["Boss's Orders"],
		3,
		["Electric Generator"]
	)
	var end_state := _extract_end_state(_make_game_state(tracked_player, opponent_player), 0)
	var primary: Dictionary = end_state.get("primary", {})
	var secondary: Dictionary = end_state.get("secondary", {})
	var tracked_primary: Dictionary = primary.get("tracked_player", {})
	var tracked_active: Dictionary = tracked_primary.get("active", {})
	var tracked_secondary: Dictionary = secondary.get("tracked_player", {})

	return run_checks([
		assert_eq(String(tracked_active.get("pokemon_name", "")), "Kirlia", "Primary active summary should use the top Pokemon name"),
		assert_eq(tracked_active.get("evolution_stack", []), ["Ralts", "Kirlia"], "Primary active summary should preserve the evolution stack"),
		assert_eq(int(tracked_active.get("energy_count", 0)), 2, "Primary active summary should capture exact attached energy count"),
		assert_eq((tracked_active.get("energy_types", {}) as Dictionary).get("P", 0), 2, "Primary active summary should capture energy type counts"),
		assert_eq(String(tracked_active.get("tool_name", "")), "Luxurious Cape", "Primary active summary should compare tool name only"),
		assert_eq(int(tracked_active.get("damage", 0)), 20, "Primary active summary should capture exact damage"),
		assert_eq(tracked_primary.get("hand", []), ["Rare Candy", "Ultra Ball"], "Primary hand summary should be a sorted card-name multiset"),
		assert_eq(int(tracked_primary.get("prize_count", 0)), 4, "Primary summary should capture remaining prize count"),
		assert_eq(int(tracked_secondary.get("total_remaining_hp", 0)), 180, "Secondary summary should capture total remaining HP"),
		assert_eq(int(tracked_secondary.get("total_energy", 0)), 3, "Secondary summary should capture total board energy"),
		assert_eq(tracked_secondary.get("discard_card_names", []), ["Professor's Research"], "Secondary summary should preserve discard card names"),
	])


func test_compare_passes_on_identical_end_state_with_unordered_bench() -> String:
	CardInstance.reset_id_counter()
	var expected_game_state := _make_game_state(
		_make_player(
			0,
			_make_slot(0, ["Ralts", "Kirlia"], 90, 20, ["P", "P"], "Luxurious Cape"),
			[
				_make_slot(0, ["Munkidori"], 110, 10, ["D"]),
				_make_slot(0, ["Fezandipiti ex"], 210, 0, ["P"]),
			],
			["Rare Candy", "Ultra Ball"],
			4
		),
		_make_player(1, _make_slot(1, ["Miraidon ex"], 220, 50, ["L", "L"]), [], ["Boss's Orders"], 3)
	)
	var ai_game_state := _make_game_state(
		_make_player(
			0,
			_make_slot(0, ["Ralts", "Kirlia"], 90, 20, ["P", "P"], "Luxurious Cape"),
			[
				_make_slot(0, ["Fezandipiti ex"], 210, 0, ["P"]),
				_make_slot(0, ["Munkidori"], 110, 10, ["D"]),
			],
			["Ultra Ball", "Rare Candy"],
			4
		),
		_make_player(1, _make_slot(1, ["Miraidon ex"], 220, 50, ["L", "L"]), [], ["Boss's Orders"], 3)
	)
	var expected_end_state := _extract_end_state(expected_game_state, 0, "unordered_bench")
	var ai_end_state := _extract_end_state(ai_game_state, 0, "unordered_bench")
	var verdict: Dictionary = ComparatorScript.compare(ai_end_state, expected_end_state, [])

	return run_checks([
		assert_eq(String(verdict.get("status", "")), "PASS", "Unordered bench states should still pass when the multiset matches"),
		assert_false(bool(verdict.get("dominant", false)), "Exact primary matches should not use the dominant path"),
		assert_eq((verdict.get("diff", []) as Array).size(), 0, "Exact primary matches should not report diffs"),
	])


func test_compare_requires_exact_hand_multiset() -> String:
	CardInstance.reset_id_counter()
	var expected_game_state := _make_game_state(
		_make_player(0, _make_slot(0, ["Kirlia"], 90, 20, ["P"]), [], ["Rare Candy", "Ultra Ball"], 4),
		_make_player(1, _make_slot(1, ["Miraidon ex"], 220, 50, ["L"]), [], [], 3)
	)
	var ai_game_state := _make_game_state(
		_make_player(0, _make_slot(0, ["Kirlia"], 90, 20, ["P"]), [], ["Rare Candy"], 4),
		_make_player(1, _make_slot(1, ["Miraidon ex"], 220, 50, ["L"]), [], [], 3)
	)
	var verdict: Dictionary = ComparatorScript.compare(_extract_end_state(ai_game_state, 0), _extract_end_state(expected_game_state, 0), [])

	return run_checks([
		assert_eq(String(verdict.get("status", "")), "DIVERGE", "Hand mismatches should not be treated as PASS"),
		assert_true(_diff_has_path(verdict, "primary.tracked_player.hand"), "Hand mismatches should surface in the diff"),
	])


func test_compare_uses_tool_name_and_energy_type_counts_instead_of_instance_identity() -> String:
	CardInstance.reset_id_counter()
	var expected_game_state := _make_game_state(
		_make_player(0, _make_slot(0, ["Kirlia"], 90, 20, ["P", "P"], "Bravery Charm"), [], ["Iono"], 4),
		_make_player(1, _make_slot(1, ["Miraidon ex"], 220, 50, ["L", "L"]), [], [], 3)
	)

	CardInstance.reset_id_counter()
	var ai_game_state := _make_game_state(
		_make_player(0, _make_slot(0, ["Kirlia"], 90, 20, ["P", "P"], "Bravery Charm"), [], ["Iono"], 4),
		_make_player(1, _make_slot(1, ["Miraidon ex"], 220, 50, ["L", "L"]), [], [], 3)
	)
	var verdict: Dictionary = ComparatorScript.compare(_extract_end_state(ai_game_state, 0), _extract_end_state(expected_game_state, 0), [])

	return run_checks([
		assert_eq(String(verdict.get("status", "")), "PASS", "Matching tool names and energy type counts should pass across separate instances"),
		assert_eq((verdict.get("diff", []) as Array).size(), 0, "Instance identity should not leak into the comparator diff"),
	])


func test_compare_matches_approved_divergent_end_state() -> String:
	CardInstance.reset_id_counter()
	var expected_game_state := _make_game_state(
		_make_player(0, _make_slot(0, ["Kirlia"], 90, 20, ["P"]), [], ["Rare Candy"], 4),
		_make_player(1, _make_slot(1, ["Miraidon ex"], 220, 50, ["L"]), [], [], 3)
	)
	var ai_game_state := _make_game_state(
		_make_player(0, _make_slot(0, ["Kirlia"], 90, 20, ["P"]), [], ["Rare Candy", "Buddy-Buddy Poffin"], 4),
		_make_player(1, _make_slot(1, ["Miraidon ex"], 220, 50, ["L"]), [], [], 3)
	)
	var ai_end_state := _extract_end_state(ai_game_state, 0, "approved_alt")
	var verdict: Dictionary = ComparatorScript.compare(
		ai_end_state,
		_extract_end_state(expected_game_state, 0, "approved_alt"),
		[
			{
				"alternative_id": "alt_keep_poffin",
				"end_state": ai_end_state,
			}
		]
	)

	return run_checks([
		assert_eq(String(verdict.get("status", "")), "PASS", "Approved divergent end states should count as PASS"),
		assert_eq(String(verdict.get("matched_alternative_id", "")), "alt_keep_poffin", "The matching approved alternative id should be reported"),
		assert_false(bool(verdict.get("dominant", false)), "Approved alternatives are not dominant passes"),
	])


func test_compare_allows_very_conservative_dominant_damage_only_upgrade() -> String:
	CardInstance.reset_id_counter()
	var expected_game_state := _make_game_state(
		_make_player(
			0,
			_make_slot(0, ["Kirlia"], 100, 40, ["P", "P"], "Bravery Charm"),
			[_make_slot(0, ["Munkidori"], 110, 20, ["D"])],
			["Iono"],
			4,
			["Rare Candy"]
		),
		_make_player(
			1,
			_make_slot(1, ["Miraidon ex"], 220, 60, ["L", "L"]),
			[_make_slot(1, ["Iron Hands ex"], 230, 10, ["L", "L", "F"])],
			["Boss's Orders"],
			3,
			["Electric Generator"]
		)
	)
	var ai_game_state := _make_game_state(
		_make_player(
			0,
			_make_slot(0, ["Kirlia"], 100, 20, ["P", "P"], "Bravery Charm"),
			[_make_slot(0, ["Munkidori"], 110, 10, ["D"])],
			["Iono"],
			4,
			["Rare Candy"]
		),
		_make_player(
			1,
			_make_slot(1, ["Miraidon ex"], 220, 80, ["L", "L"]),
			[_make_slot(1, ["Iron Hands ex"], 230, 20, ["L", "L", "F"])],
			["Boss's Orders"],
			3,
			["Electric Generator"]
		)
	)
	var verdict: Dictionary = ComparatorScript.compare(_extract_end_state(ai_game_state, 0, "dominant_case"), _extract_end_state(expected_game_state, 0, "dominant_case"), [])

	return run_checks([
		assert_eq(String(verdict.get("status", "")), "PASS", "Damage-only board improvements should be eligible for the dominant pass"),
		assert_true(bool(verdict.get("dominant", false)), "The comparator should flag the dominant path explicitly"),
		assert_true(_diff_has_path(verdict, ".damage"), "Dominant PASS should preserve the strict damage diff for auditability"),
	])


func test_compare_marks_damage_only_regression_as_diverge() -> String:
	CardInstance.reset_id_counter()
	var expected_game_state := _make_game_state(
		_make_player(0, _make_slot(0, ["Kirlia"], 100, 20, ["P"], "Bravery Charm"), [], ["Iono"], 4),
		_make_player(1, _make_slot(1, ["Miraidon ex"], 220, 80, ["L"]), [], [], 3)
	)
	var ai_game_state := _make_game_state(
		_make_player(0, _make_slot(0, ["Kirlia"], 100, 40, ["P"], "Bravery Charm"), [], ["Iono"], 4),
		_make_player(1, _make_slot(1, ["Miraidon ex"], 220, 60, ["L"]), [], [], 3)
	)
	var verdict: Dictionary = ComparatorScript.compare(_extract_end_state(ai_game_state, 0), _extract_end_state(expected_game_state, 0), [])

	return run_checks([
		assert_eq(String(verdict.get("status", "")), "DIVERGE", "Damage-only regressions should not be upgraded to FAIL by default"),
		assert_false(bool(verdict.get("dominant", false)), "A worse damage state cannot take the dominant path"),
		assert_true(_diff_has_path(verdict, ".damage"), "Damage regressions should be preserved in the diff"),
	])


func test_compare_marks_prize_race_regression_as_fail() -> String:
	CardInstance.reset_id_counter()
	var expected_game_state := _make_game_state(
		_make_player(0, _make_slot(0, ["Kirlia"], 100, 20, ["P"]), [], ["Iono"], 3),
		_make_player(1, _make_slot(1, ["Miraidon ex"], 220, 80, ["L"]), [], [], 4)
	)
	var ai_game_state := _make_game_state(
		_make_player(0, _make_slot(0, ["Kirlia"], 100, 20, ["P"]), [], ["Iono"], 4),
		_make_player(1, _make_slot(1, ["Miraidon ex"], 220, 80, ["L"]), [], [], 3)
	)
	var verdict: Dictionary = ComparatorScript.compare(_extract_end_state(ai_game_state, 0), _extract_end_state(expected_game_state, 0), [])

	return run_checks([
		assert_eq(String(verdict.get("status", "")), "FAIL", "A worse prize race should be classified as FAIL"),
		assert_str_contains(String(verdict.get("reason", "")), "prize race", "FAIL reasons should explain the prize-race regression"),
	])
