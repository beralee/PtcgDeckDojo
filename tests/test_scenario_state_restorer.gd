class_name TestScenarioStateRestorer
extends TestBase


const ScenarioStateSnapshotScript = preload("res://scripts/engine/scenario/ScenarioStateSnapshot.gd")
const ScenarioStateRestorerScript = preload("res://scripts/engine/scenario/ScenarioStateRestorer.gd")
const ScenarioStateSnapshotTestScript = preload("res://tests/test_scenario_state_snapshot.gd")


func test_restore_rebuilds_runnable_game_state_machine_state() -> String:
	var original_state := _make_game_state()
	var snapshot: Dictionary = ScenarioStateSnapshotScript.capture(original_state)
	var restore_result: Dictionary = ScenarioStateRestorerScript.restore(snapshot)
	var errors: Array = restore_result.get("errors", [])
	var gsm: GameStateMachine = restore_result.get("gsm", null)
	var restored_state: GameState = gsm.game_state if gsm != null else null
	var restored_p0: PlayerState = restored_state.players[0] if restored_state != null and restored_state.players.size() > 0 else null
	var restored_p1: PlayerState = restored_state.players[1] if restored_state != null and restored_state.players.size() > 1 else null

	return run_checks([
		assert_eq(errors.size(), 0, "Restore should succeed without validation errors"),
		assert_not_null(gsm, "Restore should provide a GameStateMachine"),
		assert_not_null(gsm.rule_validator, "Restored GameStateMachine should keep subsystems"),
		assert_eq(restored_state.phase, GameState.GamePhase.MAIN, "Restore should map phase names back to enums"),
		assert_eq(restored_state.current_player_index, 1, "Restore should keep current player"),
		assert_eq(restored_p0.hand.size(), 2, "Restore should keep player 0 hand size"),
		assert_eq(restored_p1.bench.size(), 1, "Restore should keep player 1 bench size"),
		assert_eq(restored_p0.active_pokemon.damage_counters, 60, "Restore should keep exact damage"),
		assert_eq(str(restored_p0.active_pokemon.attached_tool.card_data.name), "Defiance Band", "Restore should keep tool names"),
		assert_eq(_energy_signature(restored_p1.active_pokemon), {"L": 3}, "Restore should keep energy type counts"),
		assert_eq(str(restored_p1.active_pokemon.get_top_card().card_data.mechanic), "ex", "Restore should keep full card metadata"),
		assert_eq(str(restored_p1.prize_layout[2].card_data.name), "Prize Generator", "Restore should keep prize layout references"),
		assert_eq((gsm.get("_expected_card_totals") as Array).size(), 2, "Restore should seed expected card totals for runtime assertions"),
	])


func test_capture_restore_roundtrip_is_snapshot_stable() -> String:
	var snapshot: Dictionary = ScenarioStateSnapshotScript.capture(_make_game_state())
	var restore_result: Dictionary = ScenarioStateRestorerScript.restore(snapshot)
	var gsm: GameStateMachine = restore_result.get("gsm", null)
	var roundtrip_snapshot: Dictionary = ScenarioStateSnapshotScript.capture(gsm.game_state if gsm != null else null)
	return run_checks([
		assert_eq(restore_result.get("errors", []).size(), 0, "Roundtrip restore should succeed"),
		assert_eq(roundtrip_snapshot, snapshot, "Capture -> restore -> capture should remain stable"),
	])


func test_restore_rejects_invalid_snapshot() -> String:
	var restore_result: Dictionary = ScenarioStateRestorerScript.restore({"turn_number": 1})
	var errors: Array = restore_result.get("errors", [])
	return run_checks([
		assert_true(errors.size() > 0, "Restore should reject malformed snapshots"),
		assert_null(restore_result.get("gsm", null), "Malformed snapshots should not produce a GameStateMachine"),
	])


func test_restore_backfills_missing_name_en_from_card_database() -> String:
	var snapshot: Dictionary = ScenarioStateSnapshotScript.capture(_make_game_state())
	var hand: Array = ((snapshot.get("players", []) as Array)[0] as Dictionary).get("hand", [])
	if hand.is_empty():
		return "Expected scenario snapshot fixture to provide at least one hand card"
	var first_hand_card: Dictionary = (hand[0] as Dictionary).duplicate(true)
	first_hand_card["set_code"] = "CSVH1C"
	first_hand_card["card_index"] = "043"
	first_hand_card.erase("name_en")
	first_hand_card["name"] = "Nest Ball Local"
	first_hand_card["card_name"] = "Nest Ball Local"
	(((snapshot.get("players", []) as Array)[0] as Dictionary).get("hand", []) as Array)[0] = first_hand_card
	var restore_result: Dictionary = ScenarioStateRestorerScript.restore(snapshot)
	var gsm: GameStateMachine = restore_result.get("gsm", null)
	var restored_card: CardInstance = null if gsm == null or gsm.game_state == null else gsm.game_state.players[0].hand[0]
	return run_checks([
		assert_eq(restore_result.get("errors", []).size(), 0, "Restore should still succeed when name_en is missing from the snapshot"),
		assert_not_null(restored_card, "Restore should rebuild the hand card"),
		assert_eq(str(restored_card.card_data.name), "Nest Ball Local", "Restore should keep the recorded localized name"),
		assert_eq(str(restored_card.card_data.name_en), "Nest Ball", "Restore should backfill name_en from CardDatabase for old scenarios"),
	])


func test_restore_re_registers_pokemon_effects_for_native_abilities() -> String:
	var state := GameState.new()
	state.phase = GameState.GamePhase.MAIN
	state.current_player_index = 0
	state.first_player_index = 0
	state.players = [PlayerState.new(), PlayerState.new()]
	state.players[0].player_index = 0
	state.players[1].player_index = 1

	var arceus_cd: CardData = CardDatabase.get_card("CS5aC", "107")
	var filler_cd: CardData = CardDatabase.get_card("CSVH1C", "043")
	if arceus_cd == null or filler_cd == null:
		return "Expected CardDatabase to provide Arceus VSTAR and Nest Ball real card data"

	var arceus_slot := PokemonSlot.new()
	arceus_slot.pokemon_stack.append(CardInstance.create(arceus_cd, 0))
	state.players[0].active_pokemon = arceus_slot
	state.players[0].deck.append(CardInstance.create(filler_cd, 0))

	var snapshot: Dictionary = ScenarioStateSnapshotScript.capture(state)
	var restore_result: Dictionary = ScenarioStateRestorerScript.restore(snapshot)
	var gsm: GameStateMachine = restore_result.get("gsm", null)
	var restored_slot: PokemonSlot = null if gsm == null or gsm.game_state == null else gsm.game_state.players[0].active_pokemon
	var can_use_starbirth := gsm != null and restored_slot != null and gsm.effect_processor.can_use_ability(restored_slot, gsm.game_state, 0)

	return run_checks([
		assert_eq(restore_result.get("errors", []).size(), 0, "Restore should succeed for the Arceus VSTAR ability fixture"),
		assert_not_null(restored_slot, "Restore should rebuild the Arceus VSTAR active slot"),
		assert_true(can_use_starbirth, "Restore should re-register Pokemon effects so native abilities like Starbirth remain usable"),
	])


func test_apply_hidden_zone_override_replaces_hand_and_deck_from_snapshot() -> String:
	var snapshot: Dictionary = ScenarioStateSnapshotScript.capture(_make_game_state())
	var restore_result: Dictionary = ScenarioStateRestorerScript.restore(snapshot)
	var gsm: GameStateMachine = restore_result.get("gsm", null)
	if gsm == null or gsm.game_state == null:
		return "Expected restored GameStateMachine for hidden-zone override fixture"
	var override_players := [
		{
			"player_index": 0,
			"hand": [
				{
					"card_name": "Nest Ball",
					"name": "Nest Ball Local",
					"set_code": "CSVH1C",
					"card_index": "043",
					"instance_id": 8001,
					"card_type": "Trainer",
					"face_up": true,
					"owner_index": 0,
				}
			],
			"deck": [
				{
					"card_name": "Nest Ball",
					"name": "Nest Ball Deck",
					"set_code": "CSVH1C",
					"card_index": "043",
					"instance_id": 8002,
					"card_type": "Trainer",
					"face_up": false,
					"owner_index": 0,
				}
			],
			"shuffle_count": 7,
		}
	]
	var errors: Array[String] = ScenarioStateRestorerScript.apply_hidden_zone_override(gsm.game_state, override_players)
	var player: PlayerState = gsm.game_state.players[0]
	return run_checks([
		assert_true(errors.is_empty(), "Hidden-zone override should apply without validation errors"),
		assert_eq(player.hand.size(), 1, "Hidden-zone override should replace the player's hand"),
		assert_eq(player.deck.size(), 1, "Hidden-zone override should replace the player's deck"),
		assert_eq(str(player.hand[0].card_data.name_en), "Nest Ball", "Hidden-zone override should rebuild hand card metadata"),
		assert_eq(str(player.deck[0].card_data.name_en), "Nest Ball", "Hidden-zone override should rebuild deck card metadata"),
		assert_eq(player.shuffle_count, 7, "Hidden-zone override should restore the recorded shuffle_count"),
	])


func _energy_signature(slot: PokemonSlot) -> Dictionary:
	var counts := {}
	if slot == null:
		return counts
	for energy: CardInstance in slot.attached_energy:
		var energy_type := energy.card_data.energy_provides if energy != null and energy.card_data != null else ""
		counts[energy_type] = int(counts.get(energy_type, 0)) + 1
	return counts


func _make_game_state() -> GameState:
	return ScenarioStateSnapshotTestScript.new()._make_game_state()
