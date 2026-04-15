class_name DeckStrategyArceusGiratina
extends "res://scripts/ai/DeckStrategyBase.gd"


const NeuralNetInferenceScript = preload("res://scripts/ai/NeuralNetInference.gd")
const ArceusGiratinaStateEncoderScript = preload("res://scripts/ai/ArceusGiratinaStateEncoder.gd")

var _value_net: RefCounted = null
var _encoder_class: GDScript = ArceusGiratinaStateEncoderScript

const ARCEUS_V := "Arceus V"
const ARCEUS_VSTAR := "Arceus VSTAR"
const GIRATINA_V := "Giratina V"
const GIRATINA_VSTAR := "Giratina VSTAR"
const BIDOOF := "Bidoof"
const BIBAREL := "Bibarel"
const SKWOVET := "Skwovet"
const IRON_LEAVES_EX := "Iron Leaves ex"
const RADIANT_GARDEVOIR := "Radiant Gardevoir"
const CHARMANDER := "Charmander"
const CHARMELEON := "Charmeleon"
const CHARIZARD_EX := "Charizard ex"
const PIDGEY := "Pidgey"
const PIDGEOT_EX := "Pidgeot ex"

const ULTRA_BALL := "Ultra Ball"
const NEST_BALL := "Nest Ball"
const CAPTURING_AROMA := "Capturing Aroma"
const BOSSS_ORDERS := "Boss's Orders"
const IONO := "Iono"
const JUDGE := "Judge"
const LOST_VACUUM := "Lost Vacuum"
const LOST_CITY := "Lost City"
const SWITCH := "Switch"
const MAXIMUM_BELT := "Maximum Belt"
const CHOICE_BELT := "Choice Belt"

const DOUBLE_TURBO_ENERGY := "Double Turbo Energy"
const GRASS_ENERGY := "Grass Energy"
const PSYCHIC_ENERGY := "Psychic Energy"
const JET_ENERGY := "Jet Energy"


func get_strategy_id() -> String:
	return "arceus_giratina"


func get_signature_names() -> Array[String]:
	return [ARCEUS_V, ARCEUS_VSTAR, GIRATINA_V, GIRATINA_VSTAR]


func get_state_encoder_class() -> GDScript:
	return _encoder_class


func load_value_net(path: String) -> bool:
	var net := NeuralNetInferenceScript.new()
	if net.load_weights(path):
		_value_net = net
		return true
	_value_net = null
	return false


func get_value_net() -> RefCounted:
	return _value_net


func get_mcts_config() -> Dictionary:
	return {
		"branch_factor": 3,
		"time_budget_ms": 2100,
		"rollouts_per_sequence": 0,
	}


func plan_opening_setup(player: PlayerState) -> Dictionary:
	var basics: Array[Dictionary] = []
	for i: int in player.hand.size():
		var card: CardInstance = player.hand[i]
		if card == null or not card.is_basic_pokemon():
			continue
		basics.append({"index": i, "score": _setup_priority(card, player)})
	if basics.is_empty():
		return {"active_hand_index": -1, "bench_hand_indices": []}
	basics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	var active_index: int = int(basics[0].get("index", -1))
	var bench_indices: Array[int] = []
	var chosen_names: Array[String] = []
	if active_index >= 0 and active_index < player.hand.size():
		chosen_names.append(_card_name(player.hand[active_index]))
	var desired_shell: Array[String] = [ARCEUS_V, ARCEUS_V, GIRATINA_V, BIDOOF, SKWOVET]
	for desired: String in desired_shell:
		for entry: Dictionary in basics:
			var idx: int = int(entry.get("index", -1))
			if idx == active_index or bench_indices.has(idx):
				continue
			var card_name := _card_name(player.hand[idx])
			if card_name != desired:
				continue
			if desired == ARCEUS_V and chosen_names.count(ARCEUS_V) >= 2:
				continue
			if desired == GIRATINA_V and chosen_names.count(GIRATINA_V) >= 1:
				continue
			if desired == BIDOOF and chosen_names.count(BIDOOF) >= 1:
				continue
			if desired == SKWOVET and chosen_names.count(SKWOVET) >= 1:
				continue
			bench_indices.append(idx)
			chosen_names.append(card_name)
			break
	if chosen_names.count(ARCEUS_V) >= 2 and chosen_names.count(GIRATINA_V) >= 1 and chosen_names.count(BIDOOF) >= 1 and chosen_names.count(SKWOVET) >= 1:
		return {"active_hand_index": active_index, "bench_hand_indices": bench_indices}
	for entry: Dictionary in basics:
		var idx: int = int(entry.get("index", -1))
		if idx == active_index or bench_indices.has(idx):
			continue
		bench_indices.append(idx)
		if bench_indices.size() >= 5:
			break
	return {"active_hand_index": active_index, "bench_hand_indices": bench_indices}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var phase := _detect_phase(game_state, player)
	match str(action.get("kind", "")):
		"play_basic_to_bench":
			return _score_play_basic(action.get("card", null), game_state, player, player_index, phase)
		"evolve":
			return _score_evolve(action.get("card", null), player, phase)
		"play_stadium":
			return _score_stadium(action.get("card", null), game_state, player, player_index, phase)
		"play_trainer":
			return _score_trainer(action, game_state, player, player_index, phase)
		"attach_energy":
			return _score_attach(action.get("card", null), action.get("target_slot", null), game_state, player, phase)
		"attach_tool":
			return _score_attach_tool(action, game_state, player, player_index, phase)
		"use_ability":
			return _score_use_ability(action.get("source_slot", null), game_state, player, phase)
		"retreat":
			return _score_retreat(action, game_state, player, player_index, phase)
		"attack", "granted_attack":
			return _score_attack(action, game_state, player_index, phase)
	return 0.0


func score_action(action: Dictionary, context: Dictionary) -> float:
	return score_action_absolute(action, context.get("game_state", null), int(context.get("player_index", -1)))


func evaluate_board(game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var phase := _detect_phase(game_state, player)
	var score := 0.0
	for slot: PokemonSlot in _all_slots(player):
		var name := _slot_name(slot)
		if name == ARCEUS_VSTAR:
			score += 860.0
			score += float(slot.attached_energy.size()) * 90.0
		elif name == ARCEUS_V:
			score += 360.0
			score += float(slot.attached_energy.size()) * 70.0
		elif name == GIRATINA_VSTAR:
			score += 780.0
			score += float(slot.attached_energy.size()) * 88.0
		elif name == GIRATINA_V:
			score += 290.0
			score += float(slot.attached_energy.size()) * 60.0
		elif name == BIBAREL:
			score += 240.0
		elif name == BIDOOF:
			score += 120.0
		elif name == RADIANT_GARDEVOIR:
			score += 110.0
		score += float(slot.get_remaining_hp()) * 0.09
	var best_arceus := _best_arceus_slot(player)
	if best_arceus != null and _attack_energy_gap(best_arceus) <= 0:
		score += 260.0
	if _best_giratina_slot(player) != null and _attack_energy_gap(_best_giratina_slot(player)) <= 1:
		score += 220.0
	if phase == "transition":
		score += 120.0
	if phase == "convert":
		score += 220.0
	if _count_named_on_field(player, BIBAREL) > 0:
		score += 90.0
	if _count_named_on_field(player, SKWOVET) > 0 and _count_named_on_field(player, BIBAREL) > 0:
		score += 70.0
	if _core_shell_complete(player):
		score += 140.0
	if _target_formation_complete(player):
		score += 220.0
	return score


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var attached := _effective_energy_count(slot) + extra_context
	var best_damage := 0
	var can_attack := false
	for attack: Dictionary in slot.get_card_data().attacks:
		var cost: String = str(attack.get("cost", ""))
		var damage: int = _parse_damage(str(attack.get("damage", "0")))
		if attached >= cost.length():
			can_attack = true
			best_damage = maxi(best_damage, damage)
	return {"damage": best_damage, "can_attack": can_attack, "description": ""}


func get_discard_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	var name := _card_name(card)
	if name == RADIANT_GARDEVOIR:
		return 240
	if name == IRON_LEAVES_EX:
		return 235
	if name == SKWOVET:
		return 180
	if name == LOST_CITY:
		return 170
	if name == LOST_VACUUM:
		return 160
	if name == MAXIMUM_BELT or name == CHOICE_BELT:
		return 150
	if name == BIBAREL:
		return 80
	if name == BIDOOF:
		return 60
	if name == DOUBLE_TURBO_ENERGY:
		return 30
	if card.card_data.is_energy():
		return 90
	return 120


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	var priority := get_discard_priority(card)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return priority
	var player: PlayerState = game_state.players[player_index]
	var name := _card_name(card)
	if name == RADIANT_GARDEVOIR:
		return 25 if _should_deploy_radiant_gardevoir(game_state, player, player_index) else 240
	if name == IRON_LEAVES_EX:
		return 30 if _should_deploy_iron_leaves(game_state, player, player_index) else 235
	if name == DOUBLE_TURBO_ENERGY and _count_named_on_field(player, ARCEUS_V) + _count_named_on_field(player, ARCEUS_VSTAR) == 0:
		return 0
	if name == GIRATINA_VSTAR and _count_named_on_field(player, GIRATINA_V) > 0 and _count_named_on_field(player, GIRATINA_VSTAR) == 0:
		return 20
	if name == BIDOOF and _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) == 0:
		return 15
	return priority


func get_search_priority(card: CardInstance) -> int:
	return _search_score(card, null, -1)


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var step_id := str(step.get("id", ""))
	if step_id != "energy_assignments":
		return []
	var card_items: Array[CardInstance] = []
	for item: Variant in items:
		if item is CardInstance:
			card_items.append(item as CardInstance)
	if card_items.is_empty():
		return []
	return _pick_energy_assignment_sources(card_items, int(step.get("max_select", card_items.size())), context)


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", ""))
	if item is CardInstance:
		var card := item as CardInstance
		if step_id in ["search_pokemon", "search_cards", "search_item"]:
			return float(_search_score(card, context.get("game_state", null), int(context.get("player_index", -1))))
		if step_id in ["discard_card", "discard_cards"]:
			return float(get_discard_priority_contextual(card, context.get("game_state", null), int(context.get("player_index", -1))))
		if step_id == "energy_assignments":
			return _score_energy_assignment_source(card, context)
	if item is PokemonSlot and step_id in ["assignment_target", "energy_assignment", "energy_assignments"]:
		return _assignment_target_score(item as PokemonSlot, context)
	if item is PokemonSlot and step_id in ["send_out", "switch_target", "self_switch_target", "pivot_target", "heavy_baton_target"]:
		return _score_handoff_target(item as PokemonSlot, step_id, context)
	return 0.0


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", ""))
	if item is PokemonSlot and step_id in ["send_out", "switch_target", "self_switch_target", "pivot_target", "heavy_baton_target"]:
		return _score_handoff_target(item as PokemonSlot, step_id, context)
	return score_interaction_target(item, step, context)


func _setup_priority(card_or_name: Variant, player: PlayerState) -> float:
	var name := ""
	var retreat_cost := 99
	if card_or_name is CardInstance:
		var card := card_or_name as CardInstance
		name = _card_name(card)
		if card != null and card.card_data != null:
			retreat_cost = int(card.card_data.retreat_cost)
	else:
		name = str(card_or_name)
	if name == ARCEUS_V:
		return 380.0
	if retreat_cost <= 1:
		if name == BIDOOF:
			return 300.0
		if name == SKWOVET:
			return 290.0
		return 260.0
	if name == GIRATINA_V:
		return 280.0 if _count_named_in_hand(player, ARCEUS_V) > 0 else 250.0
	if name == BIDOOF:
		return 220.0
	if name == SKWOVET:
		return 170.0
	if name == RADIANT_GARDEVOIR:
		return -120.0
	if name == IRON_LEAVES_EX:
		return -110.0
	return 100.0


func _score_play_basic(card: CardInstance, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	if card == null or card.card_data == null or player.is_bench_full():
		return 0.0
	var name := _card_name(card)
	var keep_backup_arceus_live := _should_force_backup_arceus_shell(game_state, player, player_index, phase)
	if _target_formation_complete(player):
		return 0.0
	if _should_cool_off_draw_churn(player):
		return 0.0
	if _should_cool_off_post_launch_shell_padding(player, phase) and name in [ARCEUS_V, BIDOOF, SKWOVET]:
		if not (name == ARCEUS_V and keep_backup_arceus_live):
			return 0.0
	if _core_shell_complete(player) and name not in [ARCEUS_V, GIRATINA_V, BIDOOF, SKWOVET]:
		return 0.0
	if name == ARCEUS_V:
		if _count_arceus_total(player) >= 2:
			return 0.0
		if keep_backup_arceus_live:
			return 420.0
		return 360.0
	if name == GIRATINA_V:
		if _count_giratina_total(player) >= 1:
			return 0.0
		return 300.0 if phase != "convert" else 190.0
	if name == BIDOOF:
		return 260.0 if _count_bibarel_line_total(player) == 0 else 0.0
	if name == SKWOVET:
		return 210.0 if _count_named_on_field(player, SKWOVET) == 0 else 0.0
	if name == RADIANT_GARDEVOIR:
		if _count_named_on_field(player, RADIANT_GARDEVOIR) > 0:
			return 0.0
		return 145.0 if _should_deploy_radiant_gardevoir(game_state, player, player_index) else -140.0
	if name == IRON_LEAVES_EX:
		if _can_iron_leaves_take_charizard_ko_this_turn(game_state, player, player_index):
			return 760.0 if phase != "launch" else 620.0
		if _should_deploy_iron_leaves(game_state, player, player_index):
			return 210.0 if phase == "convert" else 150.0
		return -120.0
	return 80.0


func _score_evolve(card: CardInstance, player: PlayerState, phase: String) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var name := _card_name(card)
	if name == ARCEUS_VSTAR:
		var arceus := _best_arceus_slot(player)
		if arceus != null and _attack_energy_gap(arceus) <= 1:
			return 940.0
		return 820.0
	if name == GIRATINA_VSTAR:
		if _best_arceus_slot(player) != null and phase != "launch":
			return 760.0
		return 620.0
	if name == BIBAREL:
		return 540.0 if _count_named_on_field(player, BIBAREL) == 0 else 260.0
	return 100.0


func _score_stadium(card: CardInstance, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var name := _card_name(card)
	if name != LOST_CITY:
		return 0.0
	if game_state != null and game_state.stadium_card != null and _card_name(game_state.stadium_card) == LOST_CITY:
		return 0.0
	if phase == "convert":
		return 180.0
	if _is_launch_online(player):
		return 140.0
	return 80.0


func _score_trainer(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	var card: CardInstance = action.get("card", null)
	if card == null or card.card_data == null:
		return 0.0
	var name := _card_name(card)
	var cool_off_draw_churn := _should_cool_off_draw_churn(player)
	var cool_off_conversion_churn := _should_cool_off_conversion_churn(player)
	var launch_online := _is_launch_online(player)
	var needs_transition := _needs_transition_piece(player)
	var thin_shell := _shell_is_thin(player)
	var severe_shell_gap := _needs_shell_rebuild(player)
	var hand_arceus_live := _can_bench_hand_arceus(player)
	var charizard_reentry_engine_cooloff := _should_cool_off_charizard_reentry_engine(game_state, player, player_index, phase)
	if cool_off_draw_churn and name in [NEST_BALL, ULTRA_BALL, CAPTURING_AROMA, IONO, JUDGE]:
		if not severe_shell_gap:
			return 0.0
	if cool_off_conversion_churn and name in [NEST_BALL, ULTRA_BALL, CAPTURING_AROMA, IONO, JUDGE]:
		if not severe_shell_gap:
			return 0.0
	if charizard_reentry_engine_cooloff:
		if name in [IONO, JUDGE]:
			return 0.0
	if name == ULTRA_BALL:
		if _count_named_on_field(player, ARCEUS_V) + _count_named_on_field(player, ARCEUS_VSTAR) == 0:
			if hand_arceus_live:
				return 280.0
			return 560.0
		if _count_arceus_total(player) == 1:
			if hand_arceus_live:
				return 300.0 if thin_shell else 250.0
			return 680.0 if thin_shell else 520.0
		if _count_named_on_field(player, ARCEUS_V) > 0 and _count_named_on_field(player, ARCEUS_VSTAR) == 0:
			return 500.0
		if _count_named_on_field(player, GIRATINA_V) == 0:
			return 470.0
		if launch_online and needs_transition:
			return 430.0
		if _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) == 0:
			return 360.0
		return 240.0
	if name == NEST_BALL:
		if _count_named_on_field(player, ARCEUS_V) + _count_named_on_field(player, ARCEUS_VSTAR) == 0:
			if hand_arceus_live:
				return 240.0
			return 480.0
		if _count_arceus_total(player) == 1:
			if hand_arceus_live:
				return 260.0
			return 620.0 if thin_shell else 430.0
		if _count_named_on_field(player, GIRATINA_V) == 0:
			return 360.0
		if _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) == 0:
			return 320.0
		return 180.0
	if name == CAPTURING_AROMA:
		if _count_arceus_total(player) == 1:
			if hand_arceus_live:
				return 320.0 if thin_shell else 240.0
			return 900.0 if severe_shell_gap else (760.0 if thin_shell else 560.0)
		if _count_named_on_field(player, ARCEUS_V) + _count_named_on_field(player, ARCEUS_VSTAR) == 0 and hand_arceus_live:
			return 260.0
		if _count_named_on_field(player, ARCEUS_V) > 0 and _count_named_on_field(player, ARCEUS_VSTAR) == 0:
			return 420.0
		if _count_named_on_field(player, GIRATINA_V) == 0:
			return 320.0
		if launch_online and needs_transition:
			return 300.0
		return 160.0
	if name == BOSSS_ORDERS:
		var active := player.active_pokemon
		var target_slot: PokemonSlot = action.get("target_slot", null)
		var active_ready := active != null and _attack_energy_gap(active) <= 0
		if active_ready and target_slot != null and _best_attack_damage(active) >= target_slot.get_remaining_hp():
			return 620.0
		if phase == "convert" and active_ready:
			return 180.0
		return 0.0
	if name == IONO:
		if severe_shell_gap and player.hand.size() <= 4 and phase != "convert" and not _player_is_ahead_in_prizes(game_state, player_index):
			return 920.0
		if _player_is_behind_in_prizes(game_state, player_index):
			return 320.0 if player.hand.size() >= 4 else 250.0
		return 130.0 if player.hand.size() <= 3 else 80.0
	if name == JUDGE:
		if _player_is_ahead_in_prizes(game_state, player_index):
			return 310.0 if phase != "launch" else 240.0
		return 150.0 if phase != "launch" else 100.0
	if name == SWITCH:
		if _active_should_hand_off_to_ready_bench(player):
			return 360.0
		return 80.0
	if name == LOST_CITY:
		return 170.0 if phase != "launch" else 90.0
	if name == LOST_VACUUM:
		if game_state != null and game_state.stadium_card != null:
			return 180.0
		for slot: PokemonSlot in _all_slots(game_state.players[1 - player_index] if game_state != null else null):
			if slot != null and slot.attached_tool != null:
				return 170.0
		for slot: PokemonSlot in _all_slots(player):
			if slot != null and slot.attached_tool != null:
				return 120.0
		return 0.0
	return 90.0


func _score_attach(card: CardInstance, target_slot: PokemonSlot, game_state: GameState, player: PlayerState, phase: String) -> float:
	if card == null or card.card_data == null or target_slot == null:
		return 0.0
	var target_name := _slot_name(target_slot)
	var card_name := _card_name(card)
	var arceus_total := _count_named_on_field(player, ARCEUS_V) + _count_named_on_field(player, ARCEUS_VSTAR)
	if _should_hold_non_arceus_attach_for_hand_arceus(player, target_slot, phase):
		return 0.0
	var pivot_fallback_live := _should_enable_pivot_fallback_attach(player, target_slot, phase)
	var active_giratina_fallback_live := _should_enable_active_giratina_fallback_attach(player, target_slot, phase)
	if phase == "launch" and arceus_total == 0 and target_name not in [ARCEUS_V, ARCEUS_VSTAR] and not pivot_fallback_live and not active_giratina_fallback_live:
		return 0.0
	var arceus_ready := false
	var arceus := _best_arceus_slot(player)
	var backup_arceus := _backup_arceus_slot(player)
	var active_slot := player.active_pokemon
	if arceus != null:
		arceus_ready = _attack_energy_gap(arceus) <= 1
	if card_name == DOUBLE_TURBO_ENERGY:
		if target_name == ARCEUS_V or target_name == ARCEUS_VSTAR:
			if target_slot == active_slot and _slot_is(target_slot, [ARCEUS_VSTAR]) and _attack_energy_gap(target_slot) > 0 and _attack_energy_gap(target_slot) <= 2:
				return 760.0
			if target_slot == backup_arceus and arceus_ready:
				return 500.0 if _attack_energy_gap(target_slot) > 0 else 120.0
			return 520.0 if _attack_energy_gap(target_slot) > 0 else 90.0
		if target_name == GIRATINA_V or target_name == GIRATINA_VSTAR:
			return 0.0
		if pivot_fallback_live:
			return 220.0 if arceus_total == 0 else 160.0
	if card_name == JET_ENERGY:
		if target_name == ARCEUS_V or target_name == ARCEUS_VSTAR:
			return 360.0 if phase == "launch" else 180.0
		if target_name == GIRATINA_V or target_name == GIRATINA_VSTAR:
			return 320.0 if phase != "launch" or arceus_ready else 150.0
	if card.card_data.is_energy():
		if target_name == ARCEUS_V or target_name == ARCEUS_VSTAR:
			if phase == "launch":
				return 420.0 if _attack_energy_gap(target_slot) > 0 else 120.0
			if target_slot == backup_arceus and _needs_backup_arceus_energy(player):
				return 250.0
			return 160.0 if _attack_energy_gap(target_slot) > 0 else 90.0
		if target_name == GIRATINA_V or target_name == GIRATINA_VSTAR:
			if active_giratina_fallback_live:
				return 170.0
			return 400.0 if arceus_ready or phase != "launch" else 180.0
		if target_name == IRON_LEAVES_EX:
			if _can_iron_leaves_attack_after_manual_attach(game_state, player, game_state.players.find(player), target_slot, card):
				return 560.0
			return 180.0 if _should_deploy_iron_leaves(game_state, player, game_state.players.find(player)) else 0.0
		if pivot_fallback_live:
			return 180.0 if arceus_total == 0 else 120.0
		return 0.0
	return 0.0


func _score_use_ability(source_slot: PokemonSlot, game_state: GameState, player: PlayerState, phase: String) -> float:
	if source_slot == null:
		return 0.0
	var name := _slot_name(source_slot)
	if _should_cool_off_charizard_reentry_engine(game_state, player, game_state.players.find(player) if game_state != null else -1, phase):
		if name in [BIBAREL, SKWOVET]:
			return 0.0
	if name == ARCEUS_VSTAR:
		var active_arceus := player.active_pokemon if player.active_pokemon != null and _slot_is(player.active_pokemon, [ARCEUS_VSTAR]) else null
		var active_needs_dte_now := active_arceus != null and _attack_energy_gap(active_arceus) > 0 and _attack_energy_gap(active_arceus) <= 2 and _count_named_in_hand(player, DOUBLE_TURBO_ENERGY) == 0
		var need_giratina := _count_named_on_field(player, GIRATINA_V) + _count_named_on_field(player, GIRATINA_VSTAR) == 0
		var need_dte := _count_named_in_hand(player, DOUBLE_TURBO_ENERGY) == 0
		var needs_transition := _needs_transition_piece(player)
		var thin_shell := _shell_is_thin(player)
		var severe_shell_gap := _needs_shell_rebuild(player)
		if active_needs_dte_now:
			return 760.0
		if severe_shell_gap:
			return 980.0
		if need_giratina or need_dte:
			return 680.0
		if thin_shell and needs_transition:
			return 620.0
		if needs_transition:
			return 540.0
		return 420.0 if phase == "launch" else 220.0
	if name == BIBAREL:
		if _should_cool_off_draw_churn(player) or _should_cool_off_conversion_churn(player):
			return 0.0
		var bonus := 0.0
		if _count_named_on_field(player, SKWOVET) > 0:
			bonus += 40.0
		return 250.0 + bonus if player.hand.size() <= 3 else 150.0 + bonus
	if name == SKWOVET:
		if _count_named_on_field(player, BIBAREL) <= 0:
			return 0.0
		if _should_cool_off_draw_churn(player) or _should_cool_off_conversion_churn(player):
			return 0.0
		return 340.0 if player.hand.size() >= 2 else 300.0
	return 0.0


func _score_attach_tool(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	var card: CardInstance = action.get("card", null)
	var target_slot: PokemonSlot = action.get("target_slot", null)
	if card == null or card.card_data == null or target_slot == null or target_slot.attached_tool != null:
		return 0.0
	var tool_name := _card_name(card)
	var target_name := _slot_name(target_slot)
	var opponent: PlayerState = game_state.players[1 - player_index] if game_state != null and player_index >= 0 and (1 - player_index) >= 0 and (1 - player_index) < game_state.players.size() else null
	var opponent_active: PokemonSlot = opponent.active_pokemon if opponent != null else null
	var opponent_mechanic := ""
	if opponent_active != null and opponent_active.get_card_data() != null:
		opponent_mechanic = str(opponent_active.get_card_data().mechanic)
	if tool_name == MAXIMUM_BELT:
		if target_name == ARCEUS_VSTAR:
			if target_slot == player.active_pokemon and _attack_energy_gap(target_slot) <= 0:
				return 540.0 if phase != "launch" else 420.0
			if _attack_energy_gap(target_slot) <= 1:
				return 320.0
			return 120.0
		if target_name == GIRATINA_VSTAR:
			if phase == "convert" and _attack_energy_gap(target_slot) <= 0:
				return 430.0 if opponent_active != null and _is_two_prize_target(opponent_active) else 320.0
			return 140.0
		return 20.0
	if tool_name == CHOICE_BELT:
		if opponent_mechanic in ["V", "VSTAR", "VMAX"]:
			if target_name == ARCEUS_VSTAR:
				if target_slot == player.active_pokemon and _attack_energy_gap(target_slot) <= 0:
					return 460.0 if phase != "launch" else 360.0
				if _attack_energy_gap(target_slot) <= 1:
					return 280.0
			if target_name == GIRATINA_VSTAR and _attack_energy_gap(target_slot) <= 0:
				return 360.0 if phase == "convert" else 260.0
		return 20.0
	return 30.0


func _score_retreat(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	if game_state == null or player.active_pokemon == null:
		return 0.0
	var active_name := _slot_name(player.active_pokemon)
	var target_slot: PokemonSlot = action.get("bench_target", null)
	if target_slot == null:
		if active_name == ARCEUS_VSTAR and _should_convert_to_giratina_finisher(game_state, player, player_index):
			for slot: PokemonSlot in player.bench:
				if slot != null and _slot_name(slot) == GIRATINA_VSTAR and _attack_energy_gap(slot) <= 0:
					target_slot = slot
					break
	if target_slot == null:
		target_slot = _best_ready_bench(player)
	var target_quality := _retreat_target_quality(target_slot)
	if active_name == ARCEUS_VSTAR:
		if _should_convert_to_giratina_finisher(game_state, player, player_index):
			if target_slot != null and _slot_name(target_slot) == GIRATINA_VSTAR and _attack_energy_gap(target_slot) <= 0:
				return 420.0
			return -120.0
		if _attack_energy_gap(player.active_pokemon) <= 0:
			return -260.0 if _core_shell_complete(player) else -220.0
		if _attack_energy_gap(player.active_pokemon) <= 1:
			return -160.0
	if target_slot == null:
		return 0.0
	if active_name in [BIDOOF, SKWOVET, RADIANT_GARDEVOIR]:
		return 120.0 + target_quality
	if active_name == GIRATINA_V and phase == "launch" and _best_arceus_slot(player) != null:
		return 80.0 + target_quality
	return 40.0 + target_quality


func _score_attack(action: Dictionary, game_state: GameState, player_index: int, phase: String) -> float:
	var score := 500.0 + float(action.get("projected_damage", 0))
	var defender: PokemonSlot = game_state.players[1 - player_index].active_pokemon
	var player: PlayerState = game_state.players[player_index]
	var source_slot: PokemonSlot = action.get("source_slot", null)
	var source_name := _slot_name(source_slot)
	var attack_name := str(action.get("attack_name", ""))
	if defender != null and int(action.get("projected_damage", 0)) >= defender.get_remaining_hp():
		score += 280.0
	if phase == "transition" and source_name == ARCEUS_VSTAR and attack_name == "Trinity Nova":
		if _needs_transition_piece(player):
			score += 140.0
		else:
			score += 60.0
	if phase == "convert" and source_name == GIRATINA_VSTAR:
		score += 130.0
	if phase == "convert" and source_name == ARCEUS_VSTAR and _is_giratina_ready(player):
		score -= 80.0
		if defender != null and int(action.get("projected_damage", 0)) < defender.get_remaining_hp():
			score -= 220.0
	if source_name == ARCEUS_VSTAR and attack_name == "Trinity Nova" and _target_formation_complete(player):
		score -= 220.0
	if phase == "convert":
		score += 40.0
	return score


func _search_score(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	var name := _card_name(card)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		if name == ARCEUS_VSTAR:
			return 110
		if name == GIRATINA_VSTAR:
			return 100
		if name == ARCEUS_V:
			return 95
		if name == GIRATINA_V:
			return 88
		if name == BIBAREL:
			return 70
		return 20
	var player: PlayerState = game_state.players[player_index]
	var phase := _detect_phase(game_state, player)
	var active_arceus := player.active_pokemon if player.active_pokemon != null and _slot_is(player.active_pokemon, [ARCEUS_VSTAR]) else null
	var thin_shell := _shell_is_thin(player)
	var severe_shell_gap := _needs_shell_rebuild(player)
	var keep_backup_arceus_live := _should_force_backup_arceus_shell(game_state, player, player_index, phase)
	if name == ARCEUS_V and _count_named_on_field(player, ARCEUS_V) + _count_named_on_field(player, ARCEUS_VSTAR) == 0:
		return 145
	if name == ARCEUS_V and _count_arceus_total(player) == 1:
		if keep_backup_arceus_live:
			return 196
		if severe_shell_gap:
			return 172
		return 156 if _count_named_on_field(player, GIRATINA_V) + _count_named_on_field(player, GIRATINA_VSTAR) == 0 else 144
	if name == ARCEUS_VSTAR and _count_named_on_field(player, ARCEUS_V) > 0 and _count_named_on_field(player, ARCEUS_VSTAR) == 0:
		return 160
	if name == GIRATINA_V and _count_named_on_field(player, GIRATINA_V) + _count_named_on_field(player, GIRATINA_VSTAR) == 0:
		return 150 if severe_shell_gap and _count_arceus_total(player) >= 2 else (138 if _best_arceus_slot(player) != null else 124)
	if name == GIRATINA_VSTAR and _count_named_on_field(player, GIRATINA_V) > 0 and _count_named_on_field(player, GIRATINA_VSTAR) == 0:
		return 170 if _best_arceus_slot(player) != null else 118
	if name == GRASS_ENERGY or name == PSYCHIC_ENERGY:
		if phase != "launch" and _needs_transition_piece(player):
			return 150
		return 24
	if name == JET_ENERGY:
		if phase == "launch" and _best_arceus_slot(player) != null and _attack_energy_gap(_best_arceus_slot(player)) > 0:
			return 138
		if phase != "launch" and _needs_transition_piece(player):
			return 146
		return 30
	if name == DOUBLE_TURBO_ENERGY:
		if active_arceus != null and _attack_energy_gap(active_arceus) > 0 and _attack_energy_gap(active_arceus) <= 2:
			return 220
		if _count_named_on_field(player, ARCEUS_V) > 0:
			return 132
		return 36
	if name == BIDOOF and _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) == 0:
		if keep_backup_arceus_live:
			return 84
		if severe_shell_gap and _count_arceus_total(player) >= 2 and _count_giratina_total(player) >= 1:
			return 166
		if thin_shell and _count_arceus_total(player) >= 2 and _count_giratina_total(player) >= 1:
			return 154
		if phase != "launch" and _needs_transition_piece(player):
			return 96
		return 120
	if name == BIBAREL and _count_named_on_field(player, BIDOOF) > 0 and _count_named_on_field(player, BIBAREL) == 0:
		if keep_backup_arceus_live:
			return 96
		return 156 if thin_shell and _count_arceus_total(player) >= 2 and _count_giratina_total(player) >= 1 else 128
	if name == SKWOVET and _count_named_on_field(player, SKWOVET) == 0:
		if keep_backup_arceus_live:
			return 76
		if severe_shell_gap and _count_bibarel_line_total(player) > 0 and _count_arceus_total(player) >= 2 and _count_giratina_total(player) >= 1:
			return 158
		if thin_shell and _count_arceus_total(player) >= 2 and _count_giratina_total(player) >= 1:
			return 148 if _count_bibarel_line_total(player) > 0 else 132
		return 116 if _count_named_on_field(player, BIBAREL) > 0 or _count_named_on_field(player, BIDOOF) > 0 else 90
	if name == RADIANT_GARDEVOIR:
		return 112 if _should_deploy_radiant_gardevoir(game_state, player, player_index) else -40
	if name == IRON_LEAVES_EX:
		return 118 if _should_deploy_iron_leaves(game_state, player, player_index) else -50
	return 20


func _assignment_target_score(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null:
		return 0.0
	var source_card: CardInstance = context.get("source_card", null)
	var source_name := _card_name(source_card)
	var slot_name := _slot_name(slot)
	var player := _context_player(context)
	var launch_online := player != null and _is_launch_online(player)
	var backup_arceus := _backup_arceus_slot(player)
	var giratina := _best_giratina_slot(player)
	if source_name == DOUBLE_TURBO_ENERGY:
		if slot_name == ARCEUS_VSTAR or slot_name == ARCEUS_V:
			if slot == backup_arceus and launch_online:
				return 470.0
			return 440.0
		if slot_name == GIRATINA_V or slot_name == GIRATINA_VSTAR:
			return 0.0
	if source_name == GRASS_ENERGY or source_name == PSYCHIC_ENERGY or source_name == JET_ENERGY:
		if launch_online and slot == backup_arceus:
			var backup_score := 260.0
			if _backup_arceus_needs_first_basic_progress_after_pending(slot, context):
				backup_score += 160.0
			elif _needs_backup_arceus_energy(player):
				backup_score += 70.0
			if source_name == GRASS_ENERGY:
				backup_score += 10.0
			return backup_score
		if slot == player.active_pokemon and slot_name in [ARCEUS_V, ARCEUS_VSTAR] and launch_online and _attack_energy_gap(slot) <= 0:
			if _needs_backup_arceus_energy(player) or _needs_transition_piece(player):
				return 40.0
		if launch_online and (slot_name == GIRATINA_VSTAR or slot_name == GIRATINA_V):
			var giratina_score := 300.0
			if source_name == PSYCHIC_ENERGY and _giratina_needs_type_after_pending(slot, "P", context):
				giratina_score += 180.0
			elif source_name == GRASS_ENERGY and _giratina_needs_type_after_pending(slot, "G", context):
				giratina_score += 120.0
			elif giratina != null and slot == giratina and _attack_gap_after_pending(slot, context) <= 1:
				giratina_score += 60.0
			return giratina_score
		if slot_name == ARCEUS_VSTAR or slot_name == ARCEUS_V:
			return 260.0
		if slot_name == GIRATINA_VSTAR or slot_name == GIRATINA_V:
			return 210.0
		if slot_name == IRON_LEAVES_EX:
			var game_state: GameState = context.get("game_state", null)
			var player_index: int = int(context.get("player_index", -1))
			return 180.0 if _should_deploy_iron_leaves(game_state, player, player_index) else 0.0
		return 0.0
	if slot_name == GIRATINA_VSTAR or slot_name == GIRATINA_V:
		return 360.0
	if slot_name == ARCEUS_VSTAR or slot_name == ARCEUS_V:
		return 300.0
	return 0.0


func _pick_energy_assignment_sources(items: Array[CardInstance], max_select: int, context: Dictionary) -> Array:
	if items.is_empty() or max_select <= 0:
		return []
	var selected: Array = []
	var remaining: Array[CardInstance] = items.duplicate()
	var player := _context_player(context)
	var giratina := _best_giratina_slot(player)
	var backup_arceus := _backup_arceus_slot(player)
	if player != null and _is_launch_online(player):
		if giratina != null and _giratina_needs_type_after_pending(giratina, "P", context):
			_append_first_matching_energy_source(selected, remaining, max_select, ["P"])
		if giratina != null and _giratina_needs_type_after_pending(giratina, "G", context):
			_append_first_matching_energy_source(selected, remaining, max_select, ["G"])
		if backup_arceus != null and _backup_arceus_needs_first_basic_progress_after_pending(backup_arceus, context):
			_append_first_matching_energy_source(selected, remaining, max_select, ["G", "P"])
	while selected.size() < max_select and not remaining.is_empty():
		var best_card: CardInstance = null
		var best_score := -INF
		for card: CardInstance in remaining:
			var score := _score_energy_assignment_source(card, context)
			if score > best_score:
				best_score = score
				best_card = card
		if best_card == null:
			break
		selected.append(best_card)
		remaining.erase(best_card)
	return selected


func _append_first_matching_energy_source(selected: Array, remaining: Array[CardInstance], max_select: int, energy_types: Array[String]) -> void:
	if selected.size() >= max_select:
		return
	for card: CardInstance in remaining:
		if card == null or card.card_data == null:
			continue
		if energy_types.has(str(card.card_data.energy_provides)):
			selected.append(card)
			remaining.erase(card)
			return


func _score_energy_assignment_source(card: CardInstance, context: Dictionary) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var player := _context_player(context)
	var giratina := _best_giratina_slot(player)
	var provided := str(card.card_data.energy_provides)
	var score := 40.0
	if player != null and _is_launch_online(player) and giratina != null:
		if provided == "P" and _giratina_needs_type_after_pending(giratina, "P", context):
			score += 220.0
		elif provided == "G" and _giratina_needs_type_after_pending(giratina, "G", context):
			score += 180.0
		else:
			score += 80.0
	return score


func _detect_phase(game_state: GameState, player: PlayerState) -> String:
	if player == null:
		return "launch"
	if _target_formation_complete(player):
		return "convert"
	if _is_launch_online(player):
		var giratina := _best_giratina_slot(player)
		if giratina != null and _attack_energy_gap(giratina) <= 1:
			return "convert"
		return "transition"
	if _has_post_launch_reentry_lane(player):
		var reentry_giratina := _best_giratina_slot(player)
		if reentry_giratina != null and _attack_energy_gap(reentry_giratina) <= 0:
			return "convert"
		return "transition"
	return "launch"


func _is_launch_online(player: PlayerState) -> bool:
	var arceus := _best_arceus_slot(player)
	if arceus == null:
		return false
	return _slot_name(arceus) == ARCEUS_VSTAR and _attack_energy_gap(arceus) <= 0


func _needs_transition_piece(player: PlayerState) -> bool:
	var giratina := _best_giratina_slot(player)
	if giratina == null:
		return true
	if _slot_name(giratina) == GIRATINA_V and _count_named_in_hand(player, GIRATINA_VSTAR) == 0:
		return true
	return _attack_energy_gap(giratina) > 1


func _is_giratina_ready(player: PlayerState) -> bool:
	var giratina := _best_giratina_slot(player)
	if giratina == null:
		return false
	return _slot_name(giratina) == GIRATINA_VSTAR and _attack_energy_gap(giratina) <= 0


func _has_post_launch_reentry_lane(player: PlayerState) -> bool:
	if player == null:
		return false
	if _count_arceus_total(player) <= 0:
		return false
	var giratina := _best_giratina_slot(player)
	if giratina == null or _slot_name(giratina) != GIRATINA_VSTAR:
		return false
	return _attack_energy_gap(giratina) <= 1


func _context_player(context: Dictionary) -> PlayerState:
	var game_state: GameState = context.get("game_state", null)
	var player_index: int = int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	return game_state.players[player_index]


func _pending_assignment_count(slot: PokemonSlot, context: Dictionary) -> int:
	if slot == null or context.is_empty():
		return 0
	var pending_assignment_counts: Variant = context.get("pending_assignment_counts", {})
	if not (pending_assignment_counts is Dictionary):
		return 0
	return int((pending_assignment_counts as Dictionary).get(int(slot.get_instance_id()), 0))


func _pending_energy_type_count(slot: PokemonSlot, energy_type: String, context: Dictionary) -> int:
	if slot == null or context.is_empty():
		return 0
	var pending_assignments: Variant = context.get("pending_assignments", [])
	if not (pending_assignments is Array):
		return 0
	var total := 0
	for entry: Variant in pending_assignments:
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		if assignment.get("target", null) != slot:
			continue
		var source_card: Variant = assignment.get("source", null)
		if not (source_card is CardInstance) or (source_card as CardInstance).card_data == null:
			continue
		if str((source_card as CardInstance).card_data.energy_provides) == energy_type:
			total += 1
	return total


func _attached_energy_type_count(slot: PokemonSlot, energy_type: String) -> int:
	if slot == null:
		return 0
	var total := 0
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		if str(energy.card_data.energy_provides) == energy_type:
			total += 1
	return total


func _giratina_needs_type_after_pending(slot: PokemonSlot, energy_type: String, context: Dictionary) -> bool:
	if slot == null or not _slot_is(slot, [GIRATINA_V, GIRATINA_VSTAR]):
		return false
	return _attached_energy_type_count(slot, energy_type) + _pending_energy_type_count(slot, energy_type, context) <= 0


func _backup_arceus_needs_first_basic_progress_after_pending(slot: PokemonSlot, context: Dictionary) -> bool:
	if slot == null or not _slot_is(slot, [ARCEUS_V, ARCEUS_VSTAR]):
		return false
	return _effective_energy_count(slot) + _pending_assignment_count(slot, context) <= 0


func _attack_gap_after_pending(slot: PokemonSlot, context: Dictionary, additional_energy: int = 0) -> int:
	return maxi(0, _attack_energy_gap(slot) - _pending_assignment_count(slot, context) - additional_energy)


func _best_arceus_slot(player: PlayerState) -> PokemonSlot:
	var best_slot: PokemonSlot = null
	var best_score := -INF
	for slot: PokemonSlot in _all_slots(player):
		var slot_name := _slot_name(slot)
		if slot_name != ARCEUS_V and slot_name != ARCEUS_VSTAR:
			continue
		var score := float(slot.attached_energy.size()) * 55.0
		if slot_name == ARCEUS_VSTAR:
			score += 220.0
		if slot == player.active_pokemon:
			score += 40.0
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot


func _backup_arceus_slot(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	var best_slot: PokemonSlot = null
	var best_score := -INF
	for slot: PokemonSlot in player.bench:
		var slot_name := _slot_name(slot)
		if slot_name != ARCEUS_V and slot_name != ARCEUS_VSTAR:
			continue
		var score := float(_effective_energy_count(slot)) * 50.0
		if slot_name == ARCEUS_VSTAR:
			score += 180.0
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot


func _best_giratina_slot(player: PlayerState) -> PokemonSlot:
	var best_slot: PokemonSlot = null
	var best_score := -INF
	for slot: PokemonSlot in _all_slots(player):
		var slot_name := _slot_name(slot)
		if slot_name != GIRATINA_V and slot_name != GIRATINA_VSTAR:
			continue
		var score := float(slot.attached_energy.size()) * 50.0
		if slot_name == GIRATINA_VSTAR:
			score += 180.0
		if slot == player.active_pokemon:
			score += 30.0
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot


func _best_ready_bench(player: PlayerState) -> PokemonSlot:
	for slot: PokemonSlot in player.bench:
		if slot != null and _attack_energy_gap(slot) <= 0 and _best_attack_damage(slot) > 0:
			return slot
	return null


func _retreat_target_quality(slot: PokemonSlot) -> float:
	if slot == null:
		return -220.0
	var name := _slot_name(slot)
	if name in [BIDOOF, SKWOVET, RADIANT_GARDEVOIR]:
		return -220.0
	var score := float(_best_attack_damage(slot)) * 0.6
	var gap := _attack_energy_gap(slot)
	if gap <= 0:
		score += 200.0
	elif gap == 1:
		score += 60.0
	if name == GIRATINA_VSTAR:
		score += 120.0
	elif name == ARCEUS_VSTAR:
		score += 100.0
	elif name == GIRATINA_V:
		score += 40.0
	elif name == ARCEUS_V:
		score += 20.0
	return score


func _send_out_target_score(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null:
		return 0.0
	var player := _context_player(context)
	var score := 100.0 + float(_best_attack_damage(slot))
	var name := _slot_name(slot)
	if name == ARCEUS_VSTAR:
		score += 220.0
		if player != null and slot == _backup_arceus_slot(player):
			score += 120.0
	elif name == ARCEUS_V:
		score += 120.0
	elif name == GIRATINA_VSTAR:
		score += 180.0
	elif name == GIRATINA_V:
		score += 80.0
	elif name in [BIDOOF, SKWOVET, RADIANT_GARDEVOIR]:
		score -= 260.0
	if player != null:
		if _slot_name(slot) == ARCEUS_VSTAR and _attack_energy_gap(slot) <= 0:
			score += 160.0
		if _slot_name(slot) == GIRATINA_VSTAR and _attack_energy_gap(slot) <= 0:
			score += 90.0
		if _is_launch_online(player):
			if name == ARCEUS_VSTAR:
				score += 160.0
			elif name in [BIDOOF, SKWOVET, RADIANT_GARDEVOIR]:
				score -= 120.0
	return score


func _score_handoff_target(slot: PokemonSlot, step_id: String, context: Dictionary) -> float:
	if slot == null:
		return 0.0
	var player := _context_player(context)
	if player == null:
		return _send_out_target_score(slot, context)
	var game_state: GameState = context.get("game_state", null)
	var phase := _detect_phase(game_state, player)
	var name := _slot_name(slot)
	var is_ready := _attack_energy_gap(slot) <= 0 and _best_attack_damage(slot) > 0
	var is_near_ready := _attack_energy_gap(slot) == 1 and _best_attack_damage(slot) > 0
	var score := float(_best_attack_damage(slot)) * 0.8
	if name in [BIDOOF, SKWOVET, RADIANT_GARDEVOIR]:
		score -= 360.0
	if step_id in ["self_switch_target", "switch_target", "pivot_target", "heavy_baton_target"]:
		score += 25.0
	if phase == "launch":
		if name == ARCEUS_VSTAR:
			score += 620.0 if is_ready else (500.0 if is_near_ready else 300.0)
		elif name == ARCEUS_V:
			score += 420.0 if is_near_ready else 240.0
		elif name == GIRATINA_VSTAR:
			score += 240.0 if is_ready else (170.0 if is_near_ready else 80.0)
		elif name == GIRATINA_V:
			score += 190.0 if is_near_ready else 100.0
		return score
	if name == GIRATINA_VSTAR:
		score += 760.0 if is_ready else (560.0 if is_near_ready else 260.0)
	elif name == GIRATINA_V:
		score += 420.0 if is_near_ready else (240.0 if is_ready else 130.0)
	elif name == ARCEUS_VSTAR:
		score += 620.0 if is_ready else (340.0 if is_near_ready else 180.0)
	elif name == ARCEUS_V:
		score += 220.0 if is_near_ready else 90.0
	if _is_giratina_ready(player):
		if name == GIRATINA_VSTAR:
			score += 180.0
		elif name == ARCEUS_VSTAR:
			score -= 140.0
		elif name == ARCEUS_V:
			score -= 80.0
	if _has_post_launch_reentry_lane(player):
		if name == GIRATINA_VSTAR and _attack_energy_gap(slot) <= 1:
			score += 120.0
		elif name == ARCEUS_VSTAR and _attack_energy_gap(slot) <= 0:
			score -= 60.0
	return score


func _attack_energy_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null or slot.get_card_data().attacks.is_empty():
		return 99
	var min_gap := 99
	var attached_count := _effective_energy_count(slot)
	for attack: Dictionary in slot.get_card_data().attacks:
		var cost: String = str(attack.get("cost", ""))
		min_gap = mini(min_gap, maxi(0, cost.length() - attached_count))
	return min_gap


func _effective_energy_count(slot: PokemonSlot) -> int:
	if slot == null:
		return 0
	var total := 0
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		if _card_name(energy) == DOUBLE_TURBO_ENERGY:
			total += 2
		else:
			total += 1
	return total


func _best_attack_damage(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 0
	var best := 0
	for attack: Dictionary in slot.get_card_data().attacks:
		best = maxi(best, _parse_damage(str(attack.get("damage", "0"))))
	return best


func _all_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player == null:
		return slots
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


func _count_named_on_field(player: PlayerState, target_name: String) -> int:
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _slot_is(slot, [target_name]):
			count += 1
	return count


func _count_named_in_hand(player: PlayerState, target_name: String) -> int:
	var count := 0
	for card: CardInstance in player.hand:
		if _card_name(card) == target_name:
			count += 1
	return count


func _count_arceus_total(player: PlayerState) -> int:
	return _count_named_on_field(player, ARCEUS_V) + _count_named_on_field(player, ARCEUS_VSTAR)


func _count_giratina_total(player: PlayerState) -> int:
	return _count_named_on_field(player, GIRATINA_V) + _count_named_on_field(player, GIRATINA_VSTAR)


func _count_bibarel_line_total(player: PlayerState) -> int:
	return _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL)


func _can_bench_hand_arceus(player: PlayerState) -> bool:
	return player != null and not player.is_bench_full() and _count_named_in_hand(player, ARCEUS_V) > 0


func _core_shell_complete(player: PlayerState) -> bool:
	if player == null:
		return false
	return (
		_count_arceus_total(player) >= 2
		and _count_giratina_total(player) >= 1
		and _count_bibarel_line_total(player) >= 1
		and _count_named_on_field(player, SKWOVET) >= 1
	)


func _target_formation_complete(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if _slot_name(player.active_pokemon) != ARCEUS_VSTAR or _attack_energy_gap(player.active_pokemon) > 0:
		return false
	var backup_arceus := _backup_arceus_slot(player)
	var giratina := _best_giratina_slot(player)
	return (
		backup_arceus != null
		and _slot_name(backup_arceus) == ARCEUS_VSTAR
		and _attack_energy_gap(backup_arceus) <= 0
		and giratina != null
		and _slot_name(giratina) == GIRATINA_VSTAR
		and _attack_energy_gap(giratina) <= 0
		and _count_named_on_field(player, BIBAREL) >= 1
		and _count_named_on_field(player, SKWOVET) >= 1
	)


func _shell_is_thin(player: PlayerState) -> bool:
	if player == null:
		return false
	if _count_arceus_total(player) <= 1:
		return true
	if _count_giratina_total(player) == 0:
		return true
	if _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) == 0:
		return true
	if _count_named_on_field(player, SKWOVET) == 0:
		return true
	return false


func _needs_shell_rebuild(player: PlayerState) -> bool:
	if player == null:
		return false
	if _count_arceus_total(player) != 1:
		return false
	if _count_giratina_total(player) == 0:
		return true
	if _count_named_on_field(player, BIDOOF) + _count_named_on_field(player, BIBAREL) == 0:
		return true
	if _count_named_on_field(player, SKWOVET) == 0:
		return true
	return false


func _needs_backup_arceus_energy(player: PlayerState) -> bool:
	var backup_arceus := _backup_arceus_slot(player)
	return backup_arceus != null and _attack_energy_gap(backup_arceus) > 0


func _has_ready_attacker(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if slot == null:
			continue
		if _best_attack_damage(slot) <= 0:
			continue
		if _attack_energy_gap(slot) <= 0:
			return true
	return false


func _has_deck_out_pressure(player: PlayerState) -> bool:
	return player != null and player.deck.size() <= 8


func _active_can_attack(player: PlayerState) -> bool:
	return player != null and player.active_pokemon != null and _best_attack_damage(player.active_pokemon) > 0 and _attack_energy_gap(player.active_pokemon) <= 0


func _should_cool_off_draw_churn(player: PlayerState) -> bool:
	return _has_deck_out_pressure(player) and _has_ready_attacker(player)


func _should_cool_off_conversion_churn(player: PlayerState) -> bool:
	return (
		player != null
		and _active_can_attack(player)
		and _core_shell_complete(player)
		and not _needs_transition_piece(player)
	)


func _should_cool_off_post_launch_shell_padding(player: PlayerState, phase: String) -> bool:
	if player == null or phase == "launch":
		return false
	if _count_arceus_total(player) <= 0 or _count_giratina_total(player) <= 0:
		return false
	if _needs_shell_rebuild(player):
		return false
	return _is_launch_online(player) or _has_post_launch_reentry_lane(player)


func _should_force_backup_arceus_shell(game_state: GameState, player: PlayerState, player_index: int, phase: String) -> bool:
	if game_state == null or player == null or phase == "launch":
		return false
	if not _is_charizard_pressure_matchup(game_state, player_index):
		return false
	if not _is_launch_online(player):
		return false
	if _count_arceus_total(player) >= 2:
		return false
	return _count_giratina_total(player) >= 1


func _should_cool_off_charizard_reentry_engine(game_state: GameState, player: PlayerState, player_index: int, phase: String) -> bool:
	if game_state == null or player == null or phase == "launch":
		return false
	if not _is_charizard_pressure_matchup(game_state, player_index):
		return false
	if not _is_launch_online(player):
		return false
	if _active_can_attack(player):
		return false
	if _count_arceus_total(player) < 2:
		return true
	var backup_arceus := _backup_arceus_slot(player)
	if backup_arceus == null:
		return false
	if _slot_is(backup_arceus, [ARCEUS_V]):
		return true
	return _slot_is(backup_arceus, [ARCEUS_VSTAR]) and _attack_energy_gap(backup_arceus) > 0


func _is_charizard_pressure_matchup(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null:
		return false
	for slot: PokemonSlot in _all_slots(opponent):
		var name := _slot_name(slot)
		if name in [CHARMANDER, CHARMELEON, CHARIZARD_EX, PIDGEY, PIDGEOT_EX]:
			return true
	return false


func _active_should_hand_off_to_ready_bench(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if _active_can_attack(player):
		return false
	var ready_bench := _best_ready_bench(player)
	if ready_bench == null:
		return false
	return _retreat_target_quality(ready_bench) >= 250.0


func _should_enable_pivot_fallback_attach(player: PlayerState, target_slot: PokemonSlot, phase: String) -> bool:
	if player == null or target_slot == null or phase != "launch":
		return false
	if target_slot != player.active_pokemon:
		return false
	if not _slot_is(target_slot, [BIDOOF, SKWOVET, RADIANT_GARDEVOIR]):
		return false
	if target_slot.get_card_data() == null:
		return false
	var retreat_cost := int(target_slot.get_card_data().retreat_cost)
	if retreat_cost <= 0:
		return false
	if target_slot.attached_energy.size() >= retreat_cost:
		return false
	return _count_arceus_total(player) <= 1 and not _target_formation_complete(player)


func _should_enable_active_giratina_fallback_attach(player: PlayerState, target_slot: PokemonSlot, phase: String) -> bool:
	if player == null or target_slot == null or phase != "launch":
		return false
	if target_slot != player.active_pokemon:
		return false
	if not _slot_is(target_slot, [GIRATINA_V, GIRATINA_VSTAR]):
		return false
	return _count_arceus_total(player) == 0 and _attack_energy_gap(target_slot) > 0


func _should_hold_non_arceus_attach_for_hand_arceus(player: PlayerState, target_slot: PokemonSlot, phase: String) -> bool:
	if player == null or target_slot == null or phase != "launch":
		return false
	if _count_arceus_total(player) > 0:
		return false
	if player.is_bench_full():
		return false
	if _count_named_in_hand(player, ARCEUS_V) <= 0:
		return false
	return not _slot_is(target_slot, [ARCEUS_V, ARCEUS_VSTAR])


func _should_deploy_iron_leaves(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null or opponent.active_pokemon == null or opponent.active_pokemon.get_card_data() == null:
		return false
	if _slot_name(opponent.active_pokemon) != "Charizard ex":
		return false
	return _can_iron_leaves_take_charizard_ko_this_turn(game_state, player, player_index)


func _can_iron_leaves_take_charizard_ko_this_turn(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null or opponent.active_pokemon == null or _slot_name(opponent.active_pokemon) != CHARIZARD_EX:
		return false
	var movable_energy := _count_movable_iron_leaves_energy(player)
	var movable_has_grass := _has_movable_iron_leaves_grass(player)
	if movable_energy >= 3 and movable_has_grass:
		return true
	if game_state.energy_attached_this_turn:
		return false
	var best_attach := _best_hand_attach_profile_for_iron_leaves(player)
	return movable_energy + int(best_attach.get("energy", 0)) >= 3 and (movable_has_grass or bool(best_attach.get("has_grass", false)))


func _can_iron_leaves_attack_after_manual_attach(
	game_state: GameState,
	player: PlayerState,
	player_index: int,
	target_slot: PokemonSlot,
	card: CardInstance
) -> bool:
	if game_state == null or player == null or target_slot == null or card == null or card.card_data == null:
		return false
	if player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null or opponent.active_pokemon == null or _slot_name(opponent.active_pokemon) != CHARIZARD_EX:
		return false
	var attach_energy := 2 if _card_name(card) == DOUBLE_TURBO_ENERGY else 1
	var has_grass := _attached_energy_type_count(target_slot, "G") > 0 or _card_name(card) == GRASS_ENERGY
	return _effective_energy_count(target_slot) + attach_energy >= 3 and has_grass


func _count_movable_iron_leaves_energy(player: PlayerState) -> int:
	if player == null:
		return 0
	var total := 0
	for slot: PokemonSlot in _all_slots(player):
		if slot != null:
			total += _effective_energy_count(slot)
	return total


func _has_movable_iron_leaves_grass(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if _attached_energy_type_count(slot, "G") > 0:
			return true
	return false


func _best_hand_attach_profile_for_iron_leaves(player: PlayerState) -> Dictionary:
	var best_energy := 0
	var has_grass := false
	if player == null:
		return {"energy": 0, "has_grass": false}
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null or not card.card_data.is_energy():
			continue
		var card_name := _card_name(card)
		var energy := 2 if card_name == DOUBLE_TURBO_ENERGY else 1
		best_energy = maxi(best_energy, energy)
		if card_name == GRASS_ENERGY:
			has_grass = true
	return {"energy": best_energy, "has_grass": has_grass}


func _should_deploy_radiant_gardevoir(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	if _count_named_on_field(player, RADIANT_GARDEVOIR) > 0:
		return false
	if not _core_shell_complete(player):
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null or opponent.active_pokemon == null or opponent.active_pokemon.get_card_data() == null:
		return false
	var mechanic := str(opponent.active_pokemon.get_card_data().mechanic)
	return mechanic in ["V", "VSTAR", "VMAX"]


func _count_field_energy_of_types(player: PlayerState, types: Array[String]) -> int:
	if player == null:
		return 0
	var total := 0
	for slot: PokemonSlot in _all_slots(player):
		if slot == null:
			continue
		for energy: CardInstance in slot.attached_energy:
			if energy == null or energy.card_data == null:
				continue
			var provided := str(energy.card_data.energy_provides)
			if types.has(provided):
				total += 1
	return total


func _player_is_behind_in_prizes(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	return game_state.players[player_index].prizes.size() > game_state.players[1 - player_index].prizes.size()


func _player_is_ahead_in_prizes(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	return game_state.players[player_index].prizes.size() < game_state.players[1 - player_index].prizes.size()


func _is_two_prize_target(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	var mechanic := str(slot.get_card_data().mechanic)
	return mechanic in ["V", "VMAX", "VSTAR", "ex", "EX", "GX"]


func _should_convert_to_giratina_finisher(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null or player.active_pokemon == null:
		return false
	if player_index < 0 or player_index >= game_state.players.size():
		return false
	if _slot_name(player.active_pokemon) != ARCEUS_VSTAR:
		return false
	var giratina := _best_giratina_slot(player)
	if giratina == null or giratina == player.active_pokemon:
		return false
	if _slot_name(giratina) != GIRATINA_VSTAR or _attack_energy_gap(giratina) > 0:
		return false
	var opponent_active := game_state.players[1 - player_index].active_pokemon
	if opponent_active == null:
		return false
	var giratina_damage := _best_attack_damage(giratina)
	if giratina_damage < opponent_active.get_remaining_hp():
		return false
	var arceus_damage := _best_attack_damage(player.active_pokemon)
	if arceus_damage < opponent_active.get_remaining_hp():
		return true
	return phase_is_convert(player, game_state) and _is_two_prize_target(opponent_active)


func phase_is_convert(player: PlayerState, game_state: GameState) -> bool:
	return _detect_phase(game_state, player) == "convert"


func _card_name(card: Variant) -> String:
	if not (card is CardInstance):
		return ""
	var inst := card as CardInstance
	if inst.card_data == null:
		return ""
	if str(inst.card_data.name_en) != "":
		return str(inst.card_data.name_en)
	return str(inst.card_data.name)


func _parse_damage(text: String) -> int:
	var digits := ""
	for i: int in text.length():
		var ch := text[i]
		if ch >= "0" and ch <= "9":
			digits += ch
	return int(digits) if digits != "" else 0
