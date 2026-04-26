class_name AILegalActionBuilder
extends RefCounted

const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const AIInteractionPlannerScript = preload("res://scripts/ai/AIInteractionPlanner.gd")

const _PRIORITY_ITEM_NAMES: Array[String] = [
	"Electric Generator",
	"巢穴球",
	"友好宝芬",
	"高级球",
	"秘密箱",
	"大地容器",
	"反击捕捉器",
	"夜间担架",
	"救援担架",
	"厉害钓竿",
	"Nest Ball",
	"Buddy-Buddy Poffin",
	"Ultra Ball",
	"Switch Cart",
]

const _GARDEVOIR_SIGNATURES: Array[String] = ["沙奈朵ex", "奇鲁莉安", "拉鲁拉丝"]

const _RARE_CANDY_STAGE_ONE_BASIC_OVERRIDES := {
	"比比鸟": ["波波", "Pidgey"],
	"呱头蛙": ["呱呱泡蛙", "Froakie"],
	"冻脊龙": ["凉脊龙", "Frigibax"],
	"Pidgeotto": ["Pidgey", "波波"],
	"Frogadier": ["Froakie", "呱呱泡蛙"],
	"Arctibax": ["Frigibax", "凉脊龙"],
}

var _deck_strategy = null
var _deck_strategy_detected: bool = false
var _deck_strategy_registry = DeckStrategyRegistryScript.new()
var _interaction_planner = AIInteractionPlannerScript.new()


func set_deck_strategy(strategy: RefCounted) -> void:
	_deck_strategy = strategy
	_deck_strategy_detected = strategy != null


func _build_turn_plan(gsm: GameStateMachine, player_index: int, extra_context: Dictionary = {}) -> Dictionary:
	if _deck_strategy == null:
		return {}
	if gsm == null or gsm.game_state == null:
		return {}
	var plan_context: Dictionary = extra_context.duplicate(true)
	if _deck_strategy.has_method("build_turn_contract"):
		return _deck_strategy.call("build_turn_contract", gsm.game_state, player_index, plan_context)
	if not _deck_strategy.has_method("build_turn_plan"):
		return {}
	return _deck_strategy.call("build_turn_plan", gsm.game_state, player_index, plan_context)


func build_actions(
	gsm: GameStateMachine,
	player_index: int,
	allow_side_effectful_headless_resolution: bool = false
) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if gsm == null or gsm.game_state == null:
		return actions
	var state := gsm.game_state
	if state.current_player_index != player_index:
		return actions
	if state.phase != GameState.GamePhase.MAIN:
		return actions
	if player_index < 0 or player_index >= state.players.size():
		return actions

	var player: PlayerState = state.players[player_index]
	_detect_deck_strategy(player)
	actions.append_array(_build_attach_energy_actions(gsm, player_index, player))
	actions.append_array(_build_attach_tool_actions(gsm, player_index, player))
	actions.append_array(_build_play_basic_to_bench_actions(gsm, player_index, player))
	actions.append_array(_build_evolve_actions(gsm, player_index, player))
	actions.append_array(_build_play_trainer_actions(gsm, player_index, player, allow_side_effectful_headless_resolution))
	actions.append_array(_build_play_stadium_actions(gsm, player_index, player))
	actions.append_array(_build_use_ability_actions(gsm, player_index, player, allow_side_effectful_headless_resolution))
	actions.append_array(_build_retreat_actions(gsm, player_index, player))
	actions.append_array(_build_attack_actions(gsm, player_index, player))
	actions.append_array(_build_granted_attack_actions(gsm, player_index, player))
	actions.append({"kind": "end_turn"})
	return actions


func _build_attach_tool_actions(gsm: GameStateMachine, player_index: int, player: PlayerState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var slots: Array[PokemonSlot] = _get_player_slots(player)
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null or card.card_data.card_type != "Tool":
			continue
		for target_slot: PokemonSlot in slots:
			if target_slot == null:
				continue
			if not gsm.rule_validator.can_attach_tool(gsm.game_state, player_index, target_slot, gsm.effect_processor):
				continue
			actions.append({
				"kind": "attach_tool",
				"card": card,
				"target_slot": target_slot,
			})
	return actions


func _build_attach_energy_actions(gsm: GameStateMachine, player_index: int, player: PlayerState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if not gsm.rule_validator.can_attach_energy(gsm.game_state, player_index):
		return actions
	var slots: Array[PokemonSlot] = _get_player_slots(player)
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null or not card.card_data.is_energy():
			continue
		for target_slot: PokemonSlot in slots:
			actions.append({
				"kind": "attach_energy",
				"card": card,
				"target_slot": target_slot,
			})
	return actions


func _build_play_basic_to_bench_actions(gsm: GameStateMachine, player_index: int, player: PlayerState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		if not gsm.rule_validator.can_play_basic_to_bench(gsm.game_state, player_index, card):
			continue
		actions.append({
			"kind": "play_basic_to_bench",
			"card": card,
		})
	return actions


func _build_evolve_actions(gsm: GameStateMachine, player_index: int, player: PlayerState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var slots: Array[PokemonSlot] = _get_player_slots(player)
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null or not card.card_data.is_pokemon():
			continue
		for target_slot: PokemonSlot in slots:
			if not gsm.rule_validator.can_evolve(gsm.game_state, player_index, target_slot, card, gsm.effect_processor):
				continue
			actions.append({
				"kind": "evolve",
				"card": card,
				"target_slot": target_slot,
			})
	return actions


func _build_play_trainer_actions(
	gsm: GameStateMachine,
	player_index: int,
	player: PlayerState,
	allow_side_effectful_headless_resolution: bool
) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	for card: CardInstance in player.hand:
		var trainer_eval := _evaluate_trainer_action(gsm, player_index, card, allow_side_effectful_headless_resolution)
		if not bool(trainer_eval.get("allowed", false)):
			continue
		var targets: Array = []
		var requires_interaction: bool = bool(trainer_eval.get("requires_interaction", false))
		var preview_steps: Array[Dictionary] = []
		for step_variant: Variant in trainer_eval.get("preview_steps", []):
			if step_variant is Dictionary:
				preview_steps.append(step_variant)
		if requires_interaction:
			if not _can_headless_auto_resolve_steps(preview_steps, allow_side_effectful_headless_resolution):
				actions.append({
					"kind": "play_trainer",
					"card": card,
					"targets": [],
					"requires_interaction": true,
				})
				continue
			var headless_targets: Variant = _build_headless_targets_for_card_effect(
				gsm,
				player_index,
				card,
				preview_steps,
				allow_side_effectful_headless_resolution
			)
			if headless_targets == null:
				actions.append({
					"kind": "play_trainer",
					"card": card,
					"targets": [],
					"requires_interaction": true,
				})
				continue
			targets = headless_targets
			requires_interaction = false
		actions.append({
			"kind": "play_trainer",
			"card": card,
			"targets": targets,
			"requires_interaction": requires_interaction,
		})
	return actions


func _build_play_stadium_actions(gsm: GameStateMachine, player_index: int, player: PlayerState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null or card.card_data.card_type != "Stadium":
			continue
		if not gsm.rule_validator.can_play_stadium(gsm.game_state, player_index, card):
			continue
		var effect: BaseEffect = gsm.effect_processor.get_effect(card.card_data.effect_id)
		actions.append({
			"kind": "play_stadium",
			"card": card,
			"targets": [],
			"requires_interaction": effect != null and not effect.get_on_play_interaction_steps(card, gsm.game_state).is_empty(),
		})
	return actions


func _build_use_ability_actions(
	gsm: GameStateMachine,
	player_index: int,
	player: PlayerState,
	allow_side_effectful_headless_resolution: bool
) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	for slot: PokemonSlot in _get_player_slots(player):
		actions.append_array(_build_slot_ability_actions(gsm, player_index, slot, allow_side_effectful_headless_resolution))
	return actions


func _build_slot_ability_actions(
	gsm: GameStateMachine,
	player_index: int,
	slot: PokemonSlot,
	allow_side_effectful_headless_resolution: bool
) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if not _is_live_slot(slot):
		return actions
	var state: GameState = gsm.game_state
	var card_data: CardData = slot.get_card_data()
	for ability_index: int in card_data.abilities.size():
		if not gsm.effect_processor.can_use_ability(slot, state, ability_index):
			continue
		var source_card: CardInstance = gsm.effect_processor.get_ability_source_card(slot, ability_index, state)
		var effect: BaseEffect = gsm.effect_processor.get_ability_effect(slot, ability_index, state)
		if source_card == null or effect == null:
			continue
		var targets: Array = []
		var preview_steps: Array[Dictionary] = _get_effect_interaction_preview_steps(
			effect,
			source_card,
			state,
			allow_side_effectful_headless_resolution
		)
		var requires_interaction: bool = not preview_steps.is_empty()
		if requires_interaction:
			if not _can_headless_auto_resolve_steps(preview_steps, allow_side_effectful_headless_resolution):
				actions.append({
					"kind": "use_ability",
					"source_slot": slot,
					"ability_index": ability_index,
					"targets": [],
					"requires_interaction": true,
				})
				continue
			var headless_targets: Variant = _build_headless_targets_for_ability(
				gsm,
				player_index,
				source_card,
				effect,
				preview_steps,
				allow_side_effectful_headless_resolution
			)
			if headless_targets == null:
				continue
			targets = headless_targets
			requires_interaction = false
		actions.append({
			"kind": "use_ability",
			"source_slot": slot,
			"ability_index": ability_index,
			"targets": targets,
			"requires_interaction": requires_interaction,
		})
	for granted: Dictionary in gsm.effect_processor.get_granted_abilities(slot, state):
		var ability_index: int = int(granted.get("ability_index", -1))
		if ability_index < 0 or not gsm.effect_processor.can_use_ability(slot, state, ability_index):
			continue
		var source_card: CardInstance = gsm.effect_processor.get_ability_source_card(slot, ability_index, state)
		var effect: BaseEffect = gsm.effect_processor.get_ability_effect(slot, ability_index, state)
		if source_card == null or effect == null:
			continue
		var targets: Array = []
		var preview_steps: Array[Dictionary] = _get_effect_interaction_preview_steps(
			effect,
			source_card,
			state,
			allow_side_effectful_headless_resolution
		)
		var requires_interaction: bool = not preview_steps.is_empty()
		if requires_interaction:
			if not _can_headless_auto_resolve_steps(preview_steps, allow_side_effectful_headless_resolution):
				actions.append({
					"kind": "use_ability",
					"source_slot": slot,
					"ability_index": ability_index,
					"targets": [],
					"requires_interaction": true,
				})
				continue
			var headless_targets: Variant = _build_headless_targets_for_ability(
				gsm,
				player_index,
				source_card,
				effect,
				preview_steps,
				allow_side_effectful_headless_resolution
			)
			if headless_targets == null:
				continue
			targets = headless_targets
			requires_interaction = false
		actions.append({
			"kind": "use_ability",
			"source_slot": slot,
			"ability_index": ability_index,
			"targets": targets,
			"requires_interaction": requires_interaction,
		})
	return actions


func _build_retreat_actions(gsm: GameStateMachine, player_index: int, player: PlayerState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if not gsm.rule_validator.can_retreat(gsm.game_state, player_index, gsm.effect_processor):
		return actions
	var active: PokemonSlot = player.active_pokemon
	if not _is_live_slot(active):
		return actions
	var cost: int = gsm.effect_processor.get_effective_retreat_cost(active, gsm.game_state)
	var discards: Array[Array] = _get_minimal_retreat_discards(gsm, active, cost)
	for bench_slot: PokemonSlot in player.bench:
		if not _is_live_slot(bench_slot):
			continue
		for discard_variant: Array in discards:
			var discard_cards: Array[CardInstance] = []
			for energy: Variant in discard_variant:
				if energy is CardInstance:
					discard_cards.append(energy)
			actions.append({
				"kind": "retreat",
				"bench_target": bench_slot,
				"energy_to_discard": discard_cards,
			})
	return actions


func _build_attack_actions(gsm: GameStateMachine, player_index: int, player: PlayerState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var active: PokemonSlot = player.active_pokemon
	if not _is_live_slot(active):
		return actions
	var attacks: Array = active.get_card_data().attacks
	for attack_index: int in attacks.size():
		if not gsm.can_use_attack(player_index, attack_index):
			continue
		var interaction_steps: Array[Dictionary] = _get_attack_interaction_steps(gsm, active, attack_index)
		actions.append({
			"kind": "attack",
			"attack_index": attack_index,
			"targets": [],
			"requires_interaction": not interaction_steps.is_empty(),
		})
	return actions


func _build_granted_attack_actions(gsm: GameStateMachine, player_index: int, player: PlayerState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var active: PokemonSlot = player.active_pokemon
	if not _is_live_slot(active):
		return actions
	if gsm.effect_processor == null:
		return actions
	var granted_attacks: Array[Dictionary] = gsm.effect_processor.get_granted_attacks(active, gsm.game_state)
	for ga: Dictionary in granted_attacks:
		var cost: String = str(ga.get("cost", ""))
		if cost != "" and not gsm.rule_validator.has_enough_energy(active, cost, gsm.effect_processor, gsm.game_state):
			continue
		var ga_steps: Array[Dictionary] = gsm.effect_processor.get_granted_attack_interaction_steps(active, ga, gsm.game_state)
		actions.append({
			"kind": "granted_attack",
			"granted_attack_data": ga,
			"attack_index": -1,
			"source_slot": active,
			"targets": [],
			"requires_interaction": not ga_steps.is_empty(),
		})
	return actions


func _get_player_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if _is_live_slot(player.active_pokemon):
		slots.append(player.active_pokemon)
	for bench_slot: PokemonSlot in player.bench:
		if _is_live_slot(bench_slot):
			slots.append(bench_slot)
	return slots


func _is_live_slot(slot: PokemonSlot) -> bool:
	return slot != null and slot.get_top_card() != null and slot.get_remaining_hp() > 0


func _evaluate_trainer_action(
	gsm: GameStateMachine,
	player_index: int,
	card: CardInstance,
	allow_side_effectful_headless_resolution: bool
) -> Dictionary:
	if card == null or card.card_data == null:
		return {"allowed": false, "requires_interaction": false, "preview_steps": []}
	if card.card_data.card_type != "Item" and card.card_data.card_type != "Supporter":
		return {"allowed": false, "requires_interaction": false, "preview_steps": []}
	if card.card_data.card_type == "Item" and not gsm.rule_validator.can_play_item(gsm.game_state, player_index):
		return {"allowed": false, "requires_interaction": false, "preview_steps": []}
	if card.card_data.card_type == "Supporter":
		if not gsm.rule_validator.can_play_supporter(gsm.game_state, player_index) and not gsm._can_play_supporter_exception(player_index, card):
			return {"allowed": false, "requires_interaction": false, "preview_steps": []}
	if not card in gsm.game_state.players[player_index].hand:
		return {"allowed": false, "requires_interaction": false, "preview_steps": []}
	var effect: BaseEffect = gsm.effect_processor.get_effect(card.card_data.effect_id)
	if effect == null:
		return {"allowed": true, "requires_interaction": false, "preview_steps": []}
	if not effect.can_headless_execute(card, gsm.game_state):
		return {"allowed": false, "requires_interaction": false, "preview_steps": []}
	var preview_steps: Array[Dictionary] = _get_effect_interaction_preview_steps(
		effect,
		card,
		gsm.game_state,
		allow_side_effectful_headless_resolution
	)
	return {
		"allowed": true,
		"requires_interaction": not preview_steps.is_empty(),
		"preview_steps": preview_steps,
	}


func _get_minimal_retreat_discards(gsm: GameStateMachine, active: PokemonSlot, retreat_cost: int) -> Array[Array]:
	if retreat_cost <= 0:
		return [[]]
	var legal_discards: Array[Array] = []
	var attached_energy: Array[CardInstance] = active.attached_energy
	var subsets: Array[Array] = []
	_collect_energy_subsets(attached_energy, 0, [], subsets)
	var min_size: int = 999999
	for subset_variant: Array in subsets:
		var subset: Array[CardInstance] = []
		for energy: Variant in subset_variant:
			if energy is CardInstance:
				subset.append(energy)
		if subset.is_empty():
			continue
		if not gsm.rule_validator.has_enough_energy_to_retreat(active, subset, retreat_cost, gsm.effect_processor, gsm.game_state):
			continue
		if subset.size() < min_size:
			min_size = subset.size()
			legal_discards.clear()
		if subset.size() == min_size and not _contains_energy_subset(legal_discards, subset):
			legal_discards.append(subset)
	return legal_discards


func _collect_energy_subsets(
	energy_cards: Array[CardInstance],
	index: int,
	current: Array[CardInstance],
	results: Array[Array]
) -> void:
	if index >= energy_cards.size():
		results.append(current.duplicate())
		return
	_collect_energy_subsets(energy_cards, index + 1, current, results)
	current.append(energy_cards[index])
	_collect_energy_subsets(energy_cards, index + 1, current, results)
	current.pop_back()


func _contains_energy_subset(existing: Array[Array], candidate: Array[CardInstance]) -> bool:
	var candidate_ids: PackedInt32Array = _to_instance_id_array(candidate)
	for subset_variant: Array in existing:
		var subset: Array[CardInstance] = []
		for energy: Variant in subset_variant:
			if energy is CardInstance:
				subset.append(energy)
		if _to_instance_id_array(subset) == candidate_ids:
			return true
	return false


func _to_instance_id_array(cards: Array[CardInstance]) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for card: CardInstance in cards:
		ids.append(card.instance_id)
	return ids


func _build_headless_targets_for_card_effect(
	gsm: GameStateMachine,
	player_index: int,
	card: CardInstance,
	preview_steps: Array[Dictionary] = [],
	allow_side_effectful_headless_resolution: bool = false
) -> Variant:
	if gsm == null or card == null or card.card_data == null:
		return null
	var effect: BaseEffect = gsm.effect_processor.get_effect(card.card_data.effect_id)
	if effect == null:
		return []
	var steps: Array[Dictionary] = preview_steps
	if steps.is_empty():
		steps = _get_effect_interaction_preview_steps(effect, card, gsm.game_state, allow_side_effectful_headless_resolution)
	return _build_headless_targets_from_steps(gsm, player_index, card.owner_index, steps)


func _build_headless_targets_for_ability(
	gsm: GameStateMachine,
	player_index: int,
	source_card: CardInstance,
	effect: BaseEffect,
	preview_steps: Array[Dictionary] = [],
	allow_side_effectful_headless_resolution: bool = false
) -> Variant:
	if gsm == null or source_card == null or effect == null:
		return null
	var steps: Array[Dictionary] = preview_steps
	if steps.is_empty():
		steps = _get_effect_interaction_preview_steps(effect, source_card, gsm.game_state, allow_side_effectful_headless_resolution)
	return _build_headless_targets_from_steps(gsm, player_index, source_card.owner_index, steps)


func _get_effect_interaction_preview_steps(
	effect: BaseEffect,
	card: CardInstance,
	state: GameState,
	allow_side_effectful_headless_resolution: bool
) -> Array[Dictionary]:
	if effect == null:
		return []
	if allow_side_effectful_headless_resolution:
		return effect.get_interaction_steps(card, state)
	return effect.get_preview_interaction_steps(card, state)


func _can_headless_auto_resolve_steps(
	steps: Array[Dictionary],
	allow_side_effectful_headless_resolution: bool
) -> bool:
	if steps.is_empty():
		return true
	if allow_side_effectful_headless_resolution:
		return true
	for step: Dictionary in steps:
		if bool(step.get("wait_for_coin_animation", false)):
			return false
		if bool(step.get("preview_only", false)):
			return false
	return true


func _build_headless_targets_from_steps(
	gsm: GameStateMachine,
	player_index: int,
	owner_index: int,
	steps: Array[Dictionary]
) -> Variant:
	if steps.is_empty():
		return []
	var context := {}
	for step: Dictionary in steps:
		var resolved: Variant = _resolve_headless_step(gsm, player_index, owner_index, step, context)
		if resolved == null:
			return null
		if resolved is Dictionary:
			var resolved_dict: Dictionary = resolved
			for key: Variant in resolved_dict.keys():
				context[key] = resolved_dict[key]
	if context.is_empty():
		return []
	return [context]


func _resolve_headless_step(
	gsm: GameStateMachine,
	player_index: int,
	owner_index: int,
	step: Dictionary,
	interaction_context: Dictionary = {}
) -> Variant:
	var step_id: String = str(step.get("id", ""))
	if step_id == "":
		return null
	if str(step.get("ui_mode", "")) == "counter_distribution":
		return _resolve_headless_counter_distribution_step(gsm, step)
	if str(step.get("ui_mode", "")) == "card_assignment":
		return _resolve_headless_assignment_step(gsm, player_index, owner_index, step)

	var items_variant: Variant = step.get("items", [])
	if not items_variant is Array:
		return null
	var items: Array = items_variant
	var min_select: int = int(step.get("min_select", 0))
	var legal_items: Array = _filter_step_items_by_context(step, items, interaction_context)
	legal_items = _filter_rare_candy_targets_by_selected_stage2(gsm, owner_index, step_id, legal_items, interaction_context)
	var max_select: int = int(step.get("max_select", legal_items.size()))
	var selection: Array = _select_headless_items(gsm, player_index, owner_index, step, legal_items, max_select, interaction_context)
	if selection.size() < min_select:
		return null
	return {step_id: selection}


func _filter_rare_candy_targets_by_selected_stage2(
	gsm: GameStateMachine,
	owner_index: int,
	step_id: String,
	items: Array,
	interaction_context: Dictionary
) -> Array:
	if step_id != "target_pokemon" or items.is_empty():
		return items
	var stage2_raw: Variant = interaction_context.get("stage2_card", [])
	if not stage2_raw is Array or (stage2_raw as Array).is_empty():
		return items
	var stage2_card: CardInstance = (stage2_raw as Array)[0] as CardInstance
	if stage2_card == null or stage2_card.card_data == null:
		return items
	if str(stage2_card.card_data.stage) != "Stage 2":
		return items
	var filtered: Array = []
	for item: Variant in items:
		if item is PokemonSlot and _rare_candy_target_matches_stage2(gsm, owner_index, stage2_card, item as PokemonSlot):
			filtered.append(item)
	return filtered if not filtered.is_empty() else items


func _rare_candy_target_matches_stage2(
	gsm: GameStateMachine,
	owner_index: int,
	stage2_card: CardInstance,
	target_slot: PokemonSlot
) -> bool:
	if gsm == null or gsm.game_state == null or stage2_card == null or stage2_card.card_data == null or target_slot == null:
		return false
	if target_slot.pokemon_stack.size() != 1:
		return false
	var target_top: CardInstance = target_slot.get_top_card()
	if target_top == null or target_top.card_data == null or not target_top.card_data.is_basic_pokemon():
		return false
	var evolves_from := str(stage2_card.card_data.evolves_from)
	var target_name := str(target_slot.get_pokemon_name())
	if evolves_from == "" or target_name == "":
		return false
	if evolves_from == target_name or _matches_rare_candy_override(evolves_from, target_name):
		return true
	if owner_index < 0 or owner_index >= gsm.game_state.players.size():
		return false
	var player: PlayerState = gsm.game_state.players[owner_index]
	for ref_card: CardInstance in _collect_player_cards_for_evolution_reference(player):
		if _matches_stage_one_reference_for_rare_candy(ref_card, evolves_from, target_name):
			return true
	return false


func _collect_player_cards_for_evolution_reference(player: PlayerState) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	if player == null:
		return cards
	cards.append_array(player.hand)
	cards.append_array(player.deck)
	cards.append_array(player.discard_pile)
	cards.append_array(player.prizes)
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null:
			cards.append_array(slot.pokemon_stack)
	return cards


func _matches_stage_one_reference_for_rare_candy(card: CardInstance, stage_one_name: String, basic_name: String) -> bool:
	if card == null or card.card_data == null:
		return false
	var card_data: CardData = card.card_data
	return (
		card_data.is_pokemon()
		and str(card_data.stage) == "Stage 1"
		and str(card_data.name) == stage_one_name
		and str(card_data.evolves_from) == basic_name
	)


func _matches_rare_candy_override(stage_one_name: String, basic_name: String) -> bool:
	var aliases: Variant = _RARE_CANDY_STAGE_ONE_BASIC_OVERRIDES.get(stage_one_name, [])
	if aliases is String:
		return str(aliases) == basic_name
	if aliases is Array:
		for alias: Variant in aliases:
			if str(alias) == basic_name:
				return true
	return false


func _resolve_headless_counter_distribution_step(
	gsm: GameStateMachine,
	step: Dictionary
) -> Variant:
	var step_id: String = str(step.get("id", ""))
	var total_counters: int = int(step.get("total_counters", 0))
	var target_items_variant: Variant = step.get("target_items", [])
	if not target_items_variant is Array:
		return null
	var target_items: Array = target_items_variant
	if total_counters <= 0 or target_items.is_empty():
		return null
	var assignments: Array[Dictionary] = _pick_counter_distribution_assignments(gsm, target_items, total_counters * 10)
	if assignments.is_empty():
		var target: Variant = _pick_preferred_assignment_target(gsm, target_items, -1, step_id)
		if target == null:
			target = target_items[0]
		assignments = [{"target": target, "amount": total_counters * 10}]
	return {step_id: assignments}


func _filter_step_items_by_context(step: Dictionary, items: Array, interaction_context: Dictionary) -> Array:
	if items.is_empty() or interaction_context.is_empty():
		return items
	var excluded_items: Array = _collect_excluded_step_items(step, interaction_context)
	if excluded_items.is_empty():
		return items
	var filtered: Array = []
	for item: Variant in items:
		if item in excluded_items:
			continue
		filtered.append(item)
	return filtered


func _collect_excluded_step_items(step: Dictionary, interaction_context: Dictionary) -> Array:
	var excluded: Array = []
	var step_ids: Array[String] = []
	var single_step_id: String = str(step.get("exclude_selected_from_step_id", "")).strip_edges()
	if single_step_id != "":
		step_ids.append(single_step_id)
	for key_variant: Variant in step.get("exclude_selected_from_step_ids", []):
		var key: String = str(key_variant).strip_edges()
		if key != "" and not step_ids.has(key):
			step_ids.append(key)
	for step_id: String in step_ids:
		var selected_items: Variant = interaction_context.get(step_id, [])
		if not selected_items is Array:
			continue
		for item: Variant in selected_items:
			if not excluded.has(item):
				excluded.append(item)
	return excluded


func _resolve_headless_assignment_step(
	gsm: GameStateMachine,
	player_index: int,
	owner_index: int,
	step: Dictionary
) -> Variant:
	var step_id: String = str(step.get("id", ""))
	var source_items_variant: Variant = step.get("source_items", [])
	var target_items_variant: Variant = step.get("target_items", [])
	if not source_items_variant is Array or not target_items_variant is Array:
		return null
	var source_items: Array = source_items_variant
	var target_items: Array = target_items_variant
	if source_items.is_empty() or target_items.is_empty():
		return null
	var min_select: int = int(step.get("min_select", 0))
	var max_select: int = int(step.get("max_select", source_items.size()))
	var selected_sources: Array = _select_headless_items(
		gsm,
		player_index,
		owner_index,
		step,
		source_items,
		max_select,
		{"target_items": target_items}
	)
	var exclude_map: Dictionary = step.get("source_exclude_targets", {})
	var assignments: Array[Dictionary] = []
	var pending_assignment_counts: Dictionary = {}
	var pending_assignments: Array[Dictionary] = []
	for source: Variant in selected_sources:
		var source_index: int = source_items.find(source)
		var eligible_targets: Array = []
		var excluded_target_indices: Array = exclude_map.get(source_index, [])
		for target_index: int in target_items.size():
			if target_index in excluded_target_indices:
				continue
			eligible_targets.append(target_items[target_index])
		var target: Variant = _pick_preferred_assignment_target_for_source(
			gsm,
			player_index,
			step_id,
			source,
			eligible_targets,
			pending_assignment_counts,
			pending_assignments
		)
		if target == null:
			continue
		if target is Object:
			var target_id := int((target as Object).get_instance_id())
			pending_assignment_counts[target_id] = int(pending_assignment_counts.get(target_id, 0)) + 1
		assignments.append({
			"source": source,
			"target": target,
		})
		pending_assignments.append({
			"source": source,
			"target": target,
		})
	if assignments.size() < min_select:
		return null
	return {step_id: assignments}


func _select_headless_items(
	gsm: GameStateMachine,
	player_index: int,
	owner_index: int,
	step: Dictionary,
	items: Array,
	max_select: int,
	interaction_context: Dictionary = {}
) -> Array:
	var step_id: String = str(step.get("id", ""))
	var strategy_context := {
		"game_state": gsm.game_state if gsm != null else null,
		"player_index": player_index,
	}
	for key: Variant in interaction_context.keys():
		strategy_context[key] = interaction_context[key]
	var turn_contract := _build_turn_plan(gsm, player_index, {
		"step_id": step_id,
		"prompt_kind": "headless_step",
		"interaction_context": interaction_context,
	})
	strategy_context["turn_plan"] = turn_contract
	strategy_context["turn_contract"] = turn_contract
	match step_id:
		"search_item":
			var planned_items: Array = _pick_items_with_strategy(items, step_id, max_select, strategy_context)
			if not planned_items.is_empty():
				return planned_items
			var prioritized_items: Array = _pick_preferred_cards_by_strategy_priority(items, max_select)
			if not prioritized_items.is_empty():
				return prioritized_items
			var selected_item: Variant = _pick_preferred_named_card(items, _PRIORITY_ITEM_NAMES)
			return [] if selected_item == null else [selected_item]
		"search_tool":
			var planned_tools: Array = _pick_items_with_strategy(items, step_id, max_select, strategy_context)
			if not planned_tools.is_empty():
				return planned_tools
			var prioritized_tools: Array = _pick_preferred_cards_by_strategy_priority(items, max_select)
			if not prioritized_tools.is_empty():
				return prioritized_tools
			return [] if items.is_empty() else [items[0]]
		"bench_pokemon", "basic_pokemon", "buddy_poffin_pokemon":
			var planned_bench: Array = _pick_items_with_strategy(items, step_id, max_select, strategy_context)
			if not planned_bench.is_empty():
				return planned_bench
			return _pick_preferred_bench_pokemon(items, max_select)
		"discard_cards", "discard_card":
			return _pick_discard_cards(items, max_select, gsm, player_index, step, owner_index)
		"discard_energy":
			# 隐藏牌 / 精炼等需要弃能量的特性：优先弃超能量（Embrace 燃料）
			return _pick_discard_cards(items, max_select, gsm, player_index, step, owner_index)
		"search_pokemon", "search_cards":
			var planned_search: Array = _pick_items_with_strategy(items, step_id, max_select, strategy_context)
			if not planned_search.is_empty():
				return planned_search
			return _pick_preferred_search_cards(gsm, player_index, owner_index, items, max_select)
		"supporter_card", "stage2_card", "target_pokemon":
			var planned_prompt_targets: Array = _pick_items_with_strategy(items, step_id, max_select, strategy_context)
			if not planned_prompt_targets.is_empty():
				return planned_prompt_targets
			return items.slice(0, mini(max_select, items.size()))
		"energy_assignments":
			var planned_sources: Array = _pick_items_with_strategy(items, step_id, max_select, strategy_context)
			if not planned_sources.is_empty():
				return planned_sources
			return items.slice(0, mini(max_select, items.size()))
		"embrace_target":
			# 沙奈朵 Psychic Embrace 目标选择
			var planned_targets: Array = _pick_items_with_strategy(items, step_id, max_select, strategy_context)
			if not planned_targets.is_empty():
				return planned_targets
			return items.slice(0, mini(max_select, items.size()))
		_:
			var explicit_planned_items: Array = _pick_explicit_interaction_items(items, step_id, max_select, strategy_context)
			if not explicit_planned_items.is_empty():
				return explicit_planned_items
			return items.slice(0, mini(max_select, items.size()))


func _pick_explicit_interaction_items(items: Array, step_id: String, max_select: int, context: Dictionary = {}) -> Array:
	if _deck_strategy == null or not _deck_strategy.has_method("pick_interaction_items"):
		return []
	var planned: Variant = _deck_strategy.call("pick_interaction_items", items, {"id": step_id, "max_select": max_select}, context)
	if planned is Array:
		return planned
	return []


func _pick_items_with_strategy(items: Array, step_id: String, max_select: int, context: Dictionary = {}) -> Array:
	if _deck_strategy == null:
		return []
	if _deck_strategy.has_method("pick_interaction_items"):
		var planned: Variant = _deck_strategy.call("pick_interaction_items", items, {"id": step_id, "max_select": max_select}, context)
		if planned is Array:
			if not (planned as Array).is_empty():
				return planned
			if step_id == "buddy_poffin_pokemon":
				return []
	if not _deck_strategy.has_method("score_interaction_target"):
		return []
	var selected_indices: PackedInt32Array = _interaction_planner.pick_item_indices(
		_deck_strategy,
		items,
		{"id": step_id},
		max_select,
		context
	)
	var selected_items: Array = []
	for index: int in selected_indices:
		if index >= 0 and index < items.size():
			selected_items.append(items[index])
	return selected_items


func _pick_preferred_named_card(items: Array, preferred_names: Array[String]) -> Variant:
	for preferred_name: String in preferred_names:
		for item: Variant in items:
			if item is CardInstance and (item as CardInstance).card_data != null and (item as CardInstance).card_data.name == preferred_name:
				return item
	return null if items.is_empty() else items[0]


func _pick_preferred_cards_by_strategy_priority(items: Array, max_select: int) -> Array:
	if _deck_strategy == null or not _deck_strategy.has_method("get_search_priority") or items.is_empty():
		return []
	var scored_items: Array = items.duplicate()
	scored_items.sort_custom(func(a: Variant, b: Variant) -> bool:
		if not (a is CardInstance) or not (b is CardInstance):
			return false
		var score_a: int = _deck_strategy.get_search_priority(a as CardInstance)
		var score_b: int = _deck_strategy.get_search_priority(b as CardInstance)
		if score_a == score_b:
			return str((a as CardInstance).card_data.name) < str((b as CardInstance).card_data.name)
		return score_a > score_b
	)
	return scored_items.slice(0, mini(max_select, scored_items.size()))


func _pick_preferred_bench_pokemon(items: Array, max_select: int) -> Array:
	var sorted_items: Array = items.duplicate()
	sorted_items.sort_custom(func(a: Variant, b: Variant) -> bool:
		if not (a is CardInstance) or not (b is CardInstance):
			return false
		var card_a: CardInstance = a
		var card_b: CardInstance = b
		var score_a: int = _score_pokemon_search_target(card_a)
		var score_b: int = _score_pokemon_search_target(card_b)
		if score_a == score_b:
			return str(card_a.card_data.name) < str(card_b.card_data.name)
		return score_a > score_b
	)
	return sorted_items.slice(0, mini(max_select, sorted_items.size()))


func _pick_discard_cards(
	items: Array,
	max_select: int,
	gsm: GameStateMachine = null,
	player_index: int = -1,
	step: Dictionary = {},
	owner_index: int = -1
) -> Array:
	if _deck_strategy != null and _deck_strategy.has_method("pick_interaction_items"):
		var discard_context := {
			"game_state": gsm.game_state if gsm != null else null,
			"player_index": player_index,
			"owner_index": owner_index,
		}
		var turn_contract := _build_turn_plan(gsm, player_index, {
			"step_id": str(step.get("id", "")),
			"prompt_kind": "headless_discard",
			"owner_index": owner_index,
		})
		discard_context["turn_plan"] = turn_contract
		discard_context["turn_contract"] = turn_contract
		var planned: Variant = _deck_strategy.call("pick_interaction_items", items, step, discard_context)
		if planned is Array:
			var selected: Array = []
			for item: Variant in planned:
				if item in items and not selected.has(item):
					selected.append(item)
			return selected.slice(0, mini(max_select, selected.size()))
	var use_contextual: bool = _deck_strategy != null and _deck_strategy.has_method("get_discard_priority_contextual") and gsm != null and gsm.game_state != null and player_index >= 0
	var use_strategy: bool = _deck_strategy != null and _deck_strategy.has_method("get_discard_priority")
	var game_state: GameState = gsm.game_state if gsm != null else null
	var sorted_items: Array = items.duplicate()
	sorted_items.sort_custom(func(a: Variant, b: Variant) -> bool:
		if not (a is CardInstance) or not (b is CardInstance):
			return false
		var card_a: CardInstance = a
		var card_b: CardInstance = b
		var score_a: int
		var score_b: int
		if use_contextual:
			score_a = _deck_strategy.get_discard_priority_contextual(card_a, game_state, player_index)
			score_b = _deck_strategy.get_discard_priority_contextual(card_b, game_state, player_index)
		elif use_strategy:
			score_a = _deck_strategy.get_discard_priority(card_a)
			score_b = _deck_strategy.get_discard_priority(card_b)
		else:
			score_a = _score_discard_priority(card_a)
			score_b = _score_discard_priority(card_b)
		if score_a == score_b:
			return str(card_a.card_data.name) < str(card_b.card_data.name)
		return score_a > score_b
	)
	return sorted_items.slice(0, mini(max_select, sorted_items.size()))


func _pick_preferred_search_cards(
	gsm: GameStateMachine,
	player_index: int,
	_owner_index: int,
	items: Array,
	max_select: int
) -> Array:
	var player: PlayerState = gsm.game_state.players[player_index]
	var selection: Array = []
	if _player_has_miraidon_signature(player):
		for preferred_name: String in ["Miraidon ex", "Iron Hands ex", "Squawkabilly ex", "Regieleki V", "Regieleki VMAX"]:
			for item: Variant in items:
				if item is CardInstance and item not in selection and (item as CardInstance).card_data != null and (item as CardInstance).card_data.name == preferred_name:
					selection.append(item)
					if selection.size() >= max_select:
						return selection
	elif _deck_strategy != null and _deck_strategy.has_method("get_search_priority"):
		# 沙奈朵卡组：按策略检索优先级排序
		var scored_items: Array = items.duplicate()
		scored_items.sort_custom(func(a: Variant, b: Variant) -> bool:
			if not (a is CardInstance) or not (b is CardInstance):
				return false
			var score_a: int = _deck_strategy.get_search_priority(a as CardInstance)
			var score_b: int = _deck_strategy.get_search_priority(b as CardInstance)
			if score_a == score_b:
				return str((a as CardInstance).card_data.name) < str((b as CardInstance).card_data.name)
			return score_a > score_b
		)
		for item: Variant in scored_items:
			if item not in selection:
				selection.append(item)
				if selection.size() >= max_select:
					return selection
	for item: Variant in _pick_preferred_bench_pokemon(items, max_select):
		if item not in selection:
			selection.append(item)
			if selection.size() >= max_select:
				break
	return selection


func _pick_preferred_assignment_target(gsm: GameStateMachine, target_items: Array, player_index: int = -1, step_id: String = "assignment_target") -> Variant:
	if target_items.is_empty():
		return null
	if _deck_strategy != null and _deck_strategy.has_method("score_interaction_target"):
		var assignment_context := {}
		if gsm != null and gsm.game_state != null and player_index >= 0:
			assignment_context = {
				"game_state": gsm.game_state,
				"player_index": player_index,
			}
			var turn_contract := _build_turn_plan(gsm, player_index, {
				"step_id": step_id,
				"prompt_kind": "assignment_target",
			})
			assignment_context["turn_plan"] = turn_contract
			assignment_context["turn_contract"] = turn_contract
		var best_index: int = _interaction_planner.pick_best_legal_target_index(
			_deck_strategy,
			target_items,
			[],
			{"id": step_id},
			assignment_context
		)
		if best_index >= 0:
			return target_items[best_index]
	var sorted_targets: Array = target_items.duplicate()
	sorted_targets.sort_custom(func(a: Variant, b: Variant) -> bool:
		if not (a is PokemonSlot) or not (b is PokemonSlot):
			return false
		var slot_a: PokemonSlot = a
		var slot_b: PokemonSlot = b
		var score_a: int = _score_energy_assignment_target(slot_a)
		var score_b: int = _score_energy_assignment_target(slot_b)
		if score_a == score_b:
			return slot_a.get_pokemon_name() < slot_b.get_pokemon_name()
		return score_a > score_b
	)
	return sorted_targets[0]


func _pick_preferred_assignment_target_for_source(
	gsm: GameStateMachine,
	player_index: int,
	step_id: String,
	source: Variant,
	target_items: Array,
	pending_assignment_counts: Dictionary = {},
	pending_assignments: Array = []
) -> Variant:
	if target_items.is_empty():
		return null
	if _deck_strategy != null and _deck_strategy.has_method("score_interaction_target"):
		var context := {
			"game_state": gsm.game_state if gsm != null else null,
			"player_index": player_index,
			"all_items": target_items,
			"pending_assignment_counts": pending_assignment_counts,
			"pending_assignments": pending_assignments,
		}
		var turn_contract := _build_turn_plan(gsm, player_index, {
			"step_id": step_id,
			"prompt_kind": "assignment_target",
			"pending_assignments": pending_assignments,
		})
		context["turn_plan"] = turn_contract
		context["turn_contract"] = turn_contract
		if source is CardInstance:
			context["source_card"] = source
		var best_index: int = _interaction_planner.pick_best_legal_target_index(
			_deck_strategy,
			target_items,
			[],
			{"id": step_id},
			context
		)
		if best_index >= 0:
			return target_items[best_index]
	return _pick_preferred_assignment_target(gsm, target_items, player_index, step_id)


func _pick_counter_distribution_assignments(_gsm: GameStateMachine, target_items: Array, total_damage: int) -> Array[Dictionary]:
	if total_damage <= 0 or target_items.is_empty():
		return []
	var pokemon_targets: Array[PokemonSlot] = []
	for item: Variant in target_items:
		if item is PokemonSlot:
			pokemon_targets.append(item as PokemonSlot)
	if pokemon_targets.is_empty():
		return []
	var sorted_targets: Array[PokemonSlot] = pokemon_targets.duplicate()
	sorted_targets.sort_custom(func(a: PokemonSlot, b: PokemonSlot) -> bool:
		var need_a: int = _damage_needed_for_knockout(a)
		var need_b: int = _damage_needed_for_knockout(b)
		if need_a == need_b:
			return a.get_remaining_hp() < b.get_remaining_hp()
		return need_a < need_b
	)
	var remaining_damage: int = total_damage
	var assignments: Array[Dictionary] = []
	for target: PokemonSlot in sorted_targets:
		var damage_needed: int = _damage_needed_for_knockout(target)
		if damage_needed <= 0 or damage_needed > remaining_damage:
			continue
		assignments.append({
			"target": target,
			"amount": damage_needed,
		})
		remaining_damage -= damage_needed
	if assignments.is_empty():
		return []
	if remaining_damage > 0:
		assignments[0]["amount"] = int(assignments[0].get("amount", 0)) + remaining_damage
	return assignments


func _damage_needed_for_knockout(target: PokemonSlot) -> int:
	if target == null:
		return 0
	var remaining_hp: int = target.get_remaining_hp()
	if remaining_hp <= 0:
		return 0
	return int(ceil(float(remaining_hp) / 10.0) * 10.0)


func _score_pokemon_search_target(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	var name: String = card.card_data.name
	if name == "Miraidon ex":
		return 100
	if name == "Iron Hands ex":
		return 90
	if name == "Squawkabilly ex":
		return 80
	if name == "Regieleki V":
		return 70
	if name == "Regieleki VMAX":
		return 60
	if card.card_data.energy_type == "L":
		return 50
	return 10


func _score_discard_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	if card.card_data.card_type == "Basic Energy":
		return 100
	if card.card_data.card_type == "Item" and card.card_data.name != "Electric Generator":
		return 80
	if card.card_data.card_type == "Tool":
		return 70
	return 10


func _score_energy_assignment_target(slot: PokemonSlot) -> int:
	if slot == null or slot.get_top_card() == null:
		return 0
	var name: String = slot.get_pokemon_name()
	if name == "Iron Hands ex":
		return 100
	if name == "Miraidon ex":
		return 90
	if name == "Regieleki V":
		return 80
	return 40 + slot.attached_energy.size()


func _player_has_miraidon_signature(player: PlayerState) -> bool:
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.name == "Miraidon ex":
			return true
	if player.active_pokemon != null and player.active_pokemon.get_top_card() != null and player.active_pokemon.get_pokemon_name() == "Miraidon ex":
		return true
	for slot: PokemonSlot in player.bench:
		if slot != null and slot.get_top_card() != null and slot.get_pokemon_name() == "Miraidon ex":
			return true
	return false


func _get_attack_interaction_steps(gsm: GameStateMachine, slot: PokemonSlot, attack_index: int) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	if slot == null or slot.get_top_card() == null:
		return steps
	var card: CardInstance = slot.get_top_card()
	var attacks: Array = card.card_data.attacks
	if attack_index < 0 or attack_index >= attacks.size():
		return steps
	var attack: Dictionary = attacks[attack_index]
	for effect: BaseEffect in gsm.effect_processor.get_attack_effects_for_slot(slot, attack_index):
		steps.append_array(effect.get_attack_interaction_steps(card, attack, gsm.game_state))
	return steps


func _detect_deck_strategy(player: PlayerState) -> void:
	if _deck_strategy_detected:
		return
	_deck_strategy_detected = true
	_deck_strategy = _deck_strategy_registry.create_strategy_for_player(player)
