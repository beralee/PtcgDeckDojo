class_name TestAIInteractionPlanner
extends TestBase


const AI_INTERACTION_PLANNER_SCRIPT_PATH := "res://scripts/ai/AIInteractionPlanner.gd"
const DeckStrategyGardevoirScript = preload("res://scripts/ai/DeckStrategyGardevoir.gd")
const DeckStrategyMiraidonScript = preload("res://scripts/ai/DeckStrategyMiraidon.gd")


class FakeInteractionStrategy:
	extends RefCounted

	var scores: Dictionary = {}

	func score_interaction_target(item: Variant, _step: Dictionary, _context: Dictionary = {}) -> float:
		return float(scores.get(str(item), 0.0))


func _load_script(script_path: String) -> GDScript:
	var script: Variant = load(script_path)
	return script if script is GDScript else null


func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "C",
	hp: int = 100,
	evolves_from: String = "",
	mechanic: String = "",
	attacks: Array = []
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	cd.evolves_from = evolves_from
	cd.mechanic = mechanic
	cd.attacks.clear()
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func test_interaction_planner_script_exists() -> String:
	var script := _load_script(AI_INTERACTION_PLANNER_SCRIPT_PATH)
	return assert_not_null(script, "AIInteractionPlanner.gd should exist and load")


func test_planner_selects_highest_scoring_indices_for_dialog_choices() -> String:
	var planner_script := _load_script(AI_INTERACTION_PLANNER_SCRIPT_PATH)
	if planner_script == null:
		return "AIInteractionPlanner.gd should exist before interaction target selection can be unified"
	var planner = planner_script.new()
	var strategy := FakeInteractionStrategy.new()
	strategy.scores = {"low": 10.0, "high": 90.0, "mid": 40.0}
	var selected: PackedInt32Array = planner.call(
		"pick_item_indices",
		strategy,
		["low", "high", "mid"],
		{"id": "fake_select"},
		2,
		{}
	)
	return assert_eq(Array(selected), [1, 2], "Planner should sort dialog choices by descending strategy score")


func test_planner_skips_excluded_targets_for_assignment() -> String:
	var planner_script := _load_script(AI_INTERACTION_PLANNER_SCRIPT_PATH)
	if planner_script == null:
		return "AIInteractionPlanner.gd should exist before assignment target selection can be unified"
	var planner = planner_script.new()
	var strategy := FakeInteractionStrategy.new()
	strategy.scores = {"first": 100.0, "second": 60.0, "third": 20.0}
	var best_index: int = int(planner.call(
		"pick_best_legal_target_index",
		strategy,
		["first", "second", "third"],
		[0],
		{"id": "fake_assignment"},
		{}
	))
	return assert_eq(best_index, 1, "Planner should skip excluded targets and pick the best remaining legal target")


func test_planner_uses_gardevoir_search_scoring_for_real_targets() -> String:
	var planner_script := _load_script(AI_INTERACTION_PLANNER_SCRIPT_PATH)
	if planner_script == null:
		return "AIInteractionPlanner.gd should exist before Gardevoir search selection can be unified"
	var planner = planner_script.new()
	CardInstance.reset_id_counter()
	var strategy := DeckStrategyGardevoirScript.new()
	var items: Array = [
		CardInstance.create(_make_pokemon_cd("Pidgey", "Basic", "C"), 0),
		CardInstance.create(_make_pokemon_cd("拉鲁拉丝", "Basic", "P"), 0),
		CardInstance.create(_make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝"), 0),
	]
	var selected: PackedInt32Array = planner.call(
		"pick_item_indices",
		strategy,
		items,
		{"id": "search_pokemon"},
		1,
		{}
	)
	var picked_index: int = -1 if selected.is_empty() else int(selected[0])
	var picked_name: String = "" if picked_index < 0 else str((items[picked_index] as CardInstance).card_data.name)
	return assert_eq(picked_name, "拉鲁拉丝", "Planner should preserve Gardevoir's core-pokemon search preference")


func test_planner_uses_gardevoir_search_item_scoring_with_board_context() -> String:
	var planner_script := _load_script(AI_INTERACTION_PLANNER_SCRIPT_PATH)
	if planner_script == null:
		return "AIInteractionPlanner.gd should exist before Gardevoir item search selection can be unified"
	var planner = planner_script.new()
	CardInstance.reset_id_counter()
	var strategy := DeckStrategyGardevoirScript.new()
	var gs := GameState.new()
	gs.turn_number = 2
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_make_pokemon_cd("Active%d" % pi), pi)
		gs.players.append(player)
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝"), 0))
	var items: Array = [
		CardInstance.create(_make_pokemon_cd("Potion"), 0),
		CardInstance.create(_make_pokemon_cd("巢穴球"), 0),
		CardInstance.create(_make_pokemon_cd("高级球"), 0),
	]
	for item: CardInstance in items:
		item.card_data.card_type = "Item"
	var selected: PackedInt32Array = planner.call(
		"pick_item_indices",
		strategy,
		items,
		{"id": "search_item"},
		1,
		{"game_state": gs, "player_index": 0}
	)
	var picked_index: int = -1 if selected.is_empty() else int(selected[0])
	var picked_name: String = "" if picked_index < 0 else str((items[picked_index] as CardInstance).card_data.name)
	return assert_eq(picked_name, "高级球", "Planner should preserve Gardevoir's context-aware item search priority")


func test_planner_uses_miraidon_energy_target_scoring_for_real_targets() -> String:
	var planner_script := _load_script(AI_INTERACTION_PLANNER_SCRIPT_PATH)
	if planner_script == null:
		return "AIInteractionPlanner.gd should exist before Miraidon target selection can be unified"
	var planner = planner_script.new()
	CardInstance.reset_id_counter()
	var strategy := DeckStrategyMiraidonScript.new()
	var iron_hands := _make_slot(
		_make_pokemon_cd("铁臂膀ex", "Basic", "L", 230, "", "ex", [{"name": "Amp You Very Much", "cost": "LLC", "damage": "160"}]),
		0
	)
	iron_hands.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	iron_hands.attached_energy.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var miraidon := _make_slot(_make_pokemon_cd("密勒顿ex", "Basic", "L", 220, "", "ex", [{"name": "Photon Blaster", "cost": "LLC", "damage": "220"}]), 0)
	var best_index: int = int(planner.call(
		"pick_best_legal_target_index",
		strategy,
		[miraidon, iron_hands],
		[],
		{"id": "energy_target"},
		{}
	))
	return assert_eq(best_index, 1, "Planner should preserve Miraidon's preference for the near-ready attacker over the engine")


func _make_energy_cd(pname: String, energy_provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy_provides
	return cd
