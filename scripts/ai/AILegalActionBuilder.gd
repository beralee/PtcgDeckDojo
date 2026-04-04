class_name AILegalActionBuilder
extends RefCounted

const _PRIORITY_ITEM_NAMES: Array[String] = [
	"Electric Generator",
	"Nest Ball",
	"Buddy-Buddy Poffin",
	"Ultra Ball",
	"Switch Cart",
]


func build_actions(gsm: GameStateMachine, player_index: int) -> Array[Dictionary]:
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
	actions.append_array(_build_attach_energy_actions(gsm, player_index, player))
	actions.append_array(_build_attach_tool_actions(gsm, player_index, player))
	actions.append_array(_build_play_basic_to_bench_actions(gsm, player_index, player))
	actions.append_array(_build_evolve_actions(gsm, player_index, player))
	actions.append_array(_build_play_trainer_actions(gsm, player_index, player))
	actions.append_array(_build_play_stadium_actions(gsm, player_index, player))
	actions.append_array(_build_use_ability_actions(gsm, player_index, player))
	actions.append_array(_build_retreat_actions(gsm, player_index, player))
	actions.append_array(_build_attack_actions(gsm, player_index, player))
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
			if not gsm.rule_validator.can_attach_tool(gsm.game_state, player_index, target_slot):
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
			if not gsm.rule_validator.can_evolve(gsm.game_state, player_index, target_slot, card):
				continue
			actions.append({
				"kind": "evolve",
				"card": card,
				"target_slot": target_slot,
			})
	return actions


func _build_play_trainer_actions(gsm: GameStateMachine, player_index: int, player: PlayerState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	for card: CardInstance in player.hand:
		var trainer_eval := _evaluate_trainer_action(gsm, player_index, card)
		if not bool(trainer_eval.get("allowed", false)):
			continue
		var targets: Array = []
		var requires_interaction: bool = bool(trainer_eval.get("requires_interaction", false))
		if requires_interaction:
			var headless_targets: Variant = _build_headless_targets_for_card_effect(gsm, player_index, card)
			if headless_targets == null:
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


func _build_use_ability_actions(gsm: GameStateMachine, player_index: int, player: PlayerState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	for slot: PokemonSlot in _get_player_slots(player):
		actions.append_array(_build_slot_ability_actions(gsm, player_index, slot))
	return actions


func _build_slot_ability_actions(gsm: GameStateMachine, player_index: int, slot: PokemonSlot) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if slot == null or slot.get_top_card() == null:
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
		var requires_interaction: bool = not effect.get_interaction_steps(source_card, state).is_empty()
		if requires_interaction:
			var headless_targets: Variant = _build_headless_targets_for_ability(gsm, player_index, source_card, effect)
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
		var requires_interaction: bool = not effect.get_interaction_steps(source_card, state).is_empty()
		if requires_interaction:
			var headless_targets: Variant = _build_headless_targets_for_ability(gsm, player_index, source_card, effect)
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
	if not gsm.rule_validator.can_retreat(gsm.game_state, player_index):
		return actions
	var active: PokemonSlot = player.active_pokemon
	if active == null:
		return actions
	var cost: int = gsm.effect_processor.get_effective_retreat_cost(active, gsm.game_state)
	var discards: Array[Array] = _get_minimal_retreat_discards(gsm, active, cost)
	for bench_slot: PokemonSlot in player.bench:
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
	if active == null or active.get_top_card() == null:
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


func _get_player_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot != null:
			slots.append(bench_slot)
	return slots


func _evaluate_trainer_action(gsm: GameStateMachine, player_index: int, card: CardInstance) -> Dictionary:
	if card == null or card.card_data == null:
		return {"allowed": false, "requires_interaction": false}
	if card.card_data.card_type != "Item" and card.card_data.card_type != "Supporter":
		return {"allowed": false, "requires_interaction": false}
	if card.card_data.card_type == "Item" and not gsm.rule_validator.can_play_item(gsm.game_state, player_index):
		return {"allowed": false, "requires_interaction": false}
	if card.card_data.card_type == "Supporter":
		if not gsm.rule_validator.can_play_supporter(gsm.game_state, player_index) and not gsm._can_play_supporter_exception(player_index, card):
			return {"allowed": false, "requires_interaction": false}
	if not card in gsm.game_state.players[player_index].hand:
		return {"allowed": false, "requires_interaction": false}
	var effect: BaseEffect = gsm.effect_processor.get_effect(card.card_data.effect_id)
	if effect == null:
		return {"allowed": true, "requires_interaction": false}
	if not effect.can_execute(card, gsm.game_state):
		return {"allowed": false, "requires_interaction": false}
	return {
		"allowed": true,
		"requires_interaction": not effect.get_interaction_steps(card, gsm.game_state).is_empty(),
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


func _build_headless_targets_for_card_effect(gsm: GameStateMachine, player_index: int, card: CardInstance) -> Variant:
	if gsm == null or card == null or card.card_data == null:
		return null
	var effect: BaseEffect = gsm.effect_processor.get_effect(card.card_data.effect_id)
	if effect == null:
		return []
	return _build_headless_targets_from_steps(gsm, player_index, card.owner_index, effect.get_interaction_steps(card, gsm.game_state))


func _build_headless_targets_for_ability(
	gsm: GameStateMachine,
	player_index: int,
	source_card: CardInstance,
	effect: BaseEffect
) -> Variant:
	if gsm == null or source_card == null or effect == null:
		return null
	return _build_headless_targets_from_steps(gsm, player_index, source_card.owner_index, effect.get_interaction_steps(source_card, gsm.game_state))


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
		var resolved: Variant = _resolve_headless_step(gsm, player_index, owner_index, step)
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
	step: Dictionary
) -> Variant:
	var step_id: String = str(step.get("id", ""))
	if step_id == "":
		return null
	if str(step.get("ui_mode", "")) == "card_assignment":
		return _resolve_headless_assignment_step(gsm, player_index, owner_index, step)

	var items_variant: Variant = step.get("items", [])
	if not items_variant is Array:
		return null
	var items: Array = items_variant
	var min_select: int = int(step.get("min_select", 0))
	var max_select: int = int(step.get("max_select", items.size()))
	var selection: Array = _select_headless_items(gsm, player_index, owner_index, step_id, items, max_select)
	if selection.size() < min_select:
		return null
	return {step_id: selection}


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
	var selected_sources: Array = _select_headless_items(gsm, player_index, owner_index, step_id, source_items, max_select)
	if selected_sources.size() < min_select:
		return null
	var target: Variant = _pick_preferred_assignment_target(gsm, target_items)
	if target == null:
		return null
	var assignments: Array[Dictionary] = []
	for source: Variant in selected_sources:
		assignments.append({
			"source": source,
			"target": target,
		})
	return {step_id: assignments}


func _select_headless_items(
	gsm: GameStateMachine,
	player_index: int,
	owner_index: int,
	step_id: String,
	items: Array,
	max_select: int
) -> Array:
	match step_id:
		"search_item":
			var selected_item: Variant = _pick_preferred_named_card(items, _PRIORITY_ITEM_NAMES)
			return [] if selected_item == null else [selected_item]
		"search_tool":
			return [] if items.is_empty() else [items[0]]
		"bench_pokemon", "basic_pokemon", "buddy_poffin_pokemon":
			return _pick_preferred_bench_pokemon(items, max_select)
		"discard_cards":
			return _pick_discard_cards(items, max_select)
		"search_pokemon", "search_cards":
			return _pick_preferred_search_cards(gsm, player_index, owner_index, items, max_select)
		_:
			return items.slice(0, mini(max_select, items.size()))


func _pick_preferred_named_card(items: Array, preferred_names: Array[String]) -> Variant:
	for preferred_name: String in preferred_names:
		for item: Variant in items:
			if item is CardInstance and (item as CardInstance).card_data != null and (item as CardInstance).card_data.name == preferred_name:
				return item
	return null if items.is_empty() else items[0]


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


func _pick_discard_cards(items: Array, max_select: int) -> Array:
	var sorted_items: Array = items.duplicate()
	sorted_items.sort_custom(func(a: Variant, b: Variant) -> bool:
		if not (a is CardInstance) or not (b is CardInstance):
			return false
		var card_a: CardInstance = a
		var card_b: CardInstance = b
		var score_a: int = _score_discard_priority(card_a)
		var score_b: int = _score_discard_priority(card_b)
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
	for item: Variant in _pick_preferred_bench_pokemon(items, max_select):
		if item not in selection:
			selection.append(item)
			if selection.size() >= max_select:
				break
	return selection


func _pick_preferred_assignment_target(_gsm: GameStateMachine, target_items: Array) -> Variant:
	if target_items.is_empty():
		return null
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
