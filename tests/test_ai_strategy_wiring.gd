class_name TestAIStrategyWiring
extends TestBase


const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")
const AIStepResolverScript = preload("res://scripts/ai/AIStepResolver.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DeckStrategyGardevoirScript = preload("res://scripts/ai/DeckStrategyGardevoir.gd")
const DeckStrategyMiraidonScript = preload("res://scripts/ai/DeckStrategyMiraidon.gd")
const GardevoirStateEncoderScript = preload("res://scripts/ai/GardevoirStateEncoder.gd")
const AIHeuristicsScript = preload("res://scripts/ai/AIHeuristics.gd")


class FixedAttachAuthorityStrategy extends RefCounted:
	func score_action(action: Dictionary, _context: Dictionary) -> float:
		match str(action.get("kind", "")):
			"attach_energy":
				return 17.0
			"attach_tool":
				return 11.0
		return 0.0


class FixedHandoffAuthorityStrategy extends RefCounted:
	func score_handoff_target(item: Variant, step: Dictionary, _context: Dictionary = {}) -> float:
		if not (item is String):
			return 0.0
		if str(step.get("id", "")) in ["send_out", "self_switch_target", "own_bench_target"] and str(item) == "ready_attacker":
			return 100.0
		return 0.0

	func pick_interaction_items(items: Array, step: Dictionary, _context: Dictionary = {}) -> Array:
		if str(step.get("id", "")) != "own_bench_target":
			return []
		for item: Variant in items:
			if str(item) == "ready_attacker":
				return [item]
		return []

	func score_interaction_target(item: Variant, _step: Dictionary, _context: Dictionary = {}) -> float:
		if item is String and str(item) == "bench_engine":
			return 150.0
		return 0.0


class LegacyInteractionAuthorityStrategy extends RefCounted:
	func score_interaction_target(item: Variant, step: Dictionary, _context: Dictionary = {}) -> float:
		if not (item is String):
			return 0.0
		if str(step.get("id", "")) == "self_switch_target" and str(item) == "ready_attacker":
			return 100.0
		if str(item) == "bench_engine":
			return 10.0
		return 0.0


func _make_manual_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	return gsm


func _make_pokemon_cd(name: String, energy_type: String = "P") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.energy_type = energy_type
	cd.hp = 100
	return cd


func _make_item_cd(name: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Item"
	return cd


func _make_deck(deck_id: int, deck_name: String, signature_name: String) -> DeckData:
	var deck := DeckData.new()
	deck.id = deck_id
	deck.deck_name = deck_name
	deck.total_cards = 60
	deck.cards = [{
		"name": signature_name,
		"name_en": signature_name,
		"card_type": "Pokemon",
		"count": 1,
	}]
	return deck


func test_ai_opponent_set_deck_strategy_syncs_all_strategy_dependents() -> String:
	var ai = AIOpponentScript.new()
	var strategy = DeckStrategyMiraidonScript.new()
	if not ai.has_method("set_deck_strategy"):
		return "AIOpponent should expose set_deck_strategy() for centralized strategy wiring"
	ai.call("set_deck_strategy", strategy)
	return run_checks([
		assert_true(ai._deck_strategy == strategy, "AIOpponent should keep the injected strategy as the shared active strategy"),
		assert_true(ai._step_resolver.deck_strategy == strategy, "Step resolver should share the same injected strategy instance"),
		assert_true(ai._legal_action_builder._deck_strategy == strategy, "Legal action builder should share the same injected strategy instance"),
		assert_true(ai._mcts_planner.deck_strategy == strategy, "MCTS planner should share the same injected strategy instance"),
		assert_eq(ai._mcts_planner.state_encoder_class, strategy.get_state_encoder_class(), "MCTS planner should use the injected strategy encoder class"),
		assert_true(ai._heuristics.get("deck_strategy") == strategy if ai._heuristics is Object else false, "Heuristics should receive the injected strategy instance"),
	])


func test_registry_can_resolve_strategy_directly_from_deck_data() -> String:
	var registry = DeckStrategyRegistryScript.new()
	if not registry.has_method("resolve_strategy_for_deck"):
		return "DeckStrategyRegistry should expose resolve_strategy_for_deck() so live battle and benchmark entry points can share one deck-resolution path"
	var strategy = registry.call("resolve_strategy_for_deck", _make_deck(575720, "miraidon", "密勒顿ex"))
	return run_checks([
		assert_not_null(strategy, "Registry should resolve a strategy directly from deck data"),
		assert_eq(str(strategy.call("get_strategy_id")), "miraidon", "Miraidon deck data should resolve to the Miraidon strategy"),
	])


func test_gardevoir_search_item_headless_matches_resolver_scoring() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	player.active_pokemon = PokemonSlot.new()
	player.active_pokemon.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Lead"), 0))
	player.bench.append(PokemonSlot.new())
	player.bench[0].pokemon_stack.append(CardInstance.create(_make_pokemon_cd("奇鲁莉安"), 0))
	var builder = AILegalActionBuilderScript.new()
	var resolver = AIStepResolverScript.new()
	var strategy = DeckStrategyGardevoirScript.new()
	builder._deck_strategy = strategy
	builder._deck_strategy_detected = true
	resolver.deck_strategy = strategy

	var potion := CardInstance.create(_make_item_cd("Potion"), 0)
	var nest_ball := CardInstance.create(_make_item_cd("巢穴球"), 0)
	var ultra_ball := CardInstance.create(_make_item_cd("高级球"), 0)
	var step := {
		"id": "search_item",
		"items": [potion, nest_ball, ultra_ball],
		"min_select": 1,
		"max_select": 1,
	}

	var headless_result: Dictionary = builder._resolve_headless_step(gsm, 0, 0, step)
	var headless_items: Array = headless_result.get("search_item", [])
	var headless_pick: Variant = null if headless_items.is_empty() else headless_items[0]
	var resolver_index: int = resolver._best_legal_target_index(step.get("items", []), [], step)
	var resolver_pick: Variant = null if resolver_index < 0 else step["items"][resolver_index]

	return run_checks([
		assert_not_null(headless_pick, "Headless builder should synthesize a search_item target"),
		assert_not_null(resolver_pick, "Resolver path should select a search_item target"),
		assert_eq(
			"" if headless_pick == null else str((headless_pick as CardInstance).card_data.name),
			"" if resolver_pick == null else str((resolver_pick as CardInstance).card_data.name),
			"Headless builder and resolver should agree on Gardevoir search_item target selection"
		),
	])


func test_decision_trace_uses_strategy_state_encoder() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	player.active_pokemon = PokemonSlot.new()
	player.active_pokemon.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Lead"), 0))
	player.bench.append(PokemonSlot.new())
	player.bench[0].pokemon_stack.append(CardInstance.create(_make_pokemon_cd("奇鲁莉安"), 0))

	var ai = AIOpponentScript.new()
	ai.player_index = 0
	var strategy = DeckStrategyGardevoirScript.new()
	ai.call("set_deck_strategy", strategy)
	ai._record_decision_trace_from_choice(gsm, [], [], {}, false)

	var trace = ai.get_last_decision_trace()
	var expected_features: Array[float] = GardevoirStateEncoderScript.encode(gsm.game_state, 0)
	return run_checks([
		assert_not_null(trace, "Decision trace should be recorded"),
		assert_eq(trace.state_features.size(), expected_features.size(),
			"Decision traces should use the strategy-selected state encoder dimensions"),
	])


func test_injected_strategy_fully_controls_attach_and_tool_scores() -> String:
	var heuristics = AIHeuristicsScript.new()
	heuristics.deck_strategy = FixedAttachAuthorityStrategy.new()

	var active_attach_action := {"kind": "attach_energy"}
	var bench_attach_action := {"kind": "attach_energy"}
	var tool_attach_action := {"kind": "attach_tool"}

	var active_score: float = heuristics.score_action(active_attach_action, {
		"features": {
			"is_active_target": true,
			"is_bench_target": false,
			"improves_attack_readiness": true,
			"productive": true,
		},
	})
	var bench_score: float = heuristics.score_action(bench_attach_action, {
		"features": {
			"is_active_target": false,
			"is_bench_target": true,
			"improves_attack_readiness": false,
			"productive": true,
		},
	})
	var tool_score: float = heuristics.score_action(tool_attach_action, {
		"features": {
			"is_active_target": true,
			"is_bench_target": false,
			"productive": true,
		},
	})

	return run_checks([
		assert_eq(active_score, 17.0, "Injected strategy should own attach_energy scoring without generic active bonuses"),
		assert_eq(bench_score, 17.0, "Injected strategy should own attach_energy scoring without generic bench bonuses"),
		assert_eq(tool_score, 11.0, "Injected strategy should own attach_tool scoring without generic tool bonuses"),
	])


func test_greedy_combo_bias_can_prefer_setup_chain_over_isolated_attack_peak() -> String:
	var ai = AIOpponentScript.new()
	if not ai.has_method("_pick_best_scored_absolute"):
		return "AIOpponent should expose combo-aware scored absolute selection before shared greedy planning can improve"
	var best: Dictionary = ai._pick_best_scored_absolute([
		{"action": {"kind": "attack"}, "score": 200.0},
		{"action": {"kind": "play_trainer", "productive": true}, "score": 170.0},
		{"action": {"kind": "evolve", "productive": true}, "score": 165.0},
	])
	return assert_eq(str((best.get("action", {}) as Dictionary).get("kind", "")), "play_trainer",
		"Combo-aware greedy selection should be able to prefer a setup chain over a slightly higher isolated attack score")


func test_step_resolver_prefers_handoff_contract_for_switch_targets() -> String:
	var resolver = AIStepResolverScript.new()
	resolver.deck_strategy = FixedHandoffAuthorityStrategy.new()
	var best_index: int = resolver._best_legal_target_index(
		["bench_engine", "ready_attacker"],
		[],
		{"id": "self_switch_target"},
		{}
	)
	return assert_eq(best_index, 1,
		"Step resolver should route switch-like handoff targets through score_handoff_target before generic interaction scoring")


func test_headless_builder_uses_explicit_strategy_pick_for_own_bench_target() -> String:
	var gsm := _make_manual_gsm()
	var builder = AILegalActionBuilderScript.new()
	builder._deck_strategy = FixedHandoffAuthorityStrategy.new()
	builder._deck_strategy_detected = true
	var selected: Array = builder._select_headless_items(
		gsm,
		0,
		0,
		{"id": "own_bench_target"},
		["bench_engine", "ready_attacker"],
		1,
		{}
	)
	var picked: String = "" if selected.is_empty() else str(selected[0])
	return assert_eq(picked, "ready_attacker",
		"Headless interaction previews should honor explicit deck-local own_bench_target picks instead of defaulting to the first bench option")


func test_step_resolver_falls_back_to_legacy_interaction_scoring_for_handoff_targets() -> String:
	var resolver = AIStepResolverScript.new()
	resolver.deck_strategy = LegacyInteractionAuthorityStrategy.new()
	var best_index: int = resolver._best_legal_target_index(
		["bench_engine", "ready_attacker"],
		[],
		{"id": "self_switch_target"},
		{}
	)
	return assert_eq(best_index, 1,
		"Step resolver should keep using score_interaction_target for handoff targets when a legacy strategy does not implement score_handoff_target")
