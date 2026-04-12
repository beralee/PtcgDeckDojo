class_name TestAIBenchmark
extends TestBase

const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")


class RiggedCoinFlipper extends CoinFlipper:
	var _results: Array[bool] = []

	func _init(results: Array[bool]) -> void:
		_results = results.duplicate()

	func flip() -> bool:
		var result: bool = _results.pop_front() if not _results.is_empty() else false
		coin_flipped.emit(result)
		return result


class StepRunnerSpy extends RefCounted:
	var calls: int = 0
	var winner_after_calls: int = -1

	func run(_passed_agent: Variant, _state: Dictionary) -> Dictionary:
		calls += 1
		if winner_after_calls > 0 and calls >= winner_after_calls:
			return {"winner_index": 1}
		return {}


class RawSchemaStepRunnerSpy extends RefCounted:
	var calls: int = 0
	var winner_after_calls: int = 2

	func run(_passed_agent: Variant, _state: Dictionary) -> Dictionary:
		calls += 1
		if calls < winner_after_calls:
			return {
				"deck_a": {},
				"deck_b": {},
				"seed": -1,
				"winner_index": -1,
				"turn_count": 0,
				"steps": calls,
				"terminated_by_cap": false,
				"stalled": false,
				"failure_reason": "",
				"event_counters": {},
				"identity_hits": {},
			}
		return {
			"deck_a": {},
			"deck_b": {},
			"seed": -1,
			"winner_index": 1,
			"turn_count": 0,
			"steps": calls,
			"terminated_by_cap": false,
			"stalled": false,
			"failure_reason": "",
			"event_counters": {},
			"identity_hits": {},
		}


class MulliganBootstrapSpyGameStateMachine extends GameStateMachine:
	var resolve_mulligan_choice_calls: int = 0

	func resolve_mulligan_choice(beneficiary: int, draw_extra: bool) -> void:
		resolve_mulligan_choice_calls += 1
		super.resolve_mulligan_choice(beneficiary, draw_extra)


class UnsupportedPromptSignalSpyAI extends AIOpponent:
	var emitted_prompts: int = 0

	func run_single_step(_battle_scene: Control, gsm: GameStateMachine) -> bool:
		emitted_prompts += 1
		if gsm != null:
			gsm.player_choice_required.emit("unsupported_prompt", {
				"reason": "unsupported",
				"player": player_index,
			})
		return true


class EffectInteractionSignalSpyAI extends AIOpponent:
	var emitted_prompts: int = 0

	func run_single_step(_battle_scene: Control, gsm: GameStateMachine) -> bool:
		emitted_prompts += 1
		if gsm != null:
			gsm.player_choice_required.emit("effect_interaction", {
				"chooser_player_index": player_index,
				"player": player_index,
				"opponent_chooses": false,
			})
		return true


class UnsupportedInteractiveStepAI extends AIOpponent:
	var legal_action_calls: int = 0

	func get_legal_actions(_gsm: GameStateMachine) -> Array[Dictionary]:
		legal_action_calls += 1
		return [
			{
				"kind": "play_trainer",
				"requires_interaction": true,
			}
		]

	func run_single_step(_battle_scene: Control, _gsm: GameStateMachine) -> bool:
		return false


class HeavyBatonPromptResolveSpyGameStateMachine extends GameStateMachine:
	var resolve_heavy_baton_choice_calls: int = 0
	var resolved_heavy_baton_player_index: int = -1
	var resolved_heavy_baton_target: PokemonSlot = null

	func resolve_heavy_baton_choice(player_index: int, bench_slot: PokemonSlot) -> bool:
		resolve_heavy_baton_choice_calls += 1
		resolved_heavy_baton_player_index = player_index
		resolved_heavy_baton_target = bench_slot
		game_state.phase = GameState.GamePhase.GAME_OVER
		game_state.winner_index = player_index
		return true


class HeavyBatonSignalSpyAI extends AIOpponent:
	var emitted_prompts: int = 0
	var resolved_prompts: int = 0

	func run_single_step(battle_scene: Control, gsm: GameStateMachine) -> bool:
		if str(battle_scene.get("_pending_choice")) == "heavy_baton_target":
			resolved_prompts += 1
			return super.run_single_step(battle_scene, gsm)
		emitted_prompts += 1
		if gsm != null and gsm.game_state != null and player_index >= 0 and player_index < gsm.game_state.players.size():
			gsm.player_choice_required.emit("heavy_baton_target", {
				"player": player_index,
				"bench": gsm.game_state.players[player_index].bench.duplicate(),
				"count": 3,
				"source_name": "Heavy Baton",
			})
		return true


func _make_benchmark_basic(name: String, hp: int = 60, attacks: Array = []) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	card.attacks.clear()
	for attack: Dictionary in attacks:
		card.attacks.append(attack.duplicate(true))
	return CardInstance.create(card, 0)


func _make_benchmark_filler(name: String) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Item"
	return CardInstance.create(card, 0)


func _make_benchmark_slot(card: CardInstance) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	return slot


func _make_real_smoke_deck(deck_name: String) -> DeckData:
	var deck := DeckData.new()
	deck.id = 999000 + int(abs(hash(deck_name)) % 1000)
	deck.deck_name = deck_name
	deck.total_cards = 60
	deck.cards = [
		{
			"set_code": "CSV7C",
			"card_index": "161",
			"count": 30,
			"card_type": "Pokemon",
			"name": "Smoke Dragon",
		},
		{
			"set_code": "CSVE1C",
			"card_index": "LIG",
			"count": 30,
			"card_type": "Basic Energy",
			"name": "Basic Lightning Energy",
		},
	]
	return deck


func _make_headless_smoke_gsm() -> GameStateMachine:
	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 1
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	var attack := {"name": "Bench Breaker", "cost": "", "damage": "120", "text": "", "is_vstar_power": false}
	gsm.game_state.players[0].active_pokemon = _make_benchmark_slot(_make_benchmark_basic("P0 Active", 70, [attack]))
	gsm.game_state.players[0].bench = [_make_benchmark_slot(_make_benchmark_basic("P0 Bench", 70, [attack]))]
	gsm.game_state.players[1].active_pokemon = _make_benchmark_slot(_make_benchmark_basic("P1 Active", 70, [attack]))
	gsm.game_state.players[1].bench = [_make_benchmark_slot(_make_benchmark_basic("P1 Bench", 70, [attack]))]
	gsm.game_state.players[0].set_prizes([
		_make_benchmark_filler("P0 Prize 1"),
		_make_benchmark_filler("P0 Prize 2"),
	])
	gsm.game_state.players[1].set_prizes([
		_make_benchmark_filler("P1 Prize 1"),
		_make_benchmark_filler("P1 Prize 2"),
	])
	gsm.game_state.players[0].deck = [
		_make_benchmark_filler("P0 Deck 1"),
		_make_benchmark_filler("P0 Deck 2"),
	]
	gsm.game_state.players[1].deck = [
		_make_benchmark_filler("P1 Deck 1"),
		_make_benchmark_filler("P1 Deck 2"),
	]
	return gsm


func _make_headless_mulligan_bootstrap_gsm() -> MulliganBootstrapSpyGameStateMachine:
	CardInstance.reset_id_counter()
	var gsm := MulliganBootstrapSpyGameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 1
	gsm.game_state.turn_number = 0
	gsm.game_state.players[0].active_pokemon = null
	gsm.game_state.players[1].active_pokemon = null
	gsm.game_state.players[0].bench = []
	gsm.game_state.players[1].bench = []
	gsm.game_state.players[0].deck = [
		_make_benchmark_filler("P0 Deck 1"),
		_make_benchmark_filler("P0 Deck 2"),
	]
	gsm.game_state.players[1].deck = [
		_make_benchmark_filler("P1 Deck 1"),
		_make_benchmark_filler("P1 Deck 2"),
	]
	gsm.game_state.players[0].set_prizes([
		_make_benchmark_filler("P0 Prize 1"),
	])
	gsm.game_state.players[1].set_prizes([
		_make_benchmark_filler("P1 Prize 1"),
	])
	var attack := {"name": "Bench Breaker", "cost": "", "damage": "120", "text": "", "is_vstar_power": false}
	gsm.action_log.clear()
	gsm.action_log.append(GameAction.create(GameAction.ActionType.MULLIGAN, 0, {}, 0, "Seeded missed mulligan prompt"))
	gsm.game_state.players[0].hand = [
		_make_benchmark_basic("P0 Basic", 60, [attack]),
	]
	gsm.game_state.players[1].hand = [
		_make_benchmark_basic("P1 Basic", 60, [attack]),
	]
	return gsm


func test_benchmark_runner_aggregates_match_results() -> String:
	var runner = AIBenchmarkRunnerScript.new()
	var agent = AIOpponentScript.new()
	var summary: Dictionary = runner.run_fixed_match_set(agent, [
		{"tracked_player_index": 1, "result": {"winner_index": 1}},
		{"tracked_player_index": 1, "result": {"winner_index": 0}},
		{"tracked_player_index": 1, "result": {"winner_index": 1}},
	])
	return run_checks([
		assert_eq(summary.get("total_matches", -1), 3, "Benchmark runner should report the total number of matchups"),
		assert_eq(summary.get("wins", -1), 2, "Benchmark runner should count wins for the tracked player"),
		assert_eq(summary.get("win_rate", -1.0), 2.0 / 3.0, "Benchmark runner should derive a deterministic win_rate"),
	])


func test_benchmark_runner_accepts_callable_match_executors() -> String:
	var runner = AIBenchmarkRunnerScript.new()
	var agent = AIOpponentScript.new()
	var fixed_runner := func(_passed_agent: Variant, matchup: Dictionary) -> Dictionary:
		return matchup.get("result", {})
	var summary: Dictionary = runner.run_fixed_match_set(agent, [
		{
			"tracked_player_index": 1,
			"runner": fixed_runner,
			"result": {"winner_index": 1},
		},
		{
			"tracked_player_index": 1,
			"runner": fixed_runner,
			"result": {"winner_index": 1},
		},
	])
	return run_checks([
		assert_eq(summary.get("total_matches", -1), 2, "Callable-driven matchups should still contribute to total_matches"),
		assert_eq(summary.get("wins", -1), 2, "Callable-driven matchups should be aggregated the same way as fixed results"),
		assert_eq(summary.get("win_rate", -1.0), 1.0, "All-win callable matchups should yield a 1.0 win rate"),
	])


func test_benchmark_runner_smoke_match_stops_on_terminal_result() -> String:
	var runner = AIBenchmarkRunnerScript.new()
	var agent = AIOpponentScript.new()
	var spy := StepRunnerSpy.new()
	spy.winner_after_calls = 3
	var result: Dictionary = runner.run_smoke_match(agent, spy.run, 6)
	return run_checks([
		assert_eq(spy.calls, 3, "Smoke match should keep stepping until the runner returns a terminal result"),
		assert_eq(result.get("winner_index", -1), 1, "Terminal smoke-match results should be returned unchanged"),
		assert_eq(result.get("steps", -1), 3, "Smoke match should report how many step iterations were consumed"),
		assert_false(bool(result.get("terminated_by_cap", true)), "A naturally completed smoke match should not report an action-cap termination"),
	])


func test_benchmark_runner_smoke_match_reports_action_cap_termination() -> String:
	var runner = AIBenchmarkRunnerScript.new()
	var agent = AIOpponentScript.new()
	var spy := StepRunnerSpy.new()
	var result: Dictionary = runner.run_smoke_match(agent, spy.run, 4)
	return run_checks([
		assert_eq(spy.calls, 4, "Smoke match should stop once it hits the configured action cap"),
		assert_eq(result.get("winner_index", 99), -1, "Action-cap termination should return a sentinel non-terminal winner index"),
		assert_eq(result.get("steps", -1), 4, "Action-cap termination should report the consumed step count"),
		assert_true(bool(result.get("terminated_by_cap", false)), "Action-cap termination should be marked explicitly"),
		assert_eq(result.get("deck_a", null), {}, "Smoke match cap results should include deck_a"),
		assert_eq(result.get("deck_b", null), {}, "Smoke match cap results should include deck_b"),
		assert_eq(result.get("seed", -2), -1, "Smoke match cap results should include the seed field"),
		assert_eq(result.get("turn_count", -1), 0, "Smoke match cap results should include turn_count"),
		assert_false(bool(result.get("stalled", true)), "Smoke match cap results should not mark the match stalled"),
		assert_eq(result.get("failure_reason", ""), "action_cap_reached", "Smoke match cap results should carry the cap failure reason"),
		assert_true(result.has("event_counters"), "Smoke match cap results should include event_counters"),
		assert_true(result.has("identity_hits"), "Smoke match cap results should include identity_hits"),
	])


func test_benchmark_runner_smoke_match_returns_raw_contract_for_terminal_result() -> String:
	var runner = AIBenchmarkRunnerScript.new()
	var agent = AIOpponentScript.new()
	var spy := StepRunnerSpy.new()
	spy.winner_after_calls = 2
	var result: Dictionary = runner.run_smoke_match(agent, spy.run, 5)
	return run_checks([
		assert_eq(spy.calls, 2, "Smoke match should stop once the runner returns a terminal result"),
		assert_eq(result.get("deck_a", null), {}, "Smoke match terminal results should include deck_a"),
		assert_eq(result.get("deck_b", null), {}, "Smoke match terminal results should include deck_b"),
		assert_eq(result.get("seed", -2), -1, "Smoke match terminal results should include the seed field"),
		assert_eq(result.get("winner_index", -1), 1, "Smoke match terminal results should preserve the winner"),
		assert_eq(result.get("turn_count", -1), 0, "Smoke match terminal results should include turn_count"),
		assert_false(bool(result.get("terminated_by_cap", true)), "Smoke match terminal results should not report action-cap termination"),
		assert_false(bool(result.get("stalled", true)), "Smoke match terminal results should not report stalling"),
		assert_eq(result.get("failure_reason", ""), "", "Smoke match terminal results should keep the default failure_reason"),
		assert_true(result.has("event_counters"), "Smoke match terminal results should include event_counters"),
		assert_true(result.has("identity_hits"), "Smoke match terminal results should include identity_hits"),
	])


func test_benchmark_runner_treats_raw_schema_non_terminal_smoke_result_as_non_terminal() -> String:
	var runner := AIBenchmarkRunnerScript.new()
	var agent := AIOpponentScript.new()
	var spy := RawSchemaStepRunnerSpy.new()
	spy.winner_after_calls = 2
	var result: Dictionary = runner.run_smoke_match(agent, spy.run, 5)
	return run_checks([
		assert_eq(spy.calls, 2, "Smoke match should keep stepping past a raw-schema-shaped non-terminal result"),
		assert_eq(result.get("winner_index", -1), 1, "Smoke match should return the later terminal winner"),
		assert_eq(result.get("steps", -1), 2, "Smoke match should report the final step count"),
		assert_false(bool(result.get("terminated_by_cap", true)), "Completed smoke matches should not report cap termination"),
	])


func test_ai_benchmark_runner_returns_stalled_no_progress_reason() -> String:
	var runner := AIBenchmarkRunnerScript.new()
	var gsm := _make_headless_smoke_gsm()
	gsm.game_state.turn_number = 11
	var result: Dictionary = runner._make_failed_match_result("stalled_no_progress", 7, gsm)
	return run_checks([
		assert_eq(result.get("failure_reason", ""), "stalled_no_progress", "Runner should emit a stable failure reason"),
		assert_eq(result.get("steps", -1), 7, "Runner should preserve step count"),
		assert_eq(result.get("turn_count", -1), 11, "Runner should preserve the current turn count when available"),
	])


func test_benchmark_runner_returns_raw_contract_for_successful_duel() -> String:
	var runner := AIBenchmarkRunnerScript.new()
	var player_0_ai := AIOpponentScript.new()
	player_0_ai.configure(0, 1)
	var player_1_ai := AIOpponentScript.new()
	player_1_ai.configure(1, 1)
	var gsm := _make_headless_smoke_gsm()
	gsm.game_state.phase = GameState.GamePhase.GAME_OVER
	gsm.game_state.winner_index = 0
	gsm.game_state.turn_number = 9
	var result: Dictionary = runner.run_headless_duel(player_0_ai, player_1_ai, gsm, 5)
	return run_checks([
		assert_eq(result.get("deck_a", null), {}, "Successful raw match results should include deck_a"),
		assert_eq(result.get("deck_b", null), {}, "Successful raw match results should include deck_b"),
		assert_eq(result.get("seed", -2), -1, "Successful raw match results should include the seed field"),
		assert_eq(result.get("winner_index", -1), 0, "Successful raw match results should preserve the winner"),
		assert_eq(result.get("turn_count", -1), 9, "Successful raw match results should preserve the current turn count"),
		assert_eq(result.get("failure_reason", ""), "normal_game_end", "Successful raw match results should classify normal game end"),
		assert_true(result.has("event_counters"), "Successful raw match results should include event_counters"),
		assert_true(result.has("identity_hits"), "Successful raw match results should include identity_hits"),
		assert_false(bool(result.get("terminated_by_cap", true)), "Successful raw match results should not report action-cap termination"),
		assert_false(bool(result.get("stalled", true)), "Successful raw match results should not report stalling"),
	])


func test_benchmark_runner_marks_deck_out_success_reason() -> String:
	var runner := AIBenchmarkRunnerScript.new()
	var player_0_ai := AIOpponentScript.new()
	player_0_ai.configure(0, 1)
	var player_1_ai := AIOpponentScript.new()
	player_1_ai.configure(1, 1)
	var gsm := _make_headless_smoke_gsm()
	gsm.game_state.phase = GameState.GamePhase.GAME_OVER
	gsm.game_state.winner_index = 1
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 13
	gsm.game_state.players[0].deck.clear()
	gsm.game_state.players[1].deck = [_make_benchmark_filler("Winner Deck")]
	var result: Dictionary = runner.run_headless_duel(player_0_ai, player_1_ai, gsm, 5)
	return run_checks([
		assert_eq(result.get("failure_reason", ""), "deck_out", "Deck-out victories should be classified explicitly"),
	])


func test_benchmark_runner_classifies_unsupported_prompt_from_signal_path() -> String:
	var runner := AIBenchmarkRunnerScript.new()
	var player_0_ai := UnsupportedPromptSignalSpyAI.new()
	player_0_ai.configure(0, 1)
	var player_1_ai := AIOpponentScript.new()
	player_1_ai.configure(1, 1)
	var gsm := _make_headless_smoke_gsm()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	var result: Dictionary = runner.run_headless_duel(player_0_ai, player_1_ai, gsm, 5)
	return run_checks([
		assert_eq(player_0_ai.emitted_prompts, 1, "The synthetic AI should emit exactly one unsupported prompt through the game-state signal"),
		assert_eq(result.get("failure_reason", ""), "unsupported_prompt", "The runner should classify an unsupported prompt from the real signal path"),
		assert_eq(result.get("steps", -1), 2, "The unsupported prompt should be detected on the following loop iteration"),
	])


func test_benchmark_runner_classifies_unsupported_interactive_step_from_legal_actions() -> String:
	var runner := AIBenchmarkRunnerScript.new()
	var player_0_ai := UnsupportedInteractiveStepAI.new()
	player_0_ai.configure(0, 1)
	var player_1_ai := AIOpponentScript.new()
	player_1_ai.configure(1, 1)
	var gsm := _make_headless_smoke_gsm()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	var result: Dictionary = runner.run_headless_duel(player_0_ai, player_1_ai, gsm, 5)
	return run_checks([
		assert_eq(player_0_ai.legal_action_calls, 1, "The runner should inspect legal actions before classifying the failed step"),
		assert_eq(result.get("failure_reason", ""), "unsupported_interaction_step", "Interactive steps that cannot run headlessly should be classified explicitly"),
		assert_eq(result.get("steps", -1), 1, "The unsupported interaction should fail on the first turn step"),
	])


func test_benchmark_runner_handles_effect_interaction_prompt_from_signal_path() -> String:
	var runner := AIBenchmarkRunnerScript.new()
	var player_0_ai := EffectInteractionSignalSpyAI.new()
	player_0_ai.configure(0, 1)
	var player_1_ai := AIOpponentScript.new()
	player_1_ai.configure(1, 1)
	var gsm := _make_headless_smoke_gsm()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	var result: Dictionary = runner.run_headless_duel(player_0_ai, player_1_ai, gsm, 5)
	## HeadlessMatchBridge 现在支持效果交互，信号路径的 effect_interaction 会被尝试解决
	## 由于 spy AI 不断发射信号，最终因步数上限结束
	return run_checks([
		assert_true(player_0_ai.emitted_prompts > 0, "spy AI 应至少发射一次 effect_interaction 信号"),
		assert_true(result.get("failure_reason", "") != "", "由于 spy AI 循环发射信号，对局应以某种失败原因结束"),
	])


func test_headless_bridge_can_drive_random_start_game_setup_to_main_phase() -> String:
	var bridge = HeadlessMatchBridgeScript.new()
	var player_0_ai = AIOpponentScript.new()
	player_0_ai.configure(0, 1)
	var player_1_ai = AIOpponentScript.new()
	player_1_ai.configure(1, 1)
	var gsm := GameStateMachine.new()
	gsm.coin_flipper = RiggedCoinFlipper.new([false])
	bridge.bind(gsm)
	gsm.start_game(_make_real_smoke_deck("Smoke A"), _make_real_smoke_deck("Smoke B"), -1)

	var steps: int = 0
	var progressed: bool = true
	while gsm.game_state.phase == GameState.GamePhase.SETUP and steps < 20 and progressed:
		progressed = false
		if bridge.has_pending_prompt():
			if bridge.can_resolve_pending_prompt():
				progressed = bridge.resolve_pending_prompt()
			else:
				var owner: int = bridge.get_pending_prompt_owner()
				if owner == 0:
					progressed = player_0_ai.run_single_step(bridge, gsm)
				elif owner == 1:
					progressed = player_1_ai.run_single_step(bridge, gsm)
		else:
			var current_player: int = gsm.game_state.current_player_index
			progressed = player_0_ai.run_single_step(bridge, gsm) if current_player == 0 else player_1_ai.run_single_step(bridge, gsm)
		steps += 1

	return run_checks([
		assert_eq(gsm.game_state.first_player_index, 1, "Random first-player setup should honor the coin flip result"),
		assert_eq(gsm.game_state.phase, GameState.GamePhase.MAIN, "Headless setup smoke should advance out of SETUP into MAIN"),
		assert_not_null(gsm.game_state.players[0].active_pokemon, "Player 0 should have an active Pokemon after setup"),
		assert_not_null(gsm.game_state.players[1].active_pokemon, "Player 1 should have an active Pokemon after setup"),
	])


func test_benchmark_runner_recovers_mulligan_bootstrap_before_setup() -> String:
	var runner = AIBenchmarkRunnerScript.new()
	var player_0_ai = AIOpponentScript.new()
	player_0_ai.configure(0, 1)
	var player_1_ai = AIOpponentScript.new()
	player_1_ai.configure(1, 1)
	var gsm := _make_headless_mulligan_bootstrap_gsm()
	var result: Dictionary = runner.run_headless_duel(player_0_ai, player_1_ai, gsm, 40)
	return run_checks([
		assert_gte(gsm.resolve_mulligan_choice_calls, 1, "Headless bootstrap should recover the missed mulligan prompt before setup starts"),
		assert_false(bool(result.get("stalled", true)), "A bootstrap-recovered mulligan should not stall the duel"),
		assert_false(bool(result.get("terminated_by_cap", true)), "A bootstrap-recovered mulligan should finish before the action cap"),
	])


func test_benchmark_runner_can_finish_start_game_duel_with_real_setup_flow() -> String:
	var runner = AIBenchmarkRunnerScript.new()
	var player_0_ai = AIOpponentScript.new()
	player_0_ai.configure(0, 1)
	var player_1_ai = AIOpponentScript.new()
	player_1_ai.configure(1, 1)
	var gsm := GameStateMachine.new()
	gsm.start_game(_make_real_smoke_deck("Smoke Duel A"), _make_real_smoke_deck("Smoke Duel B"), 0)
	var result: Dictionary = runner.run_headless_duel(player_0_ai, player_1_ai, gsm, 160)

	return run_checks([
		assert_false(bool(result.get("stalled", true)), "A real start_game smoke duel should not stall during setup or turn flow"),
		assert_false(bool(result.get("terminated_by_cap", true)), "A real start_game smoke duel should finish before the action cap"),
		assert_true(int(result.get("winner_index", -1)) >= 0, "A real start_game smoke duel should eventually produce a winner"),
	])


func test_benchmark_runner_can_finish_real_headless_ai_duel() -> String:
	var runner = AIBenchmarkRunnerScript.new()
	var player_0_ai = AIOpponentScript.new()
	player_0_ai.configure(0, 1)
	var player_1_ai = AIOpponentScript.new()
	player_1_ai.configure(1, 1)
	var gsm := _make_headless_smoke_gsm()
	var result: Dictionary = runner.run_headless_duel(player_0_ai, player_1_ai, gsm, 20)
	var send_out_count: int = 0
	var prize_count: int = 0
	for action: GameAction in gsm.action_log:
		if action.action_type == GameAction.ActionType.SEND_OUT:
			send_out_count += 1
		if action.action_type == GameAction.ActionType.TAKE_PRIZE:
			prize_count += 1
	return run_checks([
		assert_eq(result.get("winner_index", -1), 0, "The first attacking AI should win the mirrored smoke duel"),
		assert_false(bool(result.get("terminated_by_cap", true)), "A real headless duel should terminate naturally instead of hitting the action cap"),
		assert_gte(send_out_count, 1, "The smoke duel should exercise the send_out_pokemon prompt path"),
		assert_gte(prize_count, 2, "The smoke duel should exercise prize taking before the winner is declared"),
	])


func test_make_benchmark_agent_applies_value_net_and_mcts_config() -> String:
	var runner = AIBenchmarkRunnerScript.new()
	var ai = runner.call("_make_benchmark_agent", 1, {
		"agent_id": "trained-ai",
		"version_tag": "candidate-v2",
		"mcts_config": {
			"branch_factor": 4,
			"rollouts_per_sequence": 8,
			"rollout_max_steps": 40,
			"time_budget_ms": 900,
		},
		"value_net_path": "user://ai_models/value_net_v2.json",
	}, "version_regression")
	return run_checks([
		assert_true(ai != null, "Benchmark runner should create an AI opponent from benchmark agent config"),
		assert_true(bool(ai.use_mcts), "Benchmark agent should enable MCTS when mcts_config is provided"),
		assert_eq(int(ai.mcts_config.get("branch_factor", 0)), 4, "Benchmark agent should copy MCTS config into the runtime AI"),
		assert_eq(str(ai.value_net_path), "user://ai_models/value_net_v2.json", "Benchmark agent should copy value_net_path into the runtime AI"),
	])


func test_benchmark_runner_routes_heavy_baton_prompt_through_ai_resolution() -> String:
	var runner := AIBenchmarkRunnerScript.new()
	var player_0_ai := HeavyBatonSignalSpyAI.new()
	player_0_ai.configure(0, 1)
	var player_1_ai := AIOpponentScript.new()
	player_1_ai.configure(1, 1)
	var gsm := HeavyBatonPromptResolveSpyGameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(_make_benchmark_basic("Bench A"))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(_make_benchmark_basic("Bench B"))
	bench_b.attached_energy.append(_make_benchmark_filler("Energy Anchor"))
	gsm.game_state.players[0].bench = [bench_a, bench_b]

	var result: Dictionary = runner.run_headless_duel(player_0_ai, player_1_ai, gsm, 5)
	return run_checks([
		assert_eq(player_0_ai.emitted_prompts, 1, "The synthetic AI should emit exactly one Heavy Baton prompt"),
		assert_eq(player_0_ai.resolved_prompts, 1, "The Heavy Baton prompt should be routed back through AI resolution"),
		assert_eq(gsm.resolve_heavy_baton_choice_calls, 1, "The bridge path should drive GameStateMachine.resolve_heavy_baton_choice"),
		assert_eq(gsm.resolved_heavy_baton_player_index, 0, "Heavy Baton resolution should preserve the prompt owner"),
		assert_eq(gsm.resolved_heavy_baton_target, bench_b, "AI should pick the more attack-ready Heavy Baton target"),
		assert_false(str(result.get("failure_reason", "")) == "unsupported_prompt", "Heavy Baton should no longer terminate as an unsupported prompt"),
	])
