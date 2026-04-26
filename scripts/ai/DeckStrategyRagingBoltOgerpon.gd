class_name DeckStrategyRagingBoltOgerpon
extends "res://scripts/ai/LLMDeckStrategyBase.gd"


const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")

const RAGING_BOLT_EX: Array[String] = ["Raging Bolt ex", "猛雷鼓ex"]
const TEAL_MASK_OGERPON_EX: Array[String] = ["Teal Mask Ogerpon ex", "厄诡椪 碧草面具ex"]
const SLITHER_WING: Array[String] = ["Slither Wing", "爬地翅"]
const IRON_BUNDLE: Array[String] = ["Iron Bundle", "铁包袱"]
const SQUAWKABILLY_EX: Array[String] = ["Squawkabilly ex", "怒鹦哥ex"]

const SADA: Array[String] = ["Professor Sada's Vitality", "奥琳博士的气魄"]
const EARTHEN_VESSEL: Array[String] = ["Earthen Vessel", "大地容器"]
const ENERGY_RETRIEVAL: Array[String] = ["Energy Retrieval", "能量回收"]
const NEST_BALL: Array[String] = ["Nest Ball", "巢穴球"]
const BRAVERY_CHARM: Array[String] = ["Bravery Charm", "勇气护符"]
const SWITCH_CART: Array[String] = ["Switch Cart", "交替推车"]
const PROFESSORS_RESEARCH: Array[String] = ["Professor's Research", "博士的研究"]
const MAGMA_BASIN: Array[String] = ["Magma Basin", "熔岩瀑布之渊"]
const PHASE_LAUNCH := "launch"
const PHASE_PRESSURE := "pressure"
const PHASE_CONVERT := "convert"
const POKEGEAR_30: Array[String] = ["Pok\u00e9gear 3.0", "宝可装置3.0"]
const RADIANT_GRENINJA: Array[String] = ["Radiant Greninja", "光辉甲贺忍蛙"]

var _deck_strategy_text: String = ""


func get_strategy_id() -> String:
	return "raging_bolt_ogerpon"


func set_deck_strategy_text(strategy_text: String) -> void:
	_deck_strategy_text = strategy_text.strip_edges()


func get_deck_strategy_text() -> String:
	return _deck_strategy_text


func get_signature_names() -> Array[String]:
	return ["Raging Bolt ex", "Teal Mask Ogerpon ex", "Professor Sada's Vitality"]


func get_state_encoder_class() -> GDScript:
	return StateEncoderScript


func load_value_net(_path: String) -> bool:
	return false


func get_value_net() -> RefCounted:
	return null


func get_mcts_config() -> Dictionary:
	return {
		"branch_factor": 3,
		"max_actions_per_turn": 8,
		"rollouts_per_sequence": 0,
		"time_budget_ms": 2400,
	}


func plan_opening_setup(player: PlayerState) -> Dictionary:
	var basics: Array[Dictionary] = []
	for i: int in player.hand.size():
		var card: CardInstance = player.hand[i]
		if not _is_basic_pokemon(card):
			continue
		basics.append({"index": i, "priority": _setup_priority(str(card.card_data.name))})
	if basics.is_empty():
		return {"active_hand_index": -1, "bench_hand_indices": []}
	basics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 0)) > int(b.get("priority", 0))
	)
	var active_index: int = int(basics[0].get("index", -1))
	var bench_indices: Array[int] = []
	for entry: Dictionary in basics:
		var index: int = int(entry.get("index", -1))
		if index == active_index:
			continue
		bench_indices.append(index)
		if bench_indices.size() >= 5:
			break
	return {"active_hand_index": active_index, "bench_hand_indices": bench_indices}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var kind: String = str(action.get("kind", ""))
	var base_score: float = 0.0
	match kind:
		"play_basic_to_bench":
			base_score = _score_bench_basic(action.get("card"), game_state, player_index)
		"attach_energy":
			base_score = _score_attach_energy(action.get("card"), action.get("target_slot"), game_state, player_index)
		"attach_tool":
			base_score = _score_attach_tool(action.get("card"), action.get("target_slot"))
		"use_ability":
			base_score = _score_ability(action.get("source_slot"), game_state, player_index)
		"play_trainer":
			base_score = _score_trainer(action.get("card"), game_state, player_index)
		"attack", "granted_attack":
			base_score = _score_attack(action, game_state, player_index)
		"retreat":
			base_score = _score_retreat(action.get("bench_target"), game_state, player_index)
	return base_score + _apply_turn_plan_bonus(kind, action, game_state, player_index, base_score)


func score_action(action: Dictionary, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state")
	var player_index: int = int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	return score_action_absolute(action, game_state, player_index) - _estimate_heuristic_base(str(action.get("kind", "")))


func evaluate_board(game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var score := 0.0
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null or slot.get_card_data() == null:
			continue
		if _slot_matches(slot, RAGING_BOLT_EX):
			score += 240.0
			score += float(slot.attached_energy.size()) * 85.0
			if _preferred_attack_energy_gap(slot) <= 1:
				score += 100.0
		elif _slot_matches(slot, TEAL_MASK_OGERPON_EX):
			score += 150.0
			score += float(slot.attached_energy.size()) * 35.0
		elif slot.get_card_data().is_ancient_pokemon():
			score += 60.0
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and card.card_data.card_type == "Basic Energy":
			score += 12.0
	return score


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var attached: int = slot.attached_energy.size() + extra_context
	var best_damage := 0
	var can_attack := false
	for attack: Dictionary in slot.get_card_data().attacks:
		var cost: String = str(attack.get("cost", ""))
		var attack_damage: int = _parse_damage_value(str(attack.get("damage", "0")))
		if attached >= cost.length():
			can_attack = true
			best_damage = maxi(best_damage, attack_damage)
	return {"damage": best_damage, "can_attack": can_attack, "description": ""}


func get_discard_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	var name: String = str(card.card_data.name)
	if _matches_name(name, RAGING_BOLT_EX):
		return 5
	if card.card_data.card_type == "Basic Energy":
		return 220
	if _matches_name(name, SADA):
		return 10
	if _matches_name(name, EARTHEN_VESSEL) or _matches_name(name, ENERGY_RETRIEVAL):
		return 30
	return 90


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	var player: PlayerState = _get_player(game_state, player_index)
	if player == null or card == null or card.card_data == null:
		return get_discard_priority(card)
	if _find_energy_holder(player, card) != null:
		return int(_score_field_discard_candidate(card, player))
	return int(_score_hand_discard_candidate(card, player))


func get_search_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	if _card_matches(card, RAGING_BOLT_EX):
		return 100
	if _card_matches(card, TEAL_MASK_OGERPON_EX):
		return 95
	if _card_matches(card, SLITHER_WING):
		return 70
	return 20


func estimate_bellowing_thunder_damage(discard_count: int) -> int:
	return maxi(0, discard_count) * 70


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var step_id: String = str(step.get("id", ""))
	if step_id == "sada_assignments":
		return _pick_sada_energy_sources(items, context, int(step.get("max_select", 2)))
	if step_id not in ["discard_energy", "discard_card", "discard_cards", "discard_basic_energy"]:
		return []
	var player: PlayerState = _get_player(context.get("game_state"), int(context.get("player_index", -1)))
	if player == null or items.is_empty():
		return []
	var card_items: Array[CardInstance] = []
	for item: Variant in items:
		if item is CardInstance:
			card_items.append(item as CardInstance)
	if card_items.is_empty():
		return []
	for card: CardInstance in card_items:
		if card == null or card.card_data == null or not card.card_data.is_energy():
			return []
	if _all_cards_attached_to_field(card_items, player):
		return _pick_field_discard_items(card_items, player, context, int(step.get("max_select", card_items.size())))
	return _pick_hand_discard_items(card_items, player, int(step.get("min_select", 0)), int(step.get("max_select", card_items.size())))


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id: String = str(step.get("id", ""))
	if item is CardInstance:
		var card := item as CardInstance
		if step_id in ["search_pokemon", "search_cards", "search_future_pokemon"]:
			return float(get_search_priority(card))
		if step_id in ["discard_cards", "discard_card", "discard_energy", "discard_basic_energy"]:
			return float(get_discard_priority_contextual(card, context.get("game_state"), int(context.get("player_index", -1))))
		if step_id == "search_energy":
			return _score_energy_search_candidate(card, context)
		return 40.0
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		return _score_assignment_target(slot, context)
	return 0.0


func _score_bench_basic(card: CardInstance, game_state: GameState = null, player_index: int = -1) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var name: String = str(card.card_data.name)
	if _matches_name(name, SQUAWKABILLY_EX):
		if game_state != null and game_state.turn_number > 2:
			return -50.0
		return float(_setup_priority(name) * 3)
	var base: float = float(_setup_priority(name) * 3)
	var player: PlayerState = _get_player(game_state, player_index)
	if player != null and _current_phase(player) != PHASE_LAUNCH:
		if _matches_name(name, RAGING_BOLT_EX) and _count_pokemon_on_field(player, RAGING_BOLT_EX) < 2:
			base += 120.0
		if _matches_name(name, TEAL_MASK_OGERPON_EX) and _count_pokemon_on_field(player, TEAL_MASK_OGERPON_EX) < 2:
			base += 100.0
	return base


func _score_attach_energy(card: CardInstance, target_slot: PokemonSlot, game_state: GameState, player_index: int) -> float:
	if card == null or card.card_data == null or target_slot == null:
		return 0.0
	var player: PlayerState = _get_player(game_state, player_index)
	var phase: String = _current_phase(player)
	var energy_type: String = str(card.card_data.energy_provides)
	if _slot_matches(target_slot, RAGING_BOLT_EX):
		if energy_type not in ["L", "F"]:
			# G(\u53ca\u5176\u4ed6\u7c7b\u578b)\u5bf9\u7311\u96f7\u9f13\u65e0\u7528\u2014\u2014\u6781\u96f7\u8f70\u53ea\u9700 L+F
			return 80.0
		var gap: int = _preferred_attack_energy_gap(target_slot)
		if phase != PHASE_LAUNCH:
			if gap == 1:
				return 540.0
			if gap == 2:
				return 390.0
			if gap <= 0:
				return 170.0 if _has_follow_up_bolt(player) else 250.0
		if gap == 1:
			return 470.0
		if gap == 2:
			return 360.0
		return 260.0
	if _slot_matches(target_slot, TEAL_MASK_OGERPON_EX) and energy_type == "G":
		var gap: int = _attack_energy_gap(target_slot)
		if phase == PHASE_CONVERT:
			return 90.0 if gap > 0 else 40.0
		if phase == PHASE_PRESSURE and _has_follow_up_bolt(player):
			return 150.0 if gap > 0 else 70.0
		return 310.0 if gap > 0 else 160.0
	if player != null and target_slot == player.active_pokemon and _active_is_non_attacker(player):
		var retreat_cost: int = target_slot.get_card_data().retreat_cost if target_slot.get_card_data() != null else 0
		if target_slot.attached_energy.size() < retreat_cost:
			return 500.0
	return 50.0


func _score_attach_tool(card: CardInstance, target_slot: PokemonSlot) -> float:
	if card == null or target_slot == null:
		return 0.0
	if _card_matches(card, BRAVERY_CHARM):
		if _slot_matches(target_slot, RAGING_BOLT_EX):
			return 260.0
		if _slot_matches(target_slot, TEAL_MASK_OGERPON_EX):
			return 220.0
	return 50.0


func _score_trainer(card: CardInstance, game_state: GameState, player_index: int) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var name: String = str(card.card_data.name)
	var player: PlayerState = game_state.players[player_index]
	var phase: String = _current_phase(player)
	var churn_cooldown: bool = _should_cool_off_churn_trainers(player)
	if _matches_name(name, SADA):
		if _count_basic_energy_in_discard(player) >= 2 and _count_ancient_targets(player) >= 1:
			if phase == PHASE_CONVERT:
				return 170.0 if player.deck.size() <= 8 else 240.0
			if phase == PHASE_PRESSURE:
				return 420.0
			return 500.0
		return 220.0 if phase != PHASE_LAUNCH else 260.0
	if _matches_name(name, EARTHEN_VESSEL):
		if phase == PHASE_CONVERT:
			return 90.0 if player.deck.size() <= 8 else 110.0
		if phase == PHASE_PRESSURE and _has_follow_up_bolt(player):
			return 180.0
		return 390.0
	if _matches_name(name, ENERGY_RETRIEVAL):
		if phase == PHASE_CONVERT:
			return 110.0 if player.deck.size() <= 8 else 120.0
		if phase == PHASE_PRESSURE and _has_follow_up_bolt(player):
			return 210.0
		return 330.0 if _count_basic_energy_in_discard(player) >= 2 else 180.0
	if _matches_name(name, NEST_BALL):
		if phase != PHASE_LAUNCH and _bench_needs_backup(player):
			return 320.0
		if churn_cooldown:
			return 20.0
		return 260.0
	if name == "Boss's Orders" or name == "Prime Catcher":
		if _opponent_has_low_hp_support(game_state, player_index):
			return 520.0 if phase != PHASE_LAUNCH else 420.0
		return 280.0 if phase != PHASE_LAUNCH else 230.0
	if name == "Iono":
		if phase == PHASE_CONVERT and player.hand.size() > 3:
			return 120.0
		return 260.0 if player.hand.size() <= 3 else 170.0
	if _matches_name(name, POKEGEAR_30):
		if churn_cooldown:
			return 30.0
		return 220.0 if not _hand_has_supporter(player) else 120.0
	if name == "Trekking Shoes":
		return 15.0 if churn_cooldown else 80.0
	if name == "Hisuian Heavy Ball":
		return 10.0 if churn_cooldown else 80.0
	if name == "Pok\u00e9mon Catcher":
		return 20.0 if churn_cooldown else 80.0
	if name == "Temple of Sinnoh":
		return 240.0 if _opponent_has_special_energy_attached(game_state, player_index) else 120.0
	if _matches_name(name, BRAVERY_CHARM):
		return 240.0
	if _matches_name(name, SWITCH_CART):
		if _active_is_non_attacker(player):
			return 550.0
		return 180.0 if phase == PHASE_CONVERT and _has_attack_ready_raging_bolt(player) else 230.0
	if _matches_name(name, MAGMA_BASIN):
		return 150.0
	if _matches_name(name, PROFESSORS_RESEARCH):
		return 70.0 if churn_cooldown else 150.0
	return 80.0


func _score_ability(source_slot: PokemonSlot, game_state: GameState, player_index: int) -> float:
	if source_slot == null or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var phase: String = _current_phase(player)
	if _slot_matches(source_slot, TEAL_MASK_OGERPON_EX):
		if not _hand_has_basic_energy(player, "G"):
			return 30.0
		if phase == PHASE_CONVERT:
			if player.hand.size() >= 4:
				return 20.0
			return 50.0 if source_slot.count_energy_of_type("G") <= 0 else 25.0
		if phase == PHASE_PRESSURE and _has_follow_up_bolt(player):
			if player.hand.size() >= 4:
				return 40.0
			if source_slot.count_energy_of_type("G") >= 1:
				return 70.0
			return 120.0
		if _has_attack_ready_raging_bolt(player):
			if player.hand.size() >= 5:
				return 60.0
			if source_slot.count_energy_of_type("G") >= 1:
				return 120.0
		var attached_grass: int = source_slot.count_energy_of_type("G")
		if attached_grass == 0:
			return 420.0
		if attached_grass == 1:
			return 360.0
		return 260.0
	if _slot_matches(source_slot, SQUAWKABILLY_EX):
		if game_state.turn_number <= 2 and player.hand.size() >= 3:
			return 280.0
		return 80.0
	if _slot_matches(source_slot, RADIANT_GRENINJA):
		var has_any_energy: bool = _hand_has_basic_energy(player, "G") \
			or _hand_has_basic_energy(player, "L") \
			or _hand_has_basic_energy(player, "F")
		if not has_any_energy:
			return 5.0
		if phase == PHASE_LAUNCH and _count_ancient_targets(player) >= 1:
			if _hand_has_supporter(player):
				return 350.0
			return 260.0
		if phase == PHASE_PRESSURE:
			return 220.0
		if phase == PHASE_CONVERT:
			return 80.0
		return 200.0
	return 0.0


func _score_attack(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var player: PlayerState = _get_player(game_state, player_index)
	var phase: String = _current_phase(player)
	var projected_damage: int = int(action.get("projected_damage", 0))
	if projected_damage <= 0 and player != null and _slot_matches(player.active_pokemon, RAGING_BOLT_EX):
		var attack_index: int = int(action.get("attack_index", -1))
		var attack_name: String = str(action.get("attack_name", ""))
		if attack_index == 1 or attack_name == "Bellowing Thunder":
			projected_damage = _estimate_best_bellowing_thunder_damage(player, game_state, player_index)
	if projected_damage <= 0:
		if player != null and _slot_matches(player.active_pokemon, RAGING_BOLT_EX):
			if phase != PHASE_LAUNCH:
				return 5.0
			if player.hand.size() >= 5:
				return 20.0
			if _has_attack_ready_raging_bolt(player):
				return 10.0
		return 80.0
	if bool(action.get("projected_knockout", false)):
		return 920.0
	if phase == PHASE_CONVERT:
		if projected_damage >= 200:
			return 860.0
		if projected_damage >= 140:
			return 760.0
		return 620.0
	if phase == PHASE_PRESSURE:
		if projected_damage >= 200:
			return 840.0
		if projected_damage >= 140:
			return 740.0
		return 600.0
	if projected_damage >= 240:
		return 820.0
	if projected_damage >= 140:
		return 700.0
	return 520.0


func _score_retreat(target_slot: PokemonSlot, game_state: GameState = null, player_index: int = -1) -> float:
	if target_slot == null:
		return 0.0
	var player: PlayerState = _get_player(game_state, player_index)
	var stuck_bonus: float = 0.0
	if player != null and _active_is_non_attacker(player):
		stuck_bonus = 200.0
	if _slot_matches(target_slot, RAGING_BOLT_EX):
		var gap: int = _preferred_attack_energy_gap(target_slot)
		if gap <= 0:
			return 320.0 + stuck_bonus
		if gap == 1:
			return 220.0 + stuck_bonus
		return 120.0 + stuck_bonus * 0.5
	if _slot_matches(target_slot, TEAL_MASK_OGERPON_EX):
		var score: float = 150.0 if target_slot.count_energy_of_type("G") >= 1 else 90.0
		return score + stuck_bonus * 0.5
	if _slot_matches(target_slot, IRON_BUNDLE):
		return -20.0
	if _slot_matches(target_slot, SQUAWKABILLY_EX):
		return -10.0
	return 40.0


func _setup_priority(name: String) -> int:
	if _matches_name(name, RAGING_BOLT_EX):
		return 100
	if _matches_name(name, TEAL_MASK_OGERPON_EX):
		return 94
	if _matches_name(name, SQUAWKABILLY_EX):
		return 76
	if _matches_name(name, SLITHER_WING):
		return 70
	if _matches_name(name, IRON_BUNDLE):
		return 64
	return 30


func _estimate_heuristic_base(kind: String) -> float:
	match kind:
		"attack", "granted_attack":
			return 500.0
		"attach_energy":
			return 220.0
		"attach_tool":
			return 160.0
		"play_basic_to_bench":
			return 180.0
		"play_trainer":
			return 110.0
		"retreat":
			return 90.0
	return 10.0


func _count_basic_energy_in_discard(player: PlayerState) -> int:
	var count := 0
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and card.card_data.card_type == "Basic Energy":
			count += 1
	return count


func _count_ancient_targets(player: PlayerState) -> int:
	var count := 0
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and slot.get_card_data() != null and slot.get_card_data().is_ancient_pokemon():
			count += 1
	return count


func _score_assignment_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null:
		return 0.0
	var player: PlayerState = _get_player(context.get("game_state"), int(context.get("player_index", -1)))
	var phase: String = _current_phase(player)
	var source_card: CardInstance = context.get("source_card", null)
	if source_card != null and source_card.card_data != null:
		var energy_type: String = str(source_card.card_data.energy_provides)
		if energy_type == "G":
			if _slot_matches(slot, RAGING_BOLT_EX):
				return 80.0
			if _slot_matches(slot, TEAL_MASK_OGERPON_EX):
				if phase == PHASE_CONVERT:
					return 90.0 if _attack_energy_gap(slot) > 0 else 50.0
				if phase == PHASE_PRESSURE and _has_follow_up_bolt(player):
					return 160.0 if _attack_energy_gap(slot) > 0 else 110.0
				return 380.0 if _attack_energy_gap(slot) > 0 else 320.0
		elif energy_type in ["L", "F"]:
			if _slot_matches(slot, RAGING_BOLT_EX):
				if _energy_type_is_needed_for_attack(slot, energy_type):
					return 560.0 if slot == player.active_pokemon else 500.0
				return 420.0 if _preferred_attack_energy_gap(slot) <= 1 else 360.0
			if _slot_matches(slot, TEAL_MASK_OGERPON_EX):
				return 180.0
	if _slot_matches(slot, RAGING_BOLT_EX):
		return 320.0
	if _slot_matches(slot, TEAL_MASK_OGERPON_EX):
		return 260.0
	return 60.0


func _attack_energy_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null or slot.get_card_data().attacks.is_empty():
		return 999
	var attached: int = slot.attached_energy.size()
	var min_gap := 999
	for attack: Dictionary in slot.get_card_data().attacks:
		var gap: int = maxi(0, str(attack.get("cost", "")).length() - attached)
		min_gap = mini(min_gap, gap)
	return min_gap


func _preferred_attack_energy_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null or slot.get_card_data().attacks.is_empty():
		return 999
	if not _slot_matches(slot, RAGING_BOLT_EX):
		return _attack_energy_gap(slot)
	var attached: int = slot.attached_energy.size()
	var best_damage := -1
	var best_gap := 999
	for attack: Dictionary in slot.get_card_data().attacks:
		var damage_text: String = str(attack.get("damage", "0"))
		var damage: int = _parse_damage_value(damage_text)
		var effective_cost: int = str(attack.get("cost", "")).length()
		# 极雷轰 "70x"：弃能×70 伤害，至少需要 1 张额外能量才有伤害
		if damage > 0 and damage_text.ends_with("x"):
			effective_cost += 1
		var gap: int = maxi(0, effective_cost - attached)
		if damage > best_damage:
			best_damage = damage
			best_gap = gap
		elif damage == best_damage:
			best_gap = mini(best_gap, gap)
	return best_gap


func _active_is_non_attacker(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	var active: PokemonSlot = player.active_pokemon
	if _slot_matches(active, RAGING_BOLT_EX) and _preferred_attack_energy_gap(active) <= 1:
		return false
	if _slot_matches(active, TEAL_MASK_OGERPON_EX) and _attack_energy_gap(active) <= 0:
		return false
	if _slot_matches(active, SLITHER_WING) and _attack_energy_gap(active) <= 0:
		return false
	for slot: PokemonSlot in player.bench:
		if _slot_matches(slot, RAGING_BOLT_EX) and _preferred_attack_energy_gap(slot) <= 1:
			return true
	return false


func _count_pokemon_on_field(player: PlayerState, aliases: Array[String]) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in player.get_all_pokemon():
		if _slot_matches(slot, aliases):
			count += 1
	return count


func _has_attack_ready_raging_bolt(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		if _slot_matches(slot, RAGING_BOLT_EX) and _preferred_attack_energy_gap(slot) <= 0:
			return true
	return false


func _should_cool_off_churn_trainers(player: PlayerState) -> bool:
	if player == null:
		return false
	if _board_is_fully_developed(player):
		return true
	if _has_attack_ready_raging_bolt(player) and player.hand.size() >= 4:
		return true
	return player.deck.size() <= 8 and _count_near_ready_raging_bolts(player) >= 1


func _board_is_fully_developed(player: PlayerState) -> bool:
	if player == null:
		return false
	return _count_near_ready_raging_bolts(player) >= 2 \
		and _count_pokemon_on_field(player, TEAL_MASK_OGERPON_EX) >= 1


func _bench_needs_backup(player: PlayerState) -> bool:
	if player == null:
		return false
	return _count_pokemon_on_field(player, RAGING_BOLT_EX) < 2


func _current_phase(player: PlayerState) -> String:
	if player == null:
		return PHASE_LAUNCH
	var ready_count: int = _count_ready_raging_bolts(player)
	if ready_count <= 0:
		return PHASE_LAUNCH
	if _has_follow_up_bolt(player) or player.deck.size() <= 8:
		return PHASE_CONVERT
	return PHASE_PRESSURE


func _has_follow_up_bolt(player: PlayerState) -> bool:
	return _count_near_ready_raging_bolts(player) >= 2


func _count_ready_raging_bolts(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in player.get_all_pokemon():
		if _slot_matches(slot, RAGING_BOLT_EX) and _preferred_attack_energy_gap(slot) <= 0:
			count += 1
	return count


func _count_near_ready_raging_bolts(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in player.get_all_pokemon():
		if _slot_matches(slot, RAGING_BOLT_EX) and _preferred_attack_energy_gap(slot) <= 1:
			count += 1
	return count


func _get_player(game_state: GameState, player_index: int) -> PlayerState:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	return game_state.players[player_index]


func _estimate_best_bellowing_thunder_damage(player: PlayerState, game_state: GameState, player_index: int) -> int:
	if player == null:
		return 0
	var available: Array[CardInstance] = _collect_bellowing_thunder_energy_candidates(player)
	if available.is_empty():
		return 0
	var desired_count: int = _desired_bellowing_thunder_discard_count(
		player,
		_opponent_active_remaining_hp(game_state, player_index),
		available.size()
	)
	return estimate_bellowing_thunder_damage(desired_count)


func _pick_field_discard_items(cards: Array[CardInstance], player: PlayerState, context: Dictionary, max_select: int) -> Array:
	if cards.is_empty():
		return []
	var desired_count: int = _desired_bellowing_thunder_discard_count(
		player,
		_opponent_active_remaining_hp(context.get("game_state"), int(context.get("player_index", -1))),
		cards.size()
	)
	if desired_count <= 0:
		return []
	var sorted_cards: Array = cards.duplicate()
	sorted_cards.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		var score_a: float = _score_field_discard_candidate(a, player)
		var score_b: float = _score_field_discard_candidate(b, player)
		if is_equal_approx(score_a, score_b):
			return str(a.card_data.name) < str(b.card_data.name)
		return score_a > score_b
	)
	return sorted_cards.slice(0, mini(mini(max_select, desired_count), sorted_cards.size()))


func _pick_hand_discard_items(cards: Array[CardInstance], player: PlayerState, min_select: int, max_select: int) -> Array:
	if cards.is_empty() or max_select <= 0:
		return []
	var desired_count: int = maxi(min_select, 1)
	var sorted_cards: Array = cards.duplicate()
	sorted_cards.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		var score_a: float = _score_hand_discard_candidate(a, player)
		var score_b: float = _score_hand_discard_candidate(b, player)
		if is_equal_approx(score_a, score_b):
			return str(a.card_data.name) < str(b.card_data.name)
		return score_a > score_b
	)
	return sorted_cards.slice(0, mini(mini(max_select, desired_count), sorted_cards.size()))


func _desired_bellowing_thunder_discard_count(player: PlayerState, target_hp: int, available_count: int) -> int:
	if player == null or available_count <= 0:
		return 0
	if target_hp <= 0:
		return 0
	var lethal_count: int = int(ceili(float(target_hp) / 70.0))
	return mini(available_count, maxi(1, lethal_count))


func _collect_bellowing_thunder_energy_candidates(player: PlayerState) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	if player == null:
		return cards
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null:
			continue
		for energy: CardInstance in slot.attached_energy:
			if energy != null and energy.card_data != null and energy.card_data.card_type == "Basic Energy":
				cards.append(energy)
	return cards


func _score_field_discard_candidate(card: CardInstance, player: PlayerState) -> float:
	if card == null or card.card_data == null or player == null:
		return 0.0
	var holder: PokemonSlot = _find_energy_holder(player, card)
	if holder == null:
		return 0.0
	var energy_type: String = str(card.card_data.energy_provides)
	if holder == player.active_pokemon and _slot_matches(holder, RAGING_BOLT_EX):
		if _energy_card_is_essential_for_attack(holder, card):
			return 20.0
		return 620.0 if energy_type == "G" else 420.0
	if _slot_matches(holder, TEAL_MASK_OGERPON_EX):
		return 920.0 if energy_type == "G" else 780.0
	if _slot_matches(holder, RAGING_BOLT_EX):
		if _energy_card_is_essential_for_attack(holder, card):
			return 180.0
		return 720.0 if energy_type == "G" else 640.0
	return 500.0


func _score_hand_discard_candidate(card: CardInstance, player: PlayerState) -> float:
	if card == null or card.card_data == null or player == null:
		return 0.0
	var energy_type: String = str(card.card_data.energy_provides)
	var best_target: PokemonSlot = _best_sada_target_for_energy_type(player, energy_type)
	if best_target != null and _energy_type_is_needed_for_attack(best_target, energy_type):
		return 900.0
	if energy_type == "G":
		return 620.0
	if energy_type in ["L", "F"]:
		return 420.0
	return 120.0


func _pick_sada_energy_sources(items: Array, context: Dictionary, max_count: int) -> Array:
	var player: PlayerState = _get_player(context.get("game_state"), int(context.get("player_index", -1)))
	if player == null:
		return items.slice(0, mini(max_count, items.size()))
	var scored: Array[Dictionary] = []
	for item: Variant in items:
		if not (item is CardInstance):
			continue
		var card := item as CardInstance
		if card.card_data == null:
			continue
		var energy_type: String = str(card.card_data.energy_provides)
		var score: float = 100.0
		for slot: PokemonSlot in player.get_all_pokemon():
			if _slot_matches(slot, RAGING_BOLT_EX) and _energy_type_is_needed_for_attack(slot, energy_type):
				score = 900.0
				break
		if score < 900.0:
			if energy_type in ["L", "F"]:
				score = 500.0
			elif energy_type == "G":
				score = 300.0
		scored.append({"item": item, "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score))
	var result: Array = []
	for entry: Dictionary in scored.slice(0, mini(max_count, scored.size())):
		result.append(entry.item)
	return result


func _best_sada_target_for_energy_type(player: PlayerState, energy_type: String) -> PokemonSlot:
	if player == null:
		return null
	if _slot_matches(player.active_pokemon, RAGING_BOLT_EX) and _energy_type_is_needed_for_attack(player.active_pokemon, energy_type):
		return player.active_pokemon
	for slot: PokemonSlot in player.bench:
		if _slot_matches(slot, RAGING_BOLT_EX) and _energy_type_is_needed_for_attack(slot, energy_type):
			return slot
	if _slot_matches(player.active_pokemon, RAGING_BOLT_EX):
		return player.active_pokemon
	for slot: PokemonSlot in player.bench:
		if _slot_matches(slot, RAGING_BOLT_EX):
			return slot
	return null


func _all_cards_attached_to_field(cards: Array[CardInstance], player: PlayerState) -> bool:
	if player == null or cards.is_empty():
		return false
	for card: CardInstance in cards:
		if _find_energy_holder(player, card) == null:
			return false
	return true


func _find_energy_holder(player: PlayerState, card: CardInstance) -> PokemonSlot:
	if player == null or card == null:
		return null
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and card in slot.attached_energy:
			return slot
	return null


func _energy_type_is_needed_for_attack(slot: PokemonSlot, energy_type: String) -> bool:
	if slot == null or energy_type == "":
		return false
	return int(_preferred_attack_requirements(slot).get(energy_type, 0)) > slot.count_energy_of_type(energy_type)


func _energy_card_is_essential_for_attack(slot: PokemonSlot, card: CardInstance) -> bool:
	if slot == null or card == null or card.card_data == null:
		return false
	var energy_type: String = str(card.card_data.energy_provides)
	var required: int = int(_preferred_attack_requirements(slot).get(energy_type, 0))
	if required <= 0:
		return false
	return slot.count_energy_of_type(energy_type) <= required


func _preferred_attack_requirements(slot: PokemonSlot) -> Dictionary:
	var requirements := {}
	if slot == null or slot.get_card_data() == null:
		return requirements
	var attacks: Array = slot.get_card_data().attacks
	var best_attack: Dictionary = {}
	var best_damage := -1
	for attack: Dictionary in attacks:
		var damage: int = _parse_damage_value(str(attack.get("damage", "0")))
		if damage > best_damage:
			best_damage = damage
			best_attack = attack
	var cost: String = str(best_attack.get("cost", ""))
	for i: int in cost.length():
		var symbol: String = cost.substr(i, 1)
		requirements[symbol] = int(requirements.get(symbol, 0)) + 1
	return requirements


func _opponent_active_remaining_hp(game_state: GameState, player_index: int) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null or opponent.active_pokemon == null:
		return 0
	return opponent.active_pokemon.get_remaining_hp()


func _is_basic_pokemon(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.card_type == "Pokemon" and str(card.card_data.stage) == "Basic"


func _slot_matches(slot: PokemonSlot, aliases: Array[String]) -> bool:
	return slot != null and _matches_name(str(slot.get_pokemon_name()), aliases)


func _card_matches(card: CardInstance, aliases: Array[String]) -> bool:
	return card != null and card.card_data != null and _matches_name(str(card.card_data.name), aliases)


func _matches_name(name: String, aliases: Array[String]) -> bool:
	for alias: String in aliases:
		if name == alias:
			return true
	return false


func _parse_damage_value(damage_text: String) -> int:
	var digits := ""
	for i: int in damage_text.length():
		var ch := damage_text[i]
		if ch >= "0" and ch <= "9":
			digits += ch
	return int(digits) if digits != "" else 0


func _score_energy_search_candidate(card: CardInstance, context: Dictionary) -> float:
	if card == null or card.card_data == null:
		return 40.0
	var player: PlayerState = _get_player(context.get("game_state"), int(context.get("player_index", -1)))
	var energy_type: String = str(card.card_data.energy_provides)
	if player == null:
		return 40.0
	for slot: PokemonSlot in player.get_all_pokemon():
		if _slot_matches(slot, RAGING_BOLT_EX) and _energy_type_is_needed_for_attack(slot, energy_type):
			return 500.0
	if energy_type == "G":
		for slot: PokemonSlot in player.get_all_pokemon():
			if _slot_matches(slot, TEAL_MASK_OGERPON_EX):
				return 300.0
	return 100.0


func _hand_has_basic_energy(player: PlayerState, energy_type: String) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		if card.card_data.card_type == "Basic Energy" and str(card.card_data.energy_provides) == energy_type:
			return true
	return false


func _hand_has_supporter(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.card_type == "Supporter":
			return true
	return false


func _opponent_has_special_energy_attached(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	for slot: PokemonSlot in game_state.players[1 - player_index].get_all_pokemon():
		if slot == null:
			continue
		for energy: CardInstance in slot.attached_energy:
			if energy != null and energy.card_data != null and energy.card_data.card_type == "Special Energy":
				return true
	return false


func _opponent_has_low_hp_support(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	for slot: PokemonSlot in game_state.players[1 - player_index].bench:
		if slot == null or slot.get_top_card() == null:
			continue
		if slot.get_remaining_hp() <= 180:
			return true
	return false


# ============================================================
#  Turn Plan / Turn Contract
# ============================================================


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	var phase: String = _current_phase(player)
	var discard_fuel: int = _count_basic_energy_in_discard(player)
	var hand_has_sada: bool = _hand_has_card(player, SADA)
	var hand_has_ev: bool = _hand_has_card(player, EARTHEN_VESSEL)
	var hand_has_er: bool = _hand_has_card(player, ENERGY_RETRIEVAL)
	var active_stuck: bool = _active_is_non_attacker(player)
	var ready_bolts: int = _count_ready_raging_bolts(player)
	var near_ready_bolts: int = _count_near_ready_raging_bolts(player)
	var bolts_on_field: int = _count_pokemon_on_field(player, RAGING_BOLT_EX)
	var ogerpon_on_field: int = _count_pokemon_on_field(player, TEAL_MASK_OGERPON_EX)

	var intent: String = "setup_board"
	if active_stuck:
		intent = "emergency_retreat"
	elif ready_bolts >= 1 and near_ready_bolts >= 2:
		intent = "convert_attack"
	elif ready_bolts >= 1 and near_ready_bolts < 2:
		intent = "pressure_expand"
	elif discard_fuel >= 2 and hand_has_sada and bolts_on_field >= 1:
		intent = "charge_bolt"
	elif discard_fuel < 2 and bolts_on_field >= 1:
		intent = "fuel_discard"

	var primary_attacker_name: String = _find_best_charge_bolt_name(player)
	var bridge_target_name: String = primary_attacker_name if intent in ["charge_bolt", "fuel_discard"] else ""
	var pivot_target_name: String = ""
	if intent == "pressure_expand":
		pivot_target_name = _find_backup_target_name(player, primary_attacker_name)

	var flags: Dictionary = {
		"hand_has_sada": hand_has_sada,
		"hand_has_earthen_vessel": hand_has_ev,
		"hand_has_energy_retrieval": hand_has_er,
		"discard_has_fuel": discard_fuel >= 2,
		"active_is_stuck": active_stuck,
		"opponent_has_value_target": _opponent_has_low_hp_support(game_state, player_index),
		"bolts_on_field": bolts_on_field,
		"ogerpon_on_field": ogerpon_on_field,
	}

	var constraints: Dictionary = {}
	if intent == "charge_bolt" and hand_has_sada:
		constraints["forbid_draw_supporter_waste"] = true
	if intent == "convert_attack":
		constraints["forbid_engine_churn"] = true

	return {
		"intent": intent,
		"phase": phase,
		"flags": flags,
		"targets": {
			"primary_attacker_name": primary_attacker_name,
			"bridge_target_name": bridge_target_name,
			"pivot_target_name": pivot_target_name,
		},
		"constraints": constraints,
		"context": context.duplicate(true),
	}


func _find_best_charge_bolt_name(player: PlayerState) -> String:
	if player == null:
		return ""
	var best_name: String = ""
	var best_gap: int = 999
	for slot: PokemonSlot in player.get_all_pokemon():
		if not _slot_matches(slot, RAGING_BOLT_EX):
			continue
		var gap: int = _preferred_attack_energy_gap(slot)
		if gap < best_gap:
			best_gap = gap
			best_name = str(slot.get_pokemon_name())
	return best_name


func _find_backup_target_name(player: PlayerState, exclude_name: String) -> String:
	if player == null:
		return ""
	for slot: PokemonSlot in player.bench:
		if slot == null:
			continue
		if _slot_matches(slot, RAGING_BOLT_EX):
			var n: String = str(slot.get_pokemon_name())
			if n != exclude_name or _count_pokemon_on_field(player, RAGING_BOLT_EX) >= 2:
				return n
	for slot: PokemonSlot in player.bench:
		if slot == null:
			continue
		if _slot_matches(slot, TEAL_MASK_OGERPON_EX):
			return str(slot.get_pokemon_name())
	return ""


func _hand_has_card(player: PlayerState, aliases: Array[String]) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and _matches_name(str(card.card_data.name), aliases):
			return true
	return false


func _is_draw_supporter(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	var name: String = str(card.card_data.name)
	return name == "Iono" or _matches_name(name, PROFESSORS_RESEARCH) or name == "Judge"


# ============================================================
#  Turn Plan Bonus — intent-driven score adjustments
# ============================================================


func _apply_turn_plan_bonus(kind: String, action: Dictionary, game_state: GameState, player_index: int, base_score: float) -> float:
	var contract: Dictionary = _turn_contract_context
	if contract.is_empty():
		return 0.0
	var intent: String = str(contract.get("intent", ""))
	if intent == "":
		return 0.0
	var flags: Dictionary = contract.get("flags", {}) if contract.get("flags", {}) is Dictionary else {}
	var targets: Dictionary = contract.get("targets", {}) if contract.get("targets", {}) is Dictionary else {}
	var player: PlayerState = _get_player(game_state, player_index)

	match intent:
		"fuel_discard":
			return _bonus_fuel_discard(kind, action, player, flags)
		"charge_bolt":
			return _bonus_charge_bolt(kind, action, player, flags, targets)
		"emergency_retreat":
			return _bonus_emergency_retreat(kind, action, player, flags)
		"pressure_expand":
			return _bonus_pressure_expand(kind, action, player, flags, targets)
		"convert_attack":
			return _bonus_convert_attack(kind, action, game_state, player_index, flags)
	return 0.0


func _bonus_fuel_discard(kind: String, action: Dictionary, player: PlayerState, flags: Dictionary) -> float:
	if kind == "play_trainer":
		var card: CardInstance = action.get("card")
		if _card_matches(card, EARTHEN_VESSEL):
			return 100.0
		if _is_draw_supporter(card) and (bool(flags.get("hand_has_earthen_vessel", false)) or bool(flags.get("hand_has_energy_retrieval", false))):
			return -80.0
	if kind == "use_ability":
		var slot: PokemonSlot = action.get("source_slot")
		if _slot_matches(slot, RADIANT_GRENINJA):
			return 80.0
	return 0.0


func _bonus_charge_bolt(kind: String, action: Dictionary, player: PlayerState, flags: Dictionary, targets: Dictionary) -> float:
	if kind == "play_trainer":
		var card: CardInstance = action.get("card")
		if _card_matches(card, SADA):
			return 80.0
		if _is_draw_supporter(card) and bool(flags.get("hand_has_sada", false)):
			return -150.0
	if kind == "attach_energy":
		var target_slot: PokemonSlot = action.get("target_slot")
		if target_slot != null and _slot_matches(target_slot, RAGING_BOLT_EX):
			var primary_name: String = str(targets.get("primary_attacker_name", ""))
			if primary_name != "" and str(target_slot.get_pokemon_name()) == primary_name:
				return 60.0
	return 0.0


func _bonus_emergency_retreat(kind: String, action: Dictionary, player: PlayerState, flags: Dictionary) -> float:
	if kind == "play_trainer":
		var card: CardInstance = action.get("card")
		if _card_matches(card, SWITCH_CART):
			return 100.0
	if kind == "retreat":
		var target: PokemonSlot = action.get("bench_target")
		if target != null and _slot_matches(target, RAGING_BOLT_EX) and _preferred_attack_energy_gap(target) <= 0:
			return 100.0
	if kind == "attach_energy" and player != null:
		var target_slot: PokemonSlot = action.get("target_slot")
		if target_slot != null and target_slot == player.active_pokemon:
			return 80.0
	return 0.0


func _bonus_pressure_expand(kind: String, action: Dictionary, player: PlayerState, flags: Dictionary, targets: Dictionary) -> float:
	if kind == "play_trainer":
		var card: CardInstance = action.get("card")
		if _card_matches(card, NEST_BALL):
			return 60.0
	if kind == "play_basic_to_bench":
		var card: CardInstance = action.get("card")
		if card != null and card.card_data != null:
			var name: String = str(card.card_data.name)
			if _matches_name(name, RAGING_BOLT_EX) or _matches_name(name, TEAL_MASK_OGERPON_EX):
				return 60.0
	if kind == "attach_energy":
		var target_slot: PokemonSlot = action.get("target_slot")
		if target_slot != null and _slot_matches(target_slot, RAGING_BOLT_EX):
			var pivot_name: String = str(targets.get("pivot_target_name", ""))
			if pivot_name != "" and str(target_slot.get_pokemon_name()) == pivot_name:
				return 40.0
	return 0.0


func _bonus_convert_attack(kind: String, action: Dictionary, game_state: GameState, player_index: int, flags: Dictionary) -> float:
	if kind in ["attack", "granted_attack"]:
		return 80.0
	if kind == "play_trainer":
		var card: CardInstance = action.get("card")
		if card != null and card.card_data != null:
			var name: String = str(card.card_data.name)
			if (name == "Boss's Orders" or name == "Prime Catcher") and bool(flags.get("opponent_has_value_target", false)):
				return 60.0
	return 0.0


# ============================================================
#  Handoff Scoring — 被击倒后选谁上场
# ============================================================


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if not (item is PokemonSlot):
		return score_interaction_target(item, step, context)
	var slot: PokemonSlot = item as PokemonSlot
	if slot == null or slot.get_card_data() == null:
		return 0.0
	if _slot_matches(slot, RAGING_BOLT_EX):
		var gap: int = _preferred_attack_energy_gap(slot)
		if gap <= 0:
			return 800.0
		if gap == 1:
			return 500.0
		return 250.0
	if _slot_matches(slot, TEAL_MASK_OGERPON_EX):
		return 300.0 if slot.count_energy_of_type("G") >= 1 else 180.0
	if _slot_matches(slot, SLITHER_WING):
		return 200.0
	if _slot_matches(slot, SQUAWKABILLY_EX) or _slot_matches(slot, RADIANT_GRENINJA) or _slot_matches(slot, IRON_BUNDLE):
		return -50.0
	return 40.0
