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


class TurnPlanActionStrategy extends RefCounted:
	var last_turn_plan: Dictionary = {}

	func build_turn_plan(_game_state: GameState, _player_index: int, _context: Dictionary = {}) -> Dictionary:
		return {
			"id": "setup_shell",
			"preferred_kind": "evolve",
		}

	func score_action_absolute_with_plan(_action: Dictionary, _game_state: GameState, _player_index: int, turn_plan: Dictionary = {}) -> float:
		last_turn_plan = turn_plan.duplicate(true)
		return 100.0 if str(_action.get("kind", "")) == str(turn_plan.get("preferred_kind", "")) else 10.0


class TurnContractActionStrategy extends RefCounted:
	var last_turn_plan: Dictionary = {}

	func build_turn_contract(_game_state: GameState, _player_index: int, _context: Dictionary = {}) -> Dictionary:
		return {
			"id": "bridge_contract",
			"intent": "bridge_to_finisher",
			"preferred_kind": "evolve",
			"owner": {
				"turn_owner_name": "Arceus VSTAR",
				"bridge_target_name": "Giratina VSTAR",
				"pivot_target_name": "Arceus VSTAR",
			},
			"constraints": {
				"forbid_engine_churn": true,
			},
		}

	func score_action_absolute_with_plan(_action: Dictionary, _game_state: GameState, _player_index: int, turn_plan: Dictionary = {}) -> float:
		last_turn_plan = turn_plan.duplicate(true)
		return 200.0 if str(_action.get("kind", "")) == "evolve" else 20.0


class EndTurnAuthorityStrategy extends RefCounted:
	func score_action_absolute_with_plan(action: Dictionary, _game_state: GameState, _player_index: int, _turn_plan: Dictionary = {}) -> float:
		return 90000.0 if str(action.get("kind", "")) == "end_turn" else 100.0


class TurnPlanInteractionStrategy extends RefCounted:
	func build_turn_plan(_game_state: GameState, _player_index: int, _context: Dictionary = {}) -> Dictionary:
		return {
			"id": "convert_attack",
			"preferred_target": "preferred_target",
		}

	func score_interaction_target(item: Variant, _step: Dictionary, context: Dictionary = {}) -> float:
		var turn_plan: Dictionary = context.get("turn_plan", {})
		return 100.0 if str(item) == str(turn_plan.get("preferred_target", "")) else 0.0


class TurnContractInteractionStrategy extends RefCounted:
	func build_turn_contract(_game_state: GameState, _player_index: int, _context: Dictionary = {}) -> Dictionary:
		return {
			"id": "convert_attack_contract",
			"preferred_target": "preferred_target",
			"owner": {
				"turn_owner_name": "Giratina VSTAR",
			},
		}

	func score_interaction_target(item: Variant, _step: Dictionary, context: Dictionary = {}) -> float:
		var turn_plan: Dictionary = context.get("turn_plan", {})
		return 100.0 if str(item) == str(turn_plan.get("preferred_target", "")) else 0.0


class ExactAssignmentSubsetStrategy extends RefCounted:
	var chosen: Array = []
	var preserve_empty: bool = false

	func pick_interaction_items(items: Array, step: Dictionary, _context: Dictionary = {}) -> Array:
		if str(step.get("id", "")) != "energy_assignments":
			return []
		var selected: Array = []
		for wanted: Variant in chosen:
			for item: Variant in items:
				if item == wanted and not selected.has(item):
					selected.append(item)
					break
		return selected

	func should_preserve_empty_interaction_selection(step: Dictionary, _context: Dictionary = {}) -> bool:
		return preserve_empty and str(step.get("id", "")) == "energy_assignments"


class FixedActionScorer extends RefCounted:
	var favored_kind: String = ""
	var favored_delta: float = 0.0

	func score_delta(_state_features: Array, _action_vector: Variant, action_kind: String) -> float:
		return favored_delta if action_kind == favored_kind else 0.0


class FixedLegalActionBuilder extends RefCounted:
	var _deck_strategy = null
	var _deck_strategy_detected: bool = false
	var actions: Array[Dictionary] = []

	func build_actions(_gsm: GameStateMachine, _player_index: int) -> Array[Dictionary]:
		return actions.duplicate(true)


class TurnPlanEffectInteractionScene extends Control:
	var _pending_choice: String = "effect_interaction"
	var _pending_effect_steps: Array[Dictionary] = []
	var _pending_effect_step_index: int = 0
	var _pending_effect_context: Dictionary = {}
	var picked_indices := PackedInt32Array()

	func _resolve_effect_step_chooser_player(step: Dictionary) -> int:
		return int(step.get("chooser_player_index", 0))

	func _effect_step_uses_counter_distribution_ui(_step: Dictionary) -> bool:
		return false

	func _effect_step_uses_field_assignment_ui(_step: Dictionary) -> bool:
		return false

	func _effect_step_uses_field_slot_ui(_step: Dictionary) -> bool:
		return false

	func _handle_effect_interaction_choice(indices: PackedInt32Array) -> void:
		picked_indices = indices


class AssignmentEffectInteractionScene extends Control:
	var _pending_choice: String = "effect_interaction"
	var _pending_effect_steps: Array[Dictionary] = []
	var _pending_effect_step_index: int = 0
	var _pending_effect_context: Dictionary = {}
	var chosen_sources: Array[int] = []
	var chosen_targets: Array[int] = []
	var confirmed: bool = false

	func _resolve_effect_step_chooser_player(step: Dictionary) -> int:
		return int(step.get("chooser_player_index", 0))

	func _effect_step_uses_counter_distribution_ui(_step: Dictionary) -> bool:
		return false

	func _effect_step_uses_field_assignment_ui(_step: Dictionary) -> bool:
		return false

	func _effect_step_uses_field_slot_ui(_step: Dictionary) -> bool:
		return false

	func _on_assignment_source_chosen(source_index: int) -> void:
		chosen_sources.append(source_index)

	func _on_assignment_target_chosen(target_index: int) -> void:
		chosen_targets.append(target_index)

	func _confirm_assignment_dialog() -> void:
		confirmed = true




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


func test_registry_passes_editable_deck_strategy_text_to_resolved_strategy() -> String:
	var registry = DeckStrategyRegistryScript.new()
	var deck := _make_deck(575718, "raging_bolt", "Raging Bolt ex")
	deck.cards.append({
		"name": "Teal Mask Ogerpon ex",
		"name_en": "Teal Mask Ogerpon ex",
		"card_type": "Pokemon",
		"count": 1,
	})
	deck.strategy = "玩家自定义猛雷鼓打法"
	var strategy = registry.call("resolve_strategy_for_deck", deck)
	return run_checks([
		assert_not_null(strategy, "Registry should resolve the Raging Bolt strategy"),
		assert_true(strategy.has_method("get_deck_strategy_text"), "Resolved strategy should expose editable deck strategy text for variant handoff"),
		assert_eq(str(strategy.call("get_deck_strategy_text")), deck.strategy, "Registry should inject DeckData.strategy into the resolved strategy"),
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


func test_ai_opponent_passes_turn_plan_into_strategy_action_scoring() -> String:
	var gsm := _make_manual_gsm()
	var ai = AIOpponentScript.new()
	ai.player_index = 0
	var strategy := TurnPlanActionStrategy.new()
	ai.call("set_deck_strategy", strategy)
	var turn_contract: Dictionary = ai._build_turn_contract(gsm, {"prompt_kind": "action_selection"})
	var best: Dictionary = ai._pick_best_absolute([
		{"kind": "play_trainer"},
		{"kind": "evolve"},
	], gsm, turn_contract)
	return run_checks([
		assert_eq(str((best.get("action", {}) as Dictionary).get("kind", "")), "evolve",
			"Greedy strategy selection should let turn-plan-aware scoring choose the preferred action kind"),
		assert_eq(str(strategy.last_turn_plan.get("id", "")), "setup_shell",
			"AIOpponent should pass the built turn plan into score_action_absolute_with_plan"),
	])


func test_ai_opponent_prefers_turn_contract_when_available() -> String:
	var gsm := _make_manual_gsm()
	var ai = AIOpponentScript.new()
	ai.player_index = 0
	ai.decision_runtime_mode = "rules_only"
	var builder := FixedLegalActionBuilder.new()
	builder.actions = [
		{"kind": "play_trainer"},
		{"kind": "evolve"},
		{"kind": "end_turn"},
	]
	ai._legal_action_builder = builder
	var strategy := TurnContractActionStrategy.new()
	ai.call("set_deck_strategy", strategy)
	var chosen: Dictionary = ai._choose_greedy_strategy_action(gsm)
	var trace = ai.get_last_decision_trace()
	return run_checks([
		assert_eq(str(chosen.get("kind", "")), "evolve", "Greedy strategy selection should honor build_turn_contract when the strategy exposes it"),
		assert_eq(str(strategy.last_turn_plan.get("id", "")), "bridge_contract", "The strategy should receive the normalized turn contract during action scoring"),
		assert_eq(str((trace.turn_contract.get("owner", {}) as Dictionary).get("bridge_target_name", "")), "Giratina VSTAR", "Recorded traces should keep the chosen turn contract for replay review"),
		assert_eq(str(trace.runtime_mode), "rules_only", "Recorded traces should preserve the runtime scoring mode"),
	])


func test_ai_opponent_allows_strategy_to_force_end_turn() -> String:
	var gsm := _make_manual_gsm()
	var ai = AIOpponentScript.new()
	ai.player_index = 0
	ai.decision_runtime_mode = "rules_only"
	var builder := FixedLegalActionBuilder.new()
	builder.actions = [
		{"kind": "play_trainer"},
		{"kind": "use_ability"},
		{"kind": "end_turn"},
	]
	ai._legal_action_builder = builder
	ai.call("set_deck_strategy", EndTurnAuthorityStrategy.new())
	var chosen: Dictionary = ai._choose_greedy_strategy_action(gsm)
	var trace = ai.get_last_decision_trace()
	var end_turn_trace: Dictionary = {}
	for scored_action: Dictionary in trace.scored_actions:
		if str(scored_action.get("kind", "")) == "end_turn":
			end_turn_trace = scored_action
	return run_checks([
		assert_eq(str(chosen.get("kind", "")), "end_turn", "Deck strategy should be able to force queued end_turn over ordinary rule actions"),
		assert_eq(float(end_turn_trace.get("absolute_score", 0.0)), 90000.0, "End turn trace should preserve the deck-local queue score"),
	])


func test_ai_opponent_runtime_trace_matches_rules_only_scoring() -> String:
	var gsm := _make_manual_gsm()
	var ai = AIOpponentScript.new()
	ai.player_index = 0
	ai.decision_runtime_mode = "rules_only"
	var builder := FixedLegalActionBuilder.new()
	builder.actions = [
		{"kind": "play_trainer"},
		{"kind": "evolve"},
		{"kind": "end_turn"},
	]
	ai._legal_action_builder = builder
	var strategy := TurnContractActionStrategy.new()
	ai.call("set_deck_strategy", strategy)
	var learned := FixedActionScorer.new()
	learned.favored_kind = "play_trainer"
	learned.favored_delta = 500.0
	ai._action_scorer = learned
	var chosen: Dictionary = ai._choose_greedy_strategy_action(gsm)
	var trace = ai.get_last_decision_trace()
	var trainer_trace: Dictionary = {}
	var evolve_trace: Dictionary = {}
	for scored_action: Dictionary in trace.scored_actions:
		if str(scored_action.get("kind", "")) == "play_trainer":
			trainer_trace = scored_action
		elif str(scored_action.get("kind", "")) == "evolve":
			evolve_trace = scored_action
	return run_checks([
		assert_eq(str(chosen.get("kind", "")), "evolve", "rules_only mode should ignore learned overlays during greedy action selection"),
		assert_eq(float(trainer_trace.get("learned_action_score", -1.0)), 0.0, "rules_only traces should show zero learned contribution for non-chosen actions"),
		assert_eq(float(evolve_trace.get("absolute_score", 0.0)), 200.0, "rules_only traces should preserve the deck-local absolute score for the winning action"),
		assert_eq(str(trace.chosen_action.get("kind", "")), "evolve", "Recorded traces should agree with the actual greedy action choice"),
	])


func test_ai_opponent_runtime_trace_matches_rules_plus_learned_scoring() -> String:
	var gsm := _make_manual_gsm()
	var ai = AIOpponentScript.new()
	ai.player_index = 0
	ai.decision_runtime_mode = "rules_plus_learned"
	var builder := FixedLegalActionBuilder.new()
	builder.actions = [
		{"kind": "play_trainer"},
		{"kind": "evolve"},
		{"kind": "end_turn"},
	]
	ai._legal_action_builder = builder
	var strategy := TurnContractActionStrategy.new()
	ai.call("set_deck_strategy", strategy)
	var learned := FixedActionScorer.new()
	learned.favored_kind = "play_trainer"
	learned.favored_delta = 500.0
	ai._action_scorer = learned
	var chosen: Dictionary = ai._choose_greedy_strategy_action(gsm)
	var trace = ai.get_last_decision_trace()
	var trainer_trace: Dictionary = {}
	for scored_action: Dictionary in trace.scored_actions:
		if str(scored_action.get("kind", "")) == "play_trainer":
			trainer_trace = scored_action
	return run_checks([
		assert_eq(str(chosen.get("kind", "")), "play_trainer", "rules_plus_learned mode should still allow the learned overlay to overtake deck-local absolute scoring"),
		assert_eq(float(trainer_trace.get("learned_action_score", 0.0)), 500.0, "Runtime traces should record the same learned delta that participated in greedy action selection"),
		assert_eq(float(trace.chosen_action.get("score", 0.0)), float(trainer_trace.get("score", -1.0)), "Chosen trace payload should come from the same scored-candidate list used at runtime"),
	])


func test_headless_builder_passes_turn_plan_into_strategy_interaction_scoring() -> String:
	var gsm := _make_manual_gsm()
	var builder = AILegalActionBuilderScript.new()
	builder._deck_strategy = TurnPlanInteractionStrategy.new()
	builder._deck_strategy_detected = true
	var selected: Array = builder._select_headless_items(
		gsm,
		0,
		0,
		{"id": "search_item"},
		["bench_engine", "preferred_target"],
		1,
		{}
	)
	var picked: String = "" if selected.is_empty() else str(selected[0])
	return assert_eq(picked, "preferred_target",
		"Headless item selection should include turn-plan context when asking the strategy to score interaction targets")


func test_headless_builder_prefers_turn_contract_when_available() -> String:
	var gsm := _make_manual_gsm()
	var builder = AILegalActionBuilderScript.new()
	builder._deck_strategy = TurnContractInteractionStrategy.new()
	builder._deck_strategy_detected = true
	var selected: Array = builder._select_headless_items(
		gsm,
		0,
		0,
		{"id": "search_item"},
		["bench_engine", "preferred_target"],
		1,
		{}
	)
	var picked: String = "" if selected.is_empty() else str(selected[0])
	return assert_eq(picked, "preferred_target",
		"Headless item selection should accept build_turn_contract as the new shared contract entry point")


func test_step_resolver_passes_turn_plan_into_effect_interaction_scoring() -> String:
	var gsm := _make_manual_gsm()
	var resolver = AIStepResolverScript.new()
	resolver.deck_strategy = TurnPlanInteractionStrategy.new()
	var scene := TurnPlanEffectInteractionScene.new()
	scene._pending_effect_steps = [{
		"id": "search_item",
		"items": ["bench_engine", "preferred_target"],
		"min_select": 1,
		"max_select": 1,
		"chooser_player_index": 0,
	}]
	var resolved: bool = resolver.resolve_pending_step(scene, gsm, 0, [])
	return run_checks([
		assert_true(resolved, "Step resolver should still resolve a normal dialog step after turn-plan wiring"),
		assert_eq(Array(scene.picked_indices), [1],
			"Effect interaction scoring should receive the built turn plan and pick the preferred target"),
	])


func test_step_resolver_prefers_turn_contract_when_available() -> String:
	var gsm := _make_manual_gsm()
	var resolver = AIStepResolverScript.new()
	resolver.deck_strategy = TurnContractInteractionStrategy.new()
	var scene := TurnPlanEffectInteractionScene.new()
	scene._pending_effect_steps = [{
		"id": "search_item",
		"items": ["bench_engine", "preferred_target"],
		"min_select": 1,
		"max_select": 1,
		"chooser_player_index": 0,
	}]
	var resolved: bool = resolver.resolve_pending_step(scene, gsm, 0, [])
	return run_checks([
		assert_true(resolved, "Step resolver should still resolve effect interaction steps when the deck strategy only implements build_turn_contract"),
		assert_eq(Array(scene.picked_indices), [1],
			"Effect interaction scoring should accept build_turn_contract as the shared contract entry point"),
	])


func test_step_resolver_honors_exact_assignment_source_subset() -> String:
	var gsm := _make_manual_gsm()
	var resolver = AIStepResolverScript.new()
	var strategy := ExactAssignmentSubsetStrategy.new()
	var source_a := "grass_a"
	var source_b := "psychic_b"
	strategy.chosen = [source_b]
	resolver.deck_strategy = strategy
	var scene := AssignmentEffectInteractionScene.new()
	scene._pending_effect_steps = [{
		"id": "energy_assignments",
		"ui_mode": "card_assignment",
		"source_items": [source_a, source_b],
		"target_items": ["active", "bench"],
		"min_select": 0,
		"max_select": 2,
		"chooser_player_index": 0,
	}]
	var resolved: bool = resolver.resolve_pending_step(scene, gsm, 0, [])
	return run_checks([
		assert_true(resolved, "Step resolver should still resolve assignment prompts when the strategy picks an exact source subset"),
		assert_eq(scene.chosen_sources, [1], "Assignment resolution should honor the exact strategy-picked source subset instead of iterating all sources in raw order"),
		assert_eq(scene.chosen_targets.size(), 1, "Exact source subset planning should only produce one matching assignment"),
		assert_true(scene.confirmed, "Resolved assignment dialogs should still finalize normally after exact source subset selection"),
	])


func test_step_resolver_allows_explicit_empty_assignment_selection_when_step_is_optional() -> String:
	var gsm := _make_manual_gsm()
	var resolver = AIStepResolverScript.new()
	var strategy := ExactAssignmentSubsetStrategy.new()
	strategy.preserve_empty = true
	resolver.deck_strategy = strategy
	var scene := AssignmentEffectInteractionScene.new()
	scene._pending_effect_steps = [{
		"id": "energy_assignments",
		"ui_mode": "card_assignment",
		"source_items": ["grass_a", "psychic_b"],
		"target_items": ["active", "bench"],
		"min_select": 0,
		"max_select": 2,
		"chooser_player_index": 0,
	}]
	var resolved: bool = resolver.resolve_pending_step(scene, gsm, 0, [])
	return run_checks([
		assert_true(resolved, "Optional assignment prompts should treat an explicit empty source plan as a successful resolution"),
		assert_eq(scene.chosen_sources.size(), 0, "Explicit empty assignment plans should not fall back to baseline source iteration"),
		assert_eq(scene.chosen_targets.size(), 0, "Explicit empty assignment plans should not synthesize fallback target choices"),
		assert_true(scene.confirmed, "Optional assignment dialogs should still confirm after a valid empty resolution"),
	])
