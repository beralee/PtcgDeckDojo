class_name AIActionFeatureEncoder
extends RefCounted

const NEST_BALL_EFFECT_ID: String = "1af63a7e2cb7a79215474ad8db8fd8fd"
const FEATURE_SCHEMA: Array[String] = [
	"kind_play_trainer",
	"kind_play_stadium",
	"kind_use_ability",
	"kind_attach_tool",
	"kind_attach_energy",
	"kind_play_basic_to_bench",
	"kind_evolve",
	"kind_retreat",
	"kind_attack",
	"kind_granted_attack",
	"kind_end_turn",
	"is_active_target",
	"is_bench_target",
	"requires_interaction",
	"improves_bench_development",
	"bench_development_delta",
	"improves_attack_readiness",
	"improves_bench_attack_readiness",
	"productive",
	"search_productive",
	"creates_churn_risk",
	"deck_out_pressure",
	"remaining_basic_targets",
	"projected_damage",
	"projected_knockout",
	"consumes_hand_card",
	"targets_core_engine_piece",
	"targets_core_attacker",
	"ability_is_engine",
	"trainer_is_engine_search",
	"evolve_is_stage2_engine",
	"discard_fuel_available",
	"bench_slots_remaining",
	"stage2_engine_online",
]


func get_schema() -> Array[String]:
	return FEATURE_SCHEMA.duplicate()


func build_features(gsm: GameStateMachine, player_index: int, action: Dictionary) -> Dictionary:
	var features := {
		"is_active_target": false,
		"is_bench_target": false,
		"requires_interaction": bool(action.get("requires_interaction", false)),
		"improves_bench_development": false,
		"bench_development_delta": 0.0,
		"improves_attack_readiness": false,
		"improves_bench_attack_readiness": false,
		"productive": true,
		"search_productive": false,
		"creates_churn_risk": false,
		"deck_out_pressure": false,
		"remaining_basic_targets": 0.0,
		"projected_damage": 0.0,
		"projected_knockout": false,
		"consumes_hand_card": _action_consumes_hand_card(action),
		"targets_core_engine_piece": false,
		"targets_core_attacker": false,
		"ability_is_engine": false,
		"trainer_is_engine_search": false,
		"evolve_is_stage2_engine": false,
		"discard_fuel_available": false,
		"bench_slots_remaining": 0.0,
		"stage2_engine_online": false,
	}

	if gsm == null or gsm.game_state == null:
		return features
	if player_index < 0 or player_index >= gsm.game_state.players.size():
		return features

	var player: PlayerState = gsm.game_state.players[player_index]
	features["bench_slots_remaining"] = float(maxi(0, 5 - player.bench.size()))
	features["discard_fuel_available"] = _has_discard_energy_fuel(player)
	features["stage2_engine_online"] = _has_stage2_engine_online(player)
	match str(action.get("kind", "")):
		"play_basic_to_bench":
			features["improves_bench_development"] = true
			features["bench_development_delta"] = 1.0
			features["productive"] = _has_open_bench_slot(player)
			var bench_card: CardInstance = action.get("card")
			features["targets_core_engine_piece"] = _card_matches_any(bench_card, ["Ralts", "Kirlia", "Gardevoir ex", "拉鲁拉丝", "奇鲁莉安", "沙奈朵ex"])
			features["targets_core_attacker"] = _card_matches_any(bench_card, ["Drifloon", "Flutter Mane", "Scream Tail", "飘飘球", "振翼发", "吼叫尾"])
		"evolve":
			features["improves_bench_development"] = true
			features["productive"] = action.get("target_slot") is PokemonSlot
			var evolve_card: CardInstance = action.get("card")
			features["targets_core_engine_piece"] = _card_matches_any(evolve_card, ["Kirlia", "Gardevoir ex", "奇鲁莉安", "沙奈朵ex"])
			features["evolve_is_stage2_engine"] = _card_matches_any(evolve_card, ["Gardevoir ex", "沙奈朵ex"])
		"attach_energy":
			var target_slot: PokemonSlot = action.get("target_slot")
			var active_slot: PokemonSlot = player.active_pokemon
			var is_active_target: bool = target_slot != null and target_slot == active_slot
			features["is_active_target"] = is_active_target
			features["is_bench_target"] = target_slot != null and not is_active_target
			features["improves_bench_development"] = bool(features["is_bench_target"])
			features["targets_core_attacker"] = _slot_matches_any(target_slot, ["Drifloon", "Scream Tail", "Gardevoir ex", "飘飘球", "吼叫尾", "沙奈朵ex"])
			features["targets_core_engine_piece"] = _slot_matches_any(target_slot, ["Kirlia", "Gardevoir ex", "奇鲁莉安", "沙奈朵ex"])
			if is_active_target:
				features["improves_attack_readiness"] = _attach_enables_attack(gsm, active_slot, action)
			elif target_slot != null:
				features["improves_bench_attack_readiness"] = _attach_enables_attack(gsm, target_slot, action)
		"attach_tool":
			var tool_target_slot: PokemonSlot = action.get("target_slot")
			var active_tool_slot: PokemonSlot = player.active_pokemon
			var is_active_tool_target: bool = tool_target_slot != null and tool_target_slot == active_tool_slot
			features["is_active_target"] = is_active_tool_target
			features["is_bench_target"] = tool_target_slot != null and not is_active_tool_target
		"play_trainer":
			var trainer_card: CardInstance = action.get("card")
			features["deck_out_pressure"] = _has_deck_out_pressure(player, gsm)
			features["trainer_is_engine_search"] = _card_matches_any(trainer_card, ["Nest Ball", "Buddy-Buddy Poffin", "Ultra Ball", "Rare Candy", "Arven", "精灵球", "搭档宝芬", "高级球", "神奇糖果", "派帕"])
			if _is_nest_ball(trainer_card):
				var remaining_basic_targets: int = _count_basic_targets(player.deck)
				features["remaining_basic_targets"] = float(remaining_basic_targets)
				features["productive"] = remaining_basic_targets > 0
				features["search_productive"] = remaining_basic_targets > 0
			elif _is_churn_trainer(trainer_card) and bool(features.get("deck_out_pressure", false)) and _board_has_ready_attacker(player, gsm):
				features["creates_churn_risk"] = true
		"play_stadium":
			features["productive"] = true
			features["deck_out_pressure"] = _has_deck_out_pressure(player, gsm)
		"use_ability":
			var source_slot: PokemonSlot = action.get("source_slot")
			features["ability_is_engine"] = _slot_matches_any(source_slot, ["Gardevoir ex", "Kirlia", "Radiant Greninja", "沙奈朵ex", "奇鲁莉安", "光辉甲贺忍蛙"])
			features["targets_core_engine_piece"] = _slot_matches_any(source_slot, ["Gardevoir ex", "Kirlia", "沙奈朵ex", "奇鲁莉安"])
		"retreat":
			var bench_target: PokemonSlot = action.get("bench_target")
			features["is_bench_target"] = bench_target != null
			features["productive"] = bench_target != null and _slot_can_attack_now(gsm, bench_target)
			features["targets_core_attacker"] = _slot_matches_any(bench_target, ["Drifloon", "Scream Tail", "Gardevoir ex", "飘飘球", "吼叫尾", "沙奈朵ex"])
		"attack":
			var attack_index: int = int(action.get("attack_index", -1))
			var damage: int = gsm.get_attack_preview_damage(player_index, attack_index)
			features["projected_damage"] = float(damage)
			features["targets_core_attacker"] = true
			var opponent_index: int = 1 - player_index
			if opponent_index >= 0 and opponent_index < gsm.game_state.players.size():
				var defender: PokemonSlot = gsm.game_state.players[opponent_index].active_pokemon
				if defender != null:
					features["projected_knockout"] = damage >= defender.get_remaining_hp()
		"granted_attack":
			var granted_damage: int = int(action.get("projected_damage", 0))
			features["projected_damage"] = float(granted_damage)
			var granted_opponent_index: int = 1 - player_index
			if granted_opponent_index >= 0 and granted_opponent_index < gsm.game_state.players.size():
				var granted_defender: PokemonSlot = gsm.game_state.players[granted_opponent_index].active_pokemon
				if granted_defender != null:
					features["projected_knockout"] = granted_damage >= granted_defender.get_remaining_hp()
		"end_turn":
			features["productive"] = false
			features["deck_out_pressure"] = _has_deck_out_pressure(player, gsm)

	return features


func build_vector(gsm: GameStateMachine, player_index: int, action: Dictionary) -> Array[float]:
	var features: Dictionary = build_features(gsm, player_index, action)
	var kind: String = str(action.get("kind", ""))
	var vector: Array[float] = []
	vector.append(1.0 if kind == "play_trainer" else 0.0)
	vector.append(1.0 if kind == "play_stadium" else 0.0)
	vector.append(1.0 if kind == "use_ability" else 0.0)
	vector.append(1.0 if kind == "attach_tool" else 0.0)
	vector.append(1.0 if kind == "attach_energy" else 0.0)
	vector.append(1.0 if kind == "play_basic_to_bench" else 0.0)
	vector.append(1.0 if kind == "evolve" else 0.0)
	vector.append(1.0 if kind == "retreat" else 0.0)
	vector.append(1.0 if kind == "attack" else 0.0)
	vector.append(1.0 if kind == "granted_attack" else 0.0)
	vector.append(1.0 if kind == "end_turn" else 0.0)
	vector.append(1.0 if bool(features.get("is_active_target", false)) else 0.0)
	vector.append(1.0 if bool(features.get("is_bench_target", false)) else 0.0)
	vector.append(1.0 if bool(features.get("requires_interaction", false)) else 0.0)
	vector.append(1.0 if bool(features.get("improves_bench_development", false)) else 0.0)
	vector.append(_normalized_delta(float(features.get("bench_development_delta", 0.0)), 3.0))
	vector.append(1.0 if bool(features.get("improves_attack_readiness", false)) else 0.0)
	vector.append(1.0 if bool(features.get("improves_bench_attack_readiness", false)) else 0.0)
	vector.append(1.0 if bool(features.get("productive", true)) else 0.0)
	vector.append(1.0 if bool(features.get("search_productive", false)) else 0.0)
	vector.append(1.0 if bool(features.get("creates_churn_risk", false)) else 0.0)
	vector.append(1.0 if bool(features.get("deck_out_pressure", false)) else 0.0)
	vector.append(_normalized_delta(float(features.get("remaining_basic_targets", 0.0)), 6.0))
	vector.append(_normalized_delta(float(features.get("projected_damage", 0.0)), 330.0))
	vector.append(1.0 if bool(features.get("projected_knockout", false)) else 0.0)
	vector.append(1.0 if bool(features.get("consumes_hand_card", false)) else 0.0)
	vector.append(1.0 if bool(features.get("targets_core_engine_piece", false)) else 0.0)
	vector.append(1.0 if bool(features.get("targets_core_attacker", false)) else 0.0)
	vector.append(1.0 if bool(features.get("ability_is_engine", false)) else 0.0)
	vector.append(1.0 if bool(features.get("trainer_is_engine_search", false)) else 0.0)
	vector.append(1.0 if bool(features.get("evolve_is_stage2_engine", false)) else 0.0)
	vector.append(1.0 if bool(features.get("discard_fuel_available", false)) else 0.0)
	vector.append(_normalized_delta(float(features.get("bench_slots_remaining", 0.0)), 5.0))
	vector.append(1.0 if bool(features.get("stage2_engine_online", false)) else 0.0)
	return vector


func _action_consumes_hand_card(action: Dictionary) -> bool:
	return action.get("card") is CardInstance


func _has_open_bench_slot(player: PlayerState) -> bool:
	return player != null and player.bench.size() < 5


func _attach_enables_attack(gsm: GameStateMachine, active_slot: PokemonSlot, action: Dictionary) -> bool:
	if gsm == null or gsm.rule_validator == null or active_slot == null:
		return false
	var card_data: CardData = active_slot.get_card_data()
	var energy_card: CardInstance = action.get("card")
	if card_data == null or energy_card == null or card_data.attacks.is_empty():
		return false
	var simulated_slot := PokemonSlot.new()
	simulated_slot.pokemon_stack = active_slot.pokemon_stack.duplicate()
	simulated_slot.attached_energy = active_slot.attached_energy.duplicate()
	simulated_slot.attached_energy.append(energy_card)

	for attack: Dictionary in card_data.attacks:
		var cost: String = CardData.normalize_attack_cost(attack.get("cost", ""))
		if cost == "":
			continue
		var has_attack_before_attach: bool = gsm.rule_validator.has_enough_energy(active_slot, cost, gsm.effect_processor, gsm.game_state)
		if has_attack_before_attach:
			continue
		if gsm.rule_validator.has_enough_energy(simulated_slot, cost, gsm.effect_processor, gsm.game_state):
			return true
	return false


func _count_basic_targets(deck: Array[CardInstance]) -> int:
	var count: int = 0
	for card: CardInstance in deck:
		if card != null and card.is_basic_pokemon():
			count += 1
	return count


func _board_has_ready_attacker(player: PlayerState, gsm: GameStateMachine) -> bool:
	if player == null or gsm == null:
		return false
	var slots: Array[PokemonSlot] = []
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	for slot: PokemonSlot in slots:
		if _slot_can_attack_now(gsm, slot):
			return true
	return false


func _slot_can_attack_now(gsm: GameStateMachine, slot: PokemonSlot) -> bool:
	if gsm == null or gsm.rule_validator == null or slot == null:
		return false
	var card_data: CardData = slot.get_card_data()
	if card_data == null:
		return false
	for attack: Dictionary in card_data.attacks:
		var cost: String = CardData.normalize_attack_cost(attack.get("cost", ""))
		if cost == "":
			continue
		if gsm.rule_validator.has_enough_energy(slot, cost, gsm.effect_processor, gsm.game_state):
			return true
	return false


func _has_deck_out_pressure(player: PlayerState, gsm: GameStateMachine) -> bool:
	if player == null or gsm == null:
		return false
	return player.deck.size() <= 8 and _board_has_ready_attacker(player, gsm)


func _is_churn_trainer(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	var name: String = str(card.card_data.name)
	return name in ["Professor's Research", "博士的研究", "Iono", "奇树"]


func _is_nest_ball(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	return card.card_data.effect_id == NEST_BALL_EFFECT_ID


func _card_matches_any(card: CardInstance, names: Array[String]) -> bool:
	if card == null or card.card_data == null:
		return false
	var card_name: String = str(card.card_data.name)
	var card_name_en: String = str(card.card_data.name_en)
	for candidate: String in names:
		if candidate == card_name or (card_name_en != "" and candidate == card_name_en):
			return true
	return false


func _slot_matches_any(slot: PokemonSlot, names: Array[String]) -> bool:
	if slot == null:
		return false
	var top_card: CardData = slot.get_card_data()
	if top_card == null:
		return false
	for candidate: String in names:
		if candidate == str(top_card.name) or (str(top_card.name_en) != "" and candidate == str(top_card.name_en)):
			return true
	return false


func _has_discard_energy_fuel(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.discard_pile:
		if card == null or card.card_data == null:
			continue
		var provides: String = str(card.card_data.energy_provides)
		if card.card_data.is_energy() and provides == "P":
			return true
	return false


func _has_stage2_engine_online(player: PlayerState) -> bool:
	if player == null:
		return false
	var slots: Array[PokemonSlot] = []
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	for slot: PokemonSlot in slots:
		if _slot_matches_any(slot, ["Gardevoir ex", "Charizard ex", "沙奈朵ex", "喷火龙ex"]):
			return true
	return false


func _normalized_delta(value: float, max_value: float) -> float:
	if max_value <= 0.0:
		return 0.0
	return clampf(value / max_value, 0.0, 1.0)
