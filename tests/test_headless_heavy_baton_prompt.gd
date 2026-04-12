class_name TestHeadlessHeavyBatonPrompt
extends TestBase

const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")


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


func _make_benchmark_basic(name: String) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 60
	return CardInstance.create(card, 0)


func _make_filler(name: String) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Item"
	return CardInstance.create(card, 0)


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
	bench_b.attached_energy.append(_make_filler("Energy Anchor"))
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
