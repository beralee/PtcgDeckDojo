class_name DeckStrategyGardevoir
extends "res://scripts/ai/DeckStrategyBase.gd"


const VERSION := "v8.0"
const NeuralNetInferenceScript = preload("res://scripts/ai/NeuralNetInference.gd")
const GardevoirStateEncoderScript = preload("res://scripts/ai/GardevoirStateEncoder.gd")

var gardevoir_value_net: RefCounted = null
var gardevoir_encoder_class: GDScript = GardevoirStateEncoderScript


func get_strategy_id() -> String:
	return "gardevoir"


func get_signature_names() -> Array[String]:
	return [GARDEVOIR_EX, KIRLIA, RALTS]


func get_state_encoder_class() -> GDScript:
	return gardevoir_encoder_class


func load_value_net(path: String) -> bool:
	return load_gardevoir_value_net(path)


func get_value_net() -> RefCounted:
	return gardevoir_value_net


func load_gardevoir_value_net(path: String) -> bool:
	var net := NeuralNetInferenceScript.new()
	if net.load_weights(path):
		gardevoir_value_net = net
		return true
	gardevoir_value_net = null
	return false


func has_gardevoir_value_net() -> bool:
	return gardevoir_value_net != null and gardevoir_value_net.is_loaded()

const GARDEVOIR_EX := "沙奈朵ex"
const KIRLIA := "奇鲁莉安"
const RALTS := "拉鲁拉丝"
const KLEFKI := "钥圈儿"
const MUNKIDORI := "愿增猿"
const MANAPHY := "玛纳霏"
const DRIFLOON := "飘飘球"
const DRIFBLIM := "附和气球"
const SCREAM_TAIL := "吼叫尾"
const BRAVERY_CHARM := "勇气护符"
const RESCUE_STRETCHER := "救援担架"
const NIGHT_STRETCHER := "夜间担架"
const FLUTTER_MANE := "振翼发"
const RADIANT_GRENINJA := "光辉甲贺忍蛙"
const TM_EVOLUTION := "招式学习器 进化"
const IONO := "奇树"
const ARTAZON := "深钵镇"
const PROF_TURO := "弗图博士的剧本"

const BUDDY_BUDDY_POFFIN := "友好宝芬"
const ARVEN := "派帕"
const EARTHEN_VESSEL := "大地容器"
const COUNTER_CATCHER := "反击捕捉器"
const BOSSS_ORDERS := "老大的指令"
const RARE_CANDY := "神奇糖果"
const SUPER_ROD := "厉害钓竿"
const ULTRA_BALL := "高级球"
const NEST_BALL := "巢穴球"
const SECRET_BOX := "秘密箱"
const HISUIAN_HEAVY_BALL := "洗翠的沉重球"
const PSYCHIC_ENERGY := "基本超能量"
const DARK_ENERGY := "基本恶能量"
const CHARIZARD_EX_EN := "Charizard ex"
const PIDGEOT_EX_EN := "Pidgeot ex"
const PIDGEY_EN := "Pidgey"
const CHARMANDER_EN := "Charmander"
const DUSKULL_EN := "Duskull"
const ROTOM_V_EN := "Rotom V"

const CORE_NAMES: Array[String] = [RALTS, KIRLIA, GARDEVOIR_EX]
const CONTROL_NAMES: Array[String] = [KLEFKI, FLUTTER_MANE]
const ATTACKER_NAMES: Array[String] = [DRIFLOON, DRIFBLIM, SCREAM_TAIL]
const SUPPORT_NAMES: Array[String] = [MUNKIDORI, MANAPHY, KLEFKI, FLUTTER_MANE]
const BENCH_PRIORITY_NAMES: Array[String] = [RALTS, KLEFKI, FLUTTER_MANE, DRIFLOON, SCREAM_TAIL, MUNKIDORI, MANAPHY]
const SEARCH_PRIORITY_NAMES: Array[String] = [RALTS, KIRLIA, GARDEVOIR_EX, DRIFLOON, SCREAM_TAIL, MUNKIDORI, FLUTTER_MANE, MANAPHY]



const COMBO_RULES: Array[Dictionary] = [
	{"name": "建立引擎", "desc": "先完成拉鲁拉丝到沙奈朵ex的进化链"},
	{"name": "飘飘球收割", "desc": "Embrace给飘飘球补能，并承受20伤害"},
	{"name": "吼叫尾狙击", "desc": "Embrace给吼叫尾补能，并承受30伤害"},
	{"name": "资源加速", "desc": "优先把超能量送进弃牌区供Embrace使用"},
	{"name": "愿增猿压血", "desc": "让Munkidori转移伤害，配合低血量收奖"},
]



func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	var phase: String = _detect_game_phase(int(game_state.turn_number), player)

	var shell_lock: bool = _shell_lock_active(player)
	var transition: bool = _has_transition_shell(player)
	var shell_online: bool = _has_online_shell(player)
	var ready_attackers: int = _count_ready_attackers(player)
	var attacker_bodies: int = _count_attackers_on_field(player)
	var bench_ready_attacker: bool = false
	for bench_slot: PokemonSlot in player.bench:
		if _is_ready_attacker(bench_slot):
			bench_ready_attacker = true
			break
	var shell_bodies: int = _count_primary_shell_bodies(player)
	var has_gardevoir: bool = _count_pokemon_on_field(player, GARDEVOIR_EX) >= 1
	var has_kirlia: bool = _count_pokemon_on_field(player, KIRLIA) >= 1
	var discard_p: int = _count_psychic_energy_in_discard(game_state, player_index)
	var tm_setup_live: bool = _tm_setup_priority_live(player, phase)
	var tm_precharge: bool = _tm_precharge_window(player)
	var first_gard_emergency: bool = _first_gardevoir_emergency(player)
	var must_force_first_gardevoir: bool = _must_force_first_gardevoir(player)
	var fuel_gate: bool = _first_gardevoir_fuel_gate(game_state, player, player_index)
	var post_tm_refill: bool = _post_tm_refill_window(game_state, player, player_index)
	var handoff_window: bool = _gardevoir_handoff_window(game_state, player, player_index)
	var attacker_recovery: bool = _needs_attacker_recovery(game_state, player, player_index)
	var closed_loop_rebuild: bool = _attacker_rebuild_closed_loop_live(game_state, player, player_index)
	var charizard_matchup: bool = _is_charizard_pressure_matchup(game_state, player_index)
	var charizard_rebuild: bool = _charizard_rebuild_lock(game_state, player, player_index)
	var deck_out: bool = _has_deck_out_pressure(player)
	var immediate_attack_window: bool = _has_immediate_attack_window(game_state, player, player_index)

	var flags: Dictionary = {
		"shell_lock": shell_lock,
		"shell_online": shell_online,
		"transition_shell": transition,
		"ready_attacker_on_bench": bench_ready_attacker,
		"immediate_attack_window": immediate_attack_window,
		"shell_bodies_lt2": shell_bodies < 2,
		"shell_bodies_full": shell_bodies >= 2,
		"has_gardevoir_ex": has_gardevoir,
		"has_kirlia": has_kirlia,
		"tm_setup_live": tm_setup_live,
		"tm_precharge_window": tm_precharge,
		"post_tm_refill_window": post_tm_refill,
		"first_gardevoir_emergency": first_gard_emergency,
		"must_force_first_gardevoir": must_force_first_gardevoir,
		"first_gardevoir_fuel_gate": fuel_gate,
		"handoff_window": handoff_window,
		"attacker_recovery_mode": attacker_recovery,
		"attacker_rebuild_closed_loop": closed_loop_rebuild,
		"vs_charizard": charizard_matchup,
		"charizard_rebuild_lock": charizard_rebuild,
		"deck_out_pressure": deck_out,
		"discard_has_psychic": discard_p >= 1,
		"discard_has_embrace_fuel": discard_p >= 2,
	}

	var intent: String = "launch_shell"
	if shell_lock:
		if post_tm_refill:
			intent = "post_tm_refill"
		elif first_gard_emergency:
			intent = "force_first_gardevoir"
		elif tm_setup_live or tm_precharge:
			intent = "launch_shell_tm"
		elif shell_bodies < 2:
			intent = "launch_shell"
		else:
			intent = "launch_shell_attacker_search"
	elif shell_online and closed_loop_rebuild:
		intent = "rebuild_attacker_closed_loop"
	elif shell_online and attacker_bodies == 0:
		intent = "rebuild_attacker"
	elif shell_online and attacker_recovery:
		intent = "rebuild_attacker"
	elif shell_online and attacker_bodies >= 1 and ready_attackers == 0:
		intent = "transition_to_conversion"
	elif shell_online and ready_attackers >= 1:
		intent = "convert_attack" if immediate_attack_window else "transition_to_conversion"
	elif deck_out:
		intent = "dead_turn_preserve_outs"

	var bridge_target_name: String = ""
	if shell_lock and shell_bodies < 2:
		bridge_target_name = RALTS
	elif shell_lock and shell_bodies >= 2 and not has_kirlia:
		bridge_target_name = KIRLIA
	elif must_force_first_gardevoir:
		bridge_target_name = GARDEVOIR_EX
	elif shell_online and attacker_bodies == 0:
		bridge_target_name = DRIFLOON

	var primary_attacker_name: String = ""
	var pivot_target_name: String = ""
	if ready_attackers >= 1:
		for slot: PokemonSlot in _get_all_slots(player):
			if slot == null:
				continue
			var n: String = slot.get_pokemon_name()
			if n in ATTACKER_NAMES and _get_attack_energy_gap(slot) == 0:
				primary_attacker_name = n
				break
	if primary_attacker_name == "" and intent in ["rebuild_attacker", "rebuild_attacker_closed_loop"] and bridge_target_name != "":
		primary_attacker_name = bridge_target_name
	if primary_attacker_name == "":
		if shell_lock and shell_bodies < 2 and bridge_target_name != "":
			primary_attacker_name = bridge_target_name
		elif must_force_first_gardevoir and bridge_target_name != "":
			primary_attacker_name = bridge_target_name
		elif attacker_bodies >= 1:
			for slot: PokemonSlot in _get_all_slots(player):
				if slot == null:
					continue
				var n2: String = slot.get_pokemon_name()
				if n2 in ATTACKER_NAMES:
					primary_attacker_name = n2
					break
		elif has_gardevoir:
			primary_attacker_name = GARDEVOIR_EX
		elif player.active_pokemon != null:
			primary_attacker_name = player.active_pokemon.get_pokemon_name()

	if shell_lock and shell_bodies < 2:
		pivot_target_name = bridge_target_name
	elif must_force_first_gardevoir and bridge_target_name != "":
		pivot_target_name = bridge_target_name
	elif shell_online and attacker_bodies == 0:
		pivot_target_name = primary_attacker_name
	elif has_gardevoir:
		pivot_target_name = primary_attacker_name

	var targets: Dictionary = {
		"primary_attacker_name": primary_attacker_name,
		"bridge_target_name": bridge_target_name,
		"pivot_target_name": pivot_target_name,
	}

	var constraints: Dictionary = {
		"must_attack_if_available": intent == "convert_attack" and immediate_attack_window,
		"forbid_extra_bench_padding": intent == "convert_attack" and attacker_bodies >= 1,
		"forbid_engine_churn": intent in ["rebuild_attacker_closed_loop", "convert_attack"],
		"prefer_tm_combo_this_turn": tm_setup_live,
	}

	var modifiers: Array[String] = []
	for key: String in flags.keys():
		if bool(flags.get(key, false)):
			modifiers.append(key)
	modifiers.sort()

	return {
		"intent": intent,
		"phase": phase,
		"flags": flags,
		"targets": targets,
		"constraints": constraints,
		"modifiers": modifiers,
		"context": context.duplicate(true),
	}


func build_turn_contract(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	var contract: Dictionary = _normalize_turn_contract(build_turn_plan(game_state, player_index, context))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return contract
	var player: PlayerState = game_state.players[player_index]
	var targets: Dictionary = contract.get("targets", {}) if contract.get("targets", {}) is Dictionary else {}
	var owner: Dictionary = contract.get("owner", {}) if contract.get("owner", {}) is Dictionary else {}

	var primary_attacker_name: String = str(targets.get("primary_attacker_name", ""))
	var bridge_target_name: String = str(targets.get("bridge_target_name", ""))
	var pivot_target_name: String = str(targets.get("pivot_target_name", ""))

	if str(owner.get("turn_owner_name", "")) == "":
		owner["turn_owner_name"] = primary_attacker_name
	if str(owner.get("bridge_target_name", "")) == "":
		owner["bridge_target_name"] = bridge_target_name
	if str(owner.get("pivot_target_name", "")) == "":
		owner["pivot_target_name"] = pivot_target_name
	contract["owner"] = owner

	var attach_priority: Array[String] = []
	if bridge_target_name != "":
		attach_priority.append(bridge_target_name)
	if primary_attacker_name != "" and not attach_priority.has(primary_attacker_name):
		attach_priority.append(primary_attacker_name)
	if pivot_target_name != "" and pivot_target_name != primary_attacker_name and not attach_priority.has(pivot_target_name):
		attach_priority.append(pivot_target_name)

	var search_priority: Array[String] = []
	if bridge_target_name != "":
		search_priority.append(bridge_target_name)
	if primary_attacker_name != "" and not search_priority.has(primary_attacker_name):
		search_priority.append(primary_attacker_name)

	var handoff_priority: Array[String] = []
	if pivot_target_name != "":
		handoff_priority.append(pivot_target_name)
	if primary_attacker_name != "" and not handoff_priority.has(primary_attacker_name):
		handoff_priority.append(primary_attacker_name)

	var priorities: Dictionary = contract.get("priorities", {}) if contract.get("priorities", {}) is Dictionary else {}
	priorities["attach"] = attach_priority
	priorities["search"] = search_priority
	priorities["handoff"] = handoff_priority
	contract["priorities"] = priorities
	return contract



func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var kind: String = str(action.get("kind", ""))
	var player: PlayerState = game_state.players[player_index]
	var turn: int = int(game_state.turn_number)
	var phase: String = _detect_game_phase(turn, player)
	match kind:
		"play_basic_to_bench":
			return _abs_play_basic(action, game_state, player, player_index, phase)
		"play_stadium":
			return _abs_play_trainer(action, game_state, player, player_index, phase)
		"evolve":
			return _abs_evolve(action, player, phase, game_state, player_index)
		"attach_energy":
			return _abs_attach_energy(action, game_state, player, player_index)
		"attach_tool":
			return _abs_attach_tool(action, game_state, player, player_index, phase)
		"use_ability":
			return _abs_use_ability(action, game_state, player, player_index, phase)
		"play_trainer":
			return _abs_play_trainer(action, game_state, player, player_index, phase)
		"retreat":
			return _abs_retreat(action, game_state, player, player_index)
		"attack":
			return _abs_attack(action, game_state, player_index)
		"granted_attack":
			return _abs_granted_attack(action, game_state, player, player_index, phase)
	return 0.0


func _abs_play_basic(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	var card: CardInstance = action.get("card")
	if card == null or card.card_data == null:
		return 0.0
	var name: String = str(card.card_data.name)
	var bench_size: int = player.bench.size()
	if bench_size >= 5:
		return 0.0
	var shell_lock: bool = _shell_lock_active(player)
	var transition_shell: bool = _has_transition_shell(player)
	var ready_attackers: int = _count_ready_attackers(player)
	var attacker_bodies: int = _count_attackers_on_field(player)
	var essential_slots_needed: int = _count_essential_slots_needed(player)
	var free_slots: int = 5 - bench_size
	var is_essential: bool = _is_essential_pokemon(name, player)
	var charizard_rebuild_lock: bool = _charizard_rebuild_lock(game_state, player, player_index)

	if not is_essential and free_slots <= essential_slots_needed:
		return 0.0

	if shell_lock:
		if name == RALTS:
			if _count_primary_shell_bodies(player) >= 2:
				return 20.0
			return 420.0 if phase == "early" else 340.0
		if name in [KLEFKI, FLUTTER_MANE]:
			return -40.0
		if name == DRIFLOON:
			if attacker_bodies == 0 and free_slots > 0 and _count_primary_shell_bodies(player) >= 1:
				return 140.0
			if _count_primary_shell_bodies(player) >= 2 and not _must_force_first_gardevoir(player):
				return 120.0
			return -80.0
		if name == SCREAM_TAIL:
			if attacker_bodies == 0 and free_slots > 0 and _count_primary_shell_bodies(player) >= 1:
				return 110.0
			return -60.0
		if name in [MUNKIDORI, RADIANT_GRENINJA, MANAPHY]:
			return -120.0
		return -80.0

	if not transition_shell:
		if _has_online_shell(player) and attacker_bodies == 0:
			if name == DRIFLOON:
				return 360.0
			if name == SCREAM_TAIL:
				if _opponent_has_scream_tail_prize_target(game_state, player_index):
					return 320.0
				return 220.0
			if name == MUNKIDORI:
				return -120.0
			if name == RALTS:
				return -20.0
		if name == RALTS:
			return 120.0
		if name == DRIFLOON:
			if attacker_bodies == 0 and _opponent_has_scream_tail_prize_target(game_state, player_index):
				return 260.0
			return 320.0 if attacker_bodies == 0 else 80.0
		if name == SCREAM_TAIL:
			if attacker_bodies == 0 and _opponent_has_scream_tail_prize_target(game_state, player_index):
				return 360.0
			return 260.0 if attacker_bodies == 0 else 40.0
		if name == MUNKIDORI:
			return -80.0 if attacker_bodies == 0 else 20.0
		if name == RADIANT_GRENINJA:
			return -60.0
		if name in [KLEFKI, FLUTTER_MANE]:
			return 20.0
		if name == MANAPHY:
			return 60.0 if _count_pokemon_on_field(player, MANAPHY) == 0 else 0.0
		return -20.0

	if charizard_rebuild_lock:
		if name == MUNKIDORI:
			return -140.0
		if name == RALTS:
			return -80.0
		if name in [FLUTTER_MANE, KLEFKI, MANAPHY, RADIANT_GRENINJA]:
			return -120.0

	if transition_shell and _opponent_has_scream_tail_prize_target(game_state, player_index):
		if name == SCREAM_TAIL and _count_pokemon_on_field(player, SCREAM_TAIL) == 0:
			if ready_attackers >= 1:
				return 180.0
			if attacker_bodies >= 1:
				return 240.0

	if transition_shell and attacker_bodies >= 1 and ready_attackers == 0:
		if name in [FLUTTER_MANE, KLEFKI, MANAPHY, MUNKIDORI]:
			return -90.0
		if name == RADIANT_GRENINJA:
			return -60.0
		if name == RALTS:
			return 0.0

	if _has_deck_out_pressure(player) and ready_attackers >= 1:
		if name == RALTS:
			return -40.0
		if name in [RADIANT_GRENINJA, FLUTTER_MANE, KLEFKI, MANAPHY, MUNKIDORI]:
			return -80.0

	if attacker_bodies == 0:
		if name == DRIFLOON:
			if _opponent_has_scream_tail_prize_target(game_state, player_index):
				return 260.0
			return 320.0
		if name == SCREAM_TAIL:
			if _opponent_has_scream_tail_prize_target(game_state, player_index):
				return 360.0
			return 260.0
		if name == RALTS:
			return 20.0
		if name == MUNKIDORI:
			return -60.0
		if name == RADIANT_GRENINJA:
			return -50.0
		return 0.0

	if ready_attackers >= 1:
		if name == RALTS:
			return -80.0
		if name in [FLUTTER_MANE, KLEFKI, RADIANT_GRENINJA, MUNKIDORI, MANAPHY]:
			return -100.0
		if name in [DRIFLOON, SCREAM_TAIL]:
			return -20.0
	return 20.0


func _abs_evolve(action: Dictionary, player: PlayerState, phase: String, game_state: GameState = null, player_index: int = -1) -> float:
	var card: CardInstance = action.get("card")
	if card == null or card.card_data == null:
		return 0.0
	var name: String = str(card.card_data.name)
	if name == GARDEVOIR_EX:
		if _count_pokemon_on_field(player, GARDEVOIR_EX) == 0:
			return 1000.0 if _first_gardevoir_emergency(player) else 800.0
		var kirlia_count: int = _count_pokemon_on_field(player, KIRLIA)
		if kirlia_count <= 1:
			return 100.0
		return 350.0
	if name == KIRLIA:
		var base: float = 450.0 if phase != "late" else 300.0
		if _hand_has_card(player, GARDEVOIR_EX):
			base += 100.0
		return base
	if name == DRIFBLIM:
		return 200.0
	return 50.0


func _abs_attach_energy(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int) -> float:
	var target_slot: PokemonSlot = action.get("target_slot")
	var energy_card: CardInstance = action.get("card")
	if target_slot == null or energy_card == null or energy_card.card_data == null:
		return 0.0
	if not _slot_is_live(target_slot):
		return -300.0
	var target_name: String = target_slot.get_pokemon_name()
	var energy_type: String = str(energy_card.card_data.energy_provides)
	var shell_lock: bool = _shell_lock_active(player)
	var tm_live: bool = _tm_setup_priority_live(player, "mid")
	var stage2_shell: bool = _has_established_stage2_shell(player)
	var ready_attackers: int = _count_ready_attackers(player)
	var live_attackers: int = _count_live_attackers(player)
	var active_name: String = player.active_pokemon.get_pokemon_name() if player.active_pokemon != null else ""
	var charizard_matchup: bool = _is_charizard_pressure_matchup(game_state, player_index)
	var delay_attacker_investment: bool = _should_delay_attacker_investment_during_shell_lock(player)

	if target_name == KIRLIA:
		if _must_force_first_gardevoir(player) and _count_psychic_energy_in_discard(game_state, player_index) >= 2:
			return -240.0
		if _must_force_first_gardevoir(player) and (_active_has_tm_evolution(player) or _hand_has_card(player, TM_EVOLUTION)):
			return -220.0

	if target_slot == player.active_pokemon and target_name == SCREAM_TAIL and _get_attack_energy_gap(target_slot) <= 1:
		if delay_attacker_investment:
			return -160.0
		if energy_type == "D":
			return 900.0
		if energy_type == "P":
			return 520.0
	if target_slot == player.active_pokemon and target_name == DRIFLOON and _get_attack_energy_gap(target_slot) <= 1 and energy_type == "P":
		if delay_attacker_investment:
			return -160.0
		return 520.0
	if shell_lock and target_slot == player.active_pokemon and (_hand_has_card(player, TM_EVOLUTION) or _active_has_tm_evolution(player)) and _count_evolvable_bench_targets(player) >= 1:
		return 760.0
	if tm_live and target_slot == player.active_pokemon and _tm_attack_payment_gap(target_slot) <= 1:
		return 760.0
	if shell_lock and target_slot == player.active_pokemon and (_hand_has_card(player, TM_EVOLUTION) or _active_has_tm_evolution(player)):
		if target_name not in ATTACKER_NAMES and target_name != SCREAM_TAIL:
			if target_slot.attached_energy.size() == 0:
				return 320.0 if _count_primary_shell_bodies(player) >= 1 or _has_shell_search(player) else 180.0
	if shell_lock and target_slot == player.active_pokemon and _tm_precharge_window(player):
		if target_name in [RALTS, KIRLIA, FLUTTER_MANE, KLEFKI, MUNKIDORI] and target_slot.attached_energy.size() == 0:
			return 280.0
	if shell_lock and target_slot == player.active_pokemon and _count_primary_shell_bodies(player) >= 2:
		if active_name in [FLUTTER_MANE, KLEFKI, MUNKIDORI, DRIFLOON]:
			if target_slot.attached_energy.size() == 0:
				return 260.0

	if target_slot == player.active_pokemon \
	   and target_name not in ATTACKER_NAMES and target_name != SCREAM_TAIL:
		var retreat_gap: int = _get_retreat_energy_gap(target_slot)
		if retreat_gap > 0 and retreat_gap <= 1:
			var has_bench_attacker: bool = false
			for bench_slot: PokemonSlot in player.bench:
				if _is_ready_attacker(bench_slot):
					has_bench_attacker = true
					break
			if has_bench_attacker:
				return 380.0

	if energy_type == "P":
		if shell_lock:
			return -100.0
		if target_name == KIRLIA:
			if _has_transition_shell(player) or _count_pokemon_on_field(player, GARDEVOIR_EX) >= 1:
				return -160.0
		if stage2_shell and live_attackers == 0:
			var preferred_transition_attacker: String = _preferred_transition_attacker_name(game_state, player_index)
			if target_name == DRIFLOON or target_name == DRIFBLIM:
				if preferred_transition_attacker == DRIFLOON and _get_attack_energy_gap(target_slot) <= 1:
					return 620.0 if target_slot == player.active_pokemon else 500.0
				if _get_attack_energy_gap(target_slot) <= 1:
					return 520.0 if target_slot == player.active_pokemon else 420.0
			if target_name == SCREAM_TAIL and _get_attack_energy_gap(target_slot) <= 1:
				if preferred_transition_attacker == SCREAM_TAIL:
					if _opponent_has_scream_tail_prize_target(game_state, player_index):
						return 660.0 if target_slot == player.active_pokemon else 560.0
					return 600.0 if target_slot == player.active_pokemon else 500.0
				if _opponent_has_scream_tail_prize_target(game_state, player_index):
					return 560.0 if target_slot == player.active_pokemon else 460.0
				return 480.0 if target_slot == player.active_pokemon else 380.0
		if target_slot == player.active_pokemon and target_name == DRIFLOON and live_attackers == 0 and _get_attack_energy_gap(target_slot) <= 1:
			return 560.0
		if target_slot == player.active_pokemon and target_name == SCREAM_TAIL and live_attackers == 0 and _get_attack_energy_gap(target_slot) <= 1:
			return 520.0
		return -100.0
	if energy_type == "D":
		if target_name == SCREAM_TAIL and live_attackers == 0 and _get_attack_energy_gap(target_slot) <= 1:
			if stage2_shell:
				if _opponent_has_scream_tail_prize_target(game_state, player_index):
					return 720.0 if target_slot == player.active_pokemon else 620.0
				return 640.0 if target_slot == player.active_pokemon else 520.0
			if target_slot == player.active_pokemon:
				return 580.0
		if target_name == MUNKIDORI:
			if not _slot_has_energy_type(target_slot, "D"):
				if _shell_lock_active(player) or _count_pokemon_on_field(player, GARDEVOIR_EX) == 0:
					if target_slot == player.active_pokemon and (_hand_has_card(player, TM_EVOLUTION) or _active_has_tm_evolution(player)):
						return 260.0
					return 320.0
				if charizard_matchup and _has_transition_shell(player) and not _munkidori_can_threaten_ko(game_state, player_index):
					return -140.0
				if _has_transition_shell(player) and ready_attackers >= 1:
					return -40.0
				return 320.0
			if charizard_matchup and _has_transition_shell(player) and not _munkidori_can_threaten_ko(game_state, player_index):
				return -140.0
			if _has_transition_shell(player) and ready_attackers >= 1:
				return 0.0
			return -100.0
		if shell_lock and not (tm_live and target_slot == player.active_pokemon):
			return -100.0
		if target_slot == player.active_pokemon and target_name not in ATTACKER_NAMES and target_name != SCREAM_TAIL:
			var retreat_gap: int = _get_retreat_energy_gap(target_slot)
			if retreat_gap > 0 and retreat_gap <= 1:
				for bench_slot: PokemonSlot in player.bench:
					if _is_ready_attacker(bench_slot):
						return 350.0
		return -100.0
	return -100.0


func _abs_attach_tool(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int, phase: String = "mid") -> float:
	var card: CardInstance = action.get("card")
	var target_slot: PokemonSlot = action.get("target_slot")
	if card == null or card.card_data == null or target_slot == null:
		return 0.0
	if not _slot_is_live(target_slot):
		return -300.0
	var tool_name: String = str(card.card_data.name)
	var target_name: String = target_slot.get_pokemon_name()
	if tool_name == TM_EVOLUTION:
		if target_slot != player.active_pokemon:
			return -200.0
		if _tm_support_carrier_cools_off(player, phase):
			return -220.0
		if _has_online_shell(player):
			return -180.0
		var shell_bodies: int = _count_primary_shell_bodies(player)
		var evolvable_targets: int = _count_evolvable_bench_targets(player)
		if _shell_lock_active(player) and shell_bodies == 0 and evolvable_targets == 0:
			return -120.0
		if _must_force_first_gardevoir(player):
			return 10.0
		if evolvable_targets == 0:
			return 260.0 if _shell_lock_active(player) and shell_bodies >= 1 else -100.0
		var active_energy: int = target_slot.attached_energy.size()
		var can_power: bool = active_energy >= 1 or _hand_has_any_energy(player)
		if _shell_lock_active(player):
			if can_power:
				return 550.0
			return 180.0
		if _tm_precharge_window(player):
			return 160.0
		return -80.0
	if tool_name == BRAVERY_CHARM:
		if _shell_lock_active(player):
			return -120.0
		if target_name == SCREAM_TAIL:
			return 250.0
		if target_name == DRIFBLIM or target_name == DRIFLOON:
			return 200.0
		return -100.0
	if target_name in ATTACKER_NAMES or target_name == SCREAM_TAIL:
		return 100.0
	return -100.0


func _abs_use_ability(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	var source_slot: PokemonSlot = action.get("source_slot")
	if source_slot == null:
		return 0.0
	if not _slot_is_live(source_slot):
		return -300.0
	var source_name: String = source_slot.get_pokemon_name()
	var card_data: CardData = source_slot.get_card_data()
	if card_data == null:
		return 0.0
	if source_name == GARDEVOIR_EX:
		return _abs_psychic_embrace(game_state, player, player_index)
	if source_name == KIRLIA:
		if _post_tm_refill_window(game_state, player, player_index):
			return 520.0
		if _first_gardevoir_fuel_gate(game_state, player, player_index):
			return 460.0
		if _first_gardevoir_emergency(player) and _has_direct_first_gardevoir_line(game_state, player, player_index):
			return 120.0
		if _has_deck_out_pressure(player) and _count_ready_attackers(player) >= 1:
			return 0.0
		if _has_transition_shell(player) and _count_ready_attackers(player) >= 1:
			return 30.0
		var hand_size: int = player.hand.size()
		if hand_size <= 1:
			return 50.0
		return 400.0 if phase != "late" else 250.0
	if source_name == RADIANT_GRENINJA:
		if _post_tm_refill_window(game_state, player, player_index):
			if _hand_has_energy_type(player, "P"):
				return 560.0
			if _hand_has_energy_type(player, "D"):
				return 300.0
		if _first_gardevoir_fuel_gate(game_state, player, player_index) and _hand_has_energy_type(player, "P"):
			return 520.0
		if _has_deck_out_pressure(player) and _count_ready_attackers(player) >= 1:
			return 0.0
		if _shell_lock_active(player) and _count_primary_shell_bodies(player) < 2 and _has_shell_search(player):
			return -80.0
		if _hand_has_energy_type(player, "P"):
			if _shell_lock_active(player) and _count_primary_shell_bodies(player) >= 2:
				return 460.0
			return 420.0
		if _has_transition_shell(player) and _count_ready_attackers(player) >= 1:
			return 20.0
		if _shell_lock_active(player):
			if _count_primary_shell_bodies(player) < 2:
				return -40.0
		if _hand_has_energy_type(player, "D"):
			return 300.0
		return 0.0
	if source_name == MUNKIDORI:
		if _munkidori_can_threaten_ko(game_state, player_index):
			return 600.0
		if _post_stage2_handoff_live(game_state, player, player_index):
			return -120.0
		if _is_charizard_pressure_matchup(game_state, player_index) and _has_transition_shell(player):
			return -120.0
		if _has_transition_shell(player) and _count_ready_attackers(player) >= 1:
			return -80.0
		return -20.0
	if source_name == MANAPHY:
		return 120.0
	return 0.0

func _abs_psychic_embrace(game_state: GameState, player: PlayerState, player_index: int) -> float:
	var discard_psychic: int = _count_psychic_energy_in_discard(game_state, player_index)
	if discard_psychic <= 0:
		return -50.0

	var active: PokemonSlot = player.active_pokemon
	var active_name: String = active.get_pokemon_name() if active != null else ""
	var attacker_bodies: int = _count_attackers_on_field(player)
	var opponent_index: int = 1 - player_index
	var defender: PokemonSlot = null
	if opponent_index >= 0 and opponent_index < game_state.players.size():
		defender = game_state.players[opponent_index].active_pokemon
	var immediate_attack_window: bool = _has_immediate_attack_window(game_state, player, player_index)

	var best_value: float = 0.0
	var closed_loop_rebuild: bool = _attacker_rebuild_closed_loop_live(game_state, player, player_index)
	if _has_established_stage2_shell(player) and attacker_bodies == 0 and not closed_loop_rebuild:
		return -140.0

	for slot: PokemonSlot in _get_all_slots(player):
		var name: String = slot.get_pokemon_name()
		if name not in ATTACKER_NAMES and name != SCREAM_TAIL:
			continue
		if slot.get_remaining_hp() <= 20:
			continue
		var now: Dictionary = predict_attacker_damage(slot, 0)
		var after: Dictionary = predict_attacker_damage(slot, 1)
		var now_dmg: int = int(now.get("damage", 0))
		var after_dmg: int = int(after.get("damage", 0))
		var can_now: bool = bool(now.get("can_attack", false))
		var can_after: bool = bool(after.get("can_attack", false))

		var dmg_gain: int = after_dmg - now_dmg
		if not can_now and can_after:
			if defender != null and after_dmg >= defender.get_remaining_hp():
				best_value = maxf(best_value, 700.0)
			else:
				best_value = maxf(best_value, 500.0)
		elif can_now and defender != null and now_dmg < defender.get_remaining_hp() and after_dmg >= defender.get_remaining_hp():
			best_value = maxf(best_value, 600.0)
		elif can_now and defender != null and now_dmg >= defender.get_remaining_hp():
			if slot == player.active_pokemon:
				best_value = maxf(best_value, 30.0)
			else:
				if immediate_attack_window:
					best_value = maxf(best_value, 200.0 + float(dmg_gain))
				else:
					best_value = maxf(best_value, 60.0)
		elif can_now:
			if immediate_attack_window:
				best_value = maxf(best_value, 200.0 + float(dmg_gain) * 3.0)
			else:
				best_value = maxf(best_value, 80.0 + float(dmg_gain))
		else:
			best_value = maxf(best_value, 300.0)
		if closed_loop_rebuild and can_after:
			best_value = maxf(best_value, 540.0)

	if active != null and active_name not in ATTACKER_NAMES and active_name != SCREAM_TAIL:
		var retreat_gap: int = _get_retreat_energy_gap(active)
		if retreat_gap > 0 and active.get_remaining_hp() > 20:
			for bench_slot: PokemonSlot in player.bench:
				if _is_ready_attacker(bench_slot):
					best_value = maxf(best_value, 400.0)
					break

	if best_value <= 0.0:
		return 50.0
	if _has_deck_out_pressure(player) and not immediate_attack_window and _count_ready_attackers(player) >= 1:
		return minf(best_value, 80.0)
	return best_value


func _abs_play_trainer(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	var card: CardInstance = action.get("card")
	if card == null or card.card_data == null:
		return 0.0
	var name: String = str(card.card_data.name)
	var bench_full: bool = player.bench.size() >= 5

	var hand_size: int = player.hand.size()
	var need_gardevoir: bool = _count_pokemon_on_field(player, GARDEVOIR_EX) == 0
	var has_kirlia: bool = _count_pokemon_on_field(player, KIRLIA) >= 1
	var has_ralts: bool = _count_pokemon_on_field(player, RALTS) >= 1
	var discard_p: int = _count_psychic_energy_in_discard(game_state, player_index)
	var shell_lock: bool = _shell_lock_active(player)
	var transition_shell: bool = _has_transition_shell(player)
	var ready_attackers: int = _count_ready_attackers(player)
	var attacker_bodies: int = _count_attackers_on_field(player)
	var attacker_recovery_mode: bool = _needs_attacker_recovery(game_state, player, player_index)
	var first_attacker_body_rebuild: bool = _needs_first_attacker_body(player)
	var handoff_window: bool = _gardevoir_handoff_window(game_state, player, player_index)
	var post_stage2_handoff_live: bool = _post_stage2_handoff_live(game_state, player, player_index)
	var post_tm_refill_window: bool = _post_tm_refill_window(game_state, player, player_index)
	var fuel_gate: bool = _first_gardevoir_fuel_gate(game_state, player, player_index)
	var attacker_closed_loop: bool = _attacker_rebuild_closed_loop_live(game_state, player, player_index)
	var charizard_rebuild_lock: bool = _charizard_rebuild_lock(game_state, player, player_index)
	if name == BUDDY_BUDDY_POFFIN:
		if bench_full:
			return 0.0
		if post_stage2_handoff_live and not first_attacker_body_rebuild and not attacker_recovery_mode:
			return -180.0
		if first_attacker_body_rebuild:
			var preferred_transition_attacker: String = _preferred_transition_attacker_name(game_state, player_index)
			if preferred_transition_attacker == DRIFLOON and _count_pokemon_on_field(player, DRIFLOON) == 0:
				return 340.0
			return 40.0
		if handoff_window and not attacker_recovery_mode:
			return -160.0
		if _first_gardevoir_emergency(player):
			return -180.0
		if _must_force_first_gardevoir(player):
			if _count_primary_shell_bodies(player) >= 2:
				return -100.0
			return 40.0
		if charizard_rebuild_lock:
			return -140.0
		if attacker_recovery_mode:
			return 40.0
		if shell_lock and _count_primary_shell_bodies(player) >= 2:
			if _active_has_tm_evolution(player) or _hand_has_card(player, TM_EVOLUTION) or _tm_setup_priority_live(player, phase):
				return -80.0
			if not _hand_has_card(player, KIRLIA) and not _hand_has_card(player, GARDEVOIR_EX) \
					and player.bench.size() <= 3:
				return 40.0
			return -40.0
		if transition_shell and ready_attackers >= 1:
			return -120.0
		var essential_needed: int = _count_essential_slots_needed(player)
		if shell_lock and _count_primary_shell_bodies(player) < 2 and not bench_full:
			return 900.0
		if essential_needed >= 2 and phase == "early":
			return 380.0
		if essential_needed >= 1:
			return 300.0
		return 150.0

	if name == NEST_BALL:
		if bench_full:
			return 0.0
		if first_attacker_body_rebuild:
			var preferred_transition_attacker: String = _preferred_transition_attacker_name(game_state, player_index)
			if _count_pokemon_on_field(player, preferred_transition_attacker) == 0:
				return 360.0
			return 180.0
		if handoff_window and not attacker_recovery_mode:
			return -140.0
		if _first_gardevoir_emergency(player):
			return -160.0
		if _must_force_first_gardevoir(player):
			if _count_primary_shell_bodies(player) >= 2:
				return -80.0
			return 30.0
		if charizard_rebuild_lock:
			return -140.0
		if attacker_recovery_mode:
			return 30.0
		if shell_lock and _count_primary_shell_bodies(player) >= 2:
			return -20.0
		if transition_shell and ready_attackers >= 1:
			return -120.0
		var essential_needed: int = _count_essential_slots_needed(player)
		if essential_needed >= 1 and phase == "early":
			return 300.0
			return 200.0
		return 100.0

	if name == ULTRA_BALL:
		if _must_force_first_gardevoir(player) and has_kirlia:
			return 320.0
		return _abs_ultra_ball(game_state, player, player_index, phase, hand_size)

	if name == SECRET_BOX:
		if _must_force_first_gardevoir(player) and has_kirlia:
			return 180.0
		if first_attacker_body_rebuild:
			return maxf(_abs_secret_box(game_state, player, player_index, phase, hand_size), 240.0)
		if _first_gardevoir_emergency(player):
			return 180.0
		if _must_force_first_gardevoir(player):
			return maxf(_abs_secret_box(game_state, player, player_index, phase, hand_size), 220.0)
		if transition_shell and ready_attackers >= 1:
			return -120.0
		return _abs_secret_box(game_state, player, player_index, phase, hand_size)

	if name == ARVEN:
		if post_tm_refill_window:
			return maxf(_abs_arven(game_state, player, player_index, phase), 280.0)
		if first_attacker_body_rebuild:
			return maxf(_abs_arven(game_state, player, player_index, phase), 260.0)
		if _first_gardevoir_emergency(player):
			return maxf(_abs_arven(game_state, player, player_index, phase), 260.0)
		if _must_force_first_gardevoir(player):
			return maxf(_abs_arven(game_state, player, player_index, phase), 260.0)
		if transition_shell and ready_attackers >= 1:
			return -120.0
		return _abs_arven(game_state, player, player_index, phase)


	if name == EARTHEN_VESSEL:
		if post_tm_refill_window:
			if discard_p < 2:
				return 320.0
			return 180.0
		if fuel_gate:
			return 260.0
		if _first_gardevoir_emergency(player):
			return -120.0
		if _must_force_first_gardevoir(player):
			return -80.0
		if _tm_setup_priority_live(player, phase) and not _hand_has_any_energy(player):
			return 340.0
		if _hand_has_energy_type(player, "P"):
			return 350.0 if phase != "late" else 120.0
		if shell_lock and _count_primary_shell_bodies(player) < 2:
			return -40.0
		if transition_shell and ready_attackers >= 1:
			return -70.0
		if _hand_has_energy_type(player, "P"):
			return 350.0 if phase != "late" else 120.0
		return 200.0 if phase != "late" else 80.0


	if name == NIGHT_STRETCHER:
		if attacker_closed_loop:
			return 520.0
		if first_attacker_body_rebuild and not _has_attacker_in_discard(game_state, player_index):
			return -100.0
		if attacker_recovery_mode:
			return 360.0
		return _abs_night_stretcher(game_state, player, player_index, phase)

	if name == RESCUE_STRETCHER:
		if attacker_closed_loop:
			return 520.0
		if first_attacker_body_rebuild and not _has_attacker_in_discard(game_state, player_index):
			return -100.0
		if attacker_recovery_mode:
			return 360.0
		return _abs_night_stretcher(game_state, player, player_index, phase)

	if name == SUPER_ROD:
		if _first_gardevoir_emergency(player):
			if _discard_has_card(game_state, player_index, GARDEVOIR_EX):
				return 40.0
			return -160.0
		if first_attacker_body_rebuild and not _has_attacker_in_discard(game_state, player_index):
			return -60.0
		if attacker_recovery_mode:
			return 180.0
		var discard_value: int = 0
		if _has_core_in_discard(game_state, player_index):
			discard_value += 80
		if _has_attacker_in_discard(game_state, player_index):
			discard_value += 60
		if discard_p >= 3:
			discard_value += 40
		if shell_lock and discard_value <= 80:
			return -40.0
		if transition_shell and ready_attackers >= 1 and discard_value <= 120:
			return -80.0
		return float(maxi(60, discard_value))

	if name == HISUIAN_HEAVY_BALL:
		var heavy_targets: Array = action.get("targets", [])
		if post_stage2_handoff_live and not attacker_recovery_mode:
			return -180.0
		if _count_pokemon_on_field(player, RALTS) < 2:
			for target_variant in heavy_targets:
				if target_variant is Dictionary:
					var chosen_prize_basic: Array = target_variant.get("chosen_prize_basic", [])
					for prize_variant in chosen_prize_basic:
						var prize_card: CardInstance = prize_variant as CardInstance
						if prize_card != null and prize_card.card_data != null and str(prize_card.card_data.name) == RALTS:
							return 260.0
		if attacker_recovery_mode:
			return 10.0
		if charizard_rebuild_lock:
			return -100.0
		if _count_pokemon_on_field(player, RALTS) < 2 and not _has_shell_search(player):
			return 220.0
		if _first_gardevoir_emergency(player):
			return -140.0
		if transition_shell and ready_attackers >= 1:
			return -60.0
		return 20.0


	if name == COUNTER_CATCHER:
		if _must_force_first_gardevoir(player):
			return -120.0
		if not _has_immediate_attack_window(game_state, player, player_index):
			return -40.0
		if _can_ko_bench_target(game_state, player, player_index):
			return 700.0
		return 120.0

	if name == BOSSS_ORDERS:
		if _must_force_first_gardevoir(player):
			return -120.0
		if not _has_immediate_attack_window(game_state, player, player_index):
			return -40.0
		if _can_ko_bench_target(game_state, player, player_index):
			return 800.0
		if phase == "late":
			return 120.0
		return 40.0


	if name == IONO:
		if post_tm_refill_window:
			if hand_size <= 2:
				return 320.0
			if hand_size <= 4:
				return 260.0
			return 120.0
		if _must_force_first_gardevoir(player):
			if hand_size <= 1 and not _has_shell_search(player):
				return 80.0
			return -40.0
		if first_attacker_body_rebuild and hand_size >= 3:
			return -20.0
		if handoff_window and not attacker_recovery_mode and hand_size >= 3:
			return -40.0
		if attacker_recovery_mode and hand_size >= 3:
			return -20.0
		return _abs_iono(game_state, player, player_index, phase, hand_size)

	if name == ARTAZON:
		if bench_full or _count_searchable_basic_targets(player) == 0:
			return 0.0
		if post_stage2_handoff_live and not first_attacker_body_rebuild and not attacker_recovery_mode:
			return -180.0
		if first_attacker_body_rebuild:
			var preferred_transition_attacker: String = _preferred_transition_attacker_name(game_state, player_index)
			if _count_pokemon_on_field(player, preferred_transition_attacker) == 0:
				return 320.0
			return 160.0
		if handoff_window and not attacker_recovery_mode:
			return -160.0
		if _first_gardevoir_emergency(player):
			return -140.0
		if charizard_rebuild_lock:
			return -140.0
		if attacker_recovery_mode:
			return 40.0
		if shell_lock and _count_primary_shell_bodies(player) >= 2:
			return -20.0
		if shell_lock and _count_primary_shell_bodies(player) < 2:
			var other_shell_search: bool = _hand_has_card(player, ULTRA_BALL) \
				or _hand_has_card(player, NEST_BALL) \
				or _hand_has_card(player, BUDDY_BUDDY_POFFIN) \
				or _hand_has_card(player, ARVEN) \
				or _hand_has_card(player, SECRET_BOX)
			return 40.0 if other_shell_search else 220.0
		if transition_shell and ready_attackers >= 1:
			return -120.0
		return 120.0

	if name == PROF_TURO:
		if _must_force_first_gardevoir(player) or first_attacker_body_rebuild:
			return -120.0
		return _abs_prof_turo(game_state, player, player_index, phase)

	if name == RARE_CANDY or name == "Rare Candy":
		if has_ralts and _hand_has_card(player, GARDEVOIR_EX):
			return 500.0
		return 50.0

	return 50.0


func _abs_retreat(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int) -> float:
	var active: PokemonSlot = player.active_pokemon
	if active == null:
		return 0.0
	var active_name: String = active.get_pokemon_name()
	var bench_target: PokemonSlot = action.get("bench_target")
	if bench_target == null:
		return 0.0
	var bench_name: String = bench_target.get_pokemon_name()
	var bench_is_ready_attacker: bool = _is_ready_attacker(bench_target)
	var phase: String = _detect_game_phase(int(game_state.turn_number), player)
	if _active_has_tm_evolution(player):
		return -300.0
	if active_name in ATTACKER_NAMES or active_name == SCREAM_TAIL:
		var pred: Dictionary = predict_attacker_damage(active)
		if int(pred.get("damage", 0)) > 0 and bool(pred.get("can_attack", false)):
			return -200.0
	var is_non_attacker: bool = active_name not in ATTACKER_NAMES and active_name != SCREAM_TAIL
	if is_non_attacker and bench_is_ready_attacker:
		return 350.0
	if is_non_attacker:
		return 0.0
	if active.get_remaining_hp() < 40:
		if bench_is_ready_attacker:
			return 200.0
		return -100.0
	return 0.0

func _abs_attack(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var damage: int = int(action.get("projected_damage", 0))
	var player: PlayerState = game_state.players[player_index]
	if _should_delay_attacker_investment_during_shell_lock(player) and player.active_pokemon != null:
		var opening_name: String = player.active_pokemon.get_pokemon_name()
		if opening_name in ATTACKER_NAMES or opening_name == SCREAM_TAIL:
			var opponent_idx: int = 1 - player_index
			var opp_def: PokemonSlot = null
			if opponent_idx >= 0 and opponent_idx < game_state.players.size():
				opp_def = game_state.players[opponent_idx].active_pokemon
			if opp_def == null or damage < opp_def.get_remaining_hp():
				return -180.0
	if damage <= 0 and player.active_pokemon != null:
		var pred: Dictionary = predict_attacker_damage(player.active_pokemon)
		damage = int(pred.get("damage", 0))
	var opponent_index: int = 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return 100.0 if damage > 0 else 0.0
	var defender: PokemonSlot = game_state.players[opponent_index].active_pokemon
	if defender == null:
		return 100.0 if damage > 0 else 0.0
	var active_name: String = player.active_pokemon.get_pokemon_name() if player.active_pokemon != null else ""
	if active_name == SCREAM_TAIL and damage > 0:
		var best_ko_value: float = 0.0
		for opp_slot: PokemonSlot in _get_all_slots(game_state.players[opponent_index]):
			if opp_slot.get_remaining_hp() <= damage:
				var ko_val: float = 800.0
				var opp_cd: CardData = opp_slot.get_card_data()
				if opp_cd != null and (opp_cd.mechanic == "ex" or opp_cd.mechanic == "V"):
					ko_val = 1000.0
				if ko_val > best_ko_value:
					best_ko_value = ko_val
		if best_ko_value > 0.0:
			return best_ko_value
		return 300.0 + float(damage)
	if damage >= defender.get_remaining_hp():
		var ko_score: float = 800.0
		var defender_data: CardData = defender.get_card_data()
		if defender_data != null and (defender_data.mechanic == "ex" or defender_data.mechanic == "V"):
			ko_score = 1000.0
		return ko_score
	if damage > 0:
		return 300.0 + float(damage)
	return 0.0


func _abs_granted_attack(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	var ga_data: Dictionary = action.get("granted_attack_data", {})
	var attack_name: String = str(ga_data.get("name", ""))
	var damage: int = int(ga_data.get("damage", 0))
	if attack_name in ["进化", "Evolution", "TM Evolution"]:
		var active_name: String = player.active_pokemon.get_pokemon_name() if player.active_pokemon != null else ""
		if active_name == KIRLIA and (_has_transition_shell(player) or _count_pokemon_on_field(player, GARDEVOIR_EX) >= 1):
			return -240.0
		if _tm_support_carrier_cools_off(player, phase):
			return -220.0
		if _has_online_shell(player):
			return -180.0
		if _must_force_first_gardevoir(player):
			return 10.0
		if _shell_lock_active(player) and _count_evolvable_bench_targets(player) >= 2:
			return 900.0
		if _has_evolvable_bench_targets(player):
			return 600.0
		return 50.0
	if damage > 0:
		var opponent_index: int = 1 - player_index
		if opponent_index >= 0 and opponent_index < game_state.players.size():
			var defender: PokemonSlot = game_state.players[opponent_index].active_pokemon
			if defender != null and damage >= defender.get_remaining_hp():
				return 800.0
		return 300.0
	return 100.0



func _abs_arven(game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	var deck_items: Array[String] = _get_deck_card_names_by_type(player, "Item")
	var deck_tools: Array[String] = _get_deck_card_names_by_type(player, "Tool")
	if deck_items.is_empty() and deck_tools.is_empty():
		return 50.0

	var best_item_value: float = _eval_best_search_item(game_state, player, player_index, phase, deck_items)
	var best_tool_value: float = _eval_best_search_tool(game_state, player, player_index, phase, deck_tools)

	var total: float = best_item_value + best_tool_value
	return maxf(total, 150.0) if phase != "late" else maxf(total * 0.7, 100.0)


func _eval_best_search_item(game_state: GameState, player: PlayerState, player_index: int, phase: String, deck_items: Array[String]) -> float:
	var best: float = 50.0
	var need_gardevoir: bool = _count_pokemon_on_field(player, GARDEVOIR_EX) == 0
	var has_kirlia_on_field: bool = _count_pokemon_on_field(player, KIRLIA) >= 1
	var has_ralts_on_field: bool = _count_pokemon_on_field(player, RALTS) >= 1
	var bench_full: bool = player.bench.size() >= 5
	var post_tm_refill_window: bool = _post_tm_refill_window(game_state, player, player_index)
	var fuel_gate: bool = _first_gardevoir_fuel_gate(game_state, player, player_index)

	if RARE_CANDY in deck_items:
		if need_gardevoir and has_kirlia_on_field:
			var kirlia_count: int = _count_pokemon_on_field(player, KIRLIA)
			if kirlia_count >= 2:
				best = maxf(best, 350.0)
			else:
				best = maxf(best, 280.0)
		elif need_gardevoir and has_ralts_on_field:
			best = maxf(best, 220.0)
		elif need_gardevoir:
			best = maxf(best, 180.0)
		else:
			best = maxf(best, 100.0)

	if SECRET_BOX in deck_items:
		if phase == "early":
			best = maxf(best, 200.0)
		else:
			best = maxf(best, 120.0)

	if ULTRA_BALL in deck_items:
		if phase == "early":
			best = maxf(best, 180.0)
		else:
			best = maxf(best, 100.0)

	if NEST_BALL in deck_items and not bench_full:
		best = maxf(best, 130.0 if phase == "early" else 80.0)

	if EARTHEN_VESSEL in deck_items:
		if post_tm_refill_window:
			best = maxf(best, 340.0)
		elif fuel_gate:
			best = maxf(best, 280.0)
		best = maxf(best, 150.0 if phase != "late" else 60.0)

	if NIGHT_STRETCHER in deck_items or RESCUE_STRETCHER in deck_items:
		if _has_attacker_in_discard(game_state, player_index) or _has_core_in_discard(game_state, player_index):
			best = maxf(best, 160.0)

	if _first_gardevoir_emergency(player):
		if ULTRA_BALL in deck_items:
			best = maxf(best, 460.0)
		if (NIGHT_STRETCHER in deck_items or RESCUE_STRETCHER in deck_items) and _discard_has_card(game_state, player_index, GARDEVOIR_EX):
			best = maxf(best, 520.0)
		if SECRET_BOX in deck_items:
			best = maxf(best, 220.0)
	return best


func _eval_best_search_tool(game_state: GameState, player: PlayerState, player_index: int, phase: String, deck_tools: Array[String]) -> float:
	var best: float = 30.0

	if BRAVERY_CHARM in deck_tools:
		var active_name: String = player.active_pokemon.get_pokemon_name() if player.active_pokemon != null else ""
		if active_name in CONTROL_NAMES or active_name == DRIFLOON:
			best = maxf(best, 200.0)
		else:
			best = maxf(best, 100.0)

	return best


func _get_deck_card_names_by_type(player: PlayerState, card_type: String) -> Array[String]:
	var names: Array[String] = []
	for card: CardInstance in player.deck:
		if card != null and card.card_data != null and str(card.card_data.card_type) == card_type:
			var cname: String = str(card.card_data.name)
			if cname not in names:
				names.append(cname)
	return names



func pick_search_item(items: Array, game_state: GameState, player_index: int) -> Variant:
	if items.is_empty():
		return null
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return items[0]

	var player: PlayerState = game_state.players[player_index]
	var phase: String = _detect_game_phase(int(game_state.turn_number), player)
	var bench_full: bool = player.bench.size() >= 5

	var priority_list: Array[String] = []
	if _count_pokemon_on_field(player, GARDEVOIR_EX) == 0 and _count_pokemon_on_field(player, KIRLIA) >= 1 and _discard_has_card(game_state, player_index, GARDEVOIR_EX):
		priority_list.append(NIGHT_STRETCHER)
		priority_list.append(RESCUE_STRETCHER)
	if _first_gardevoir_emergency(player):
		priority_list.append(ULTRA_BALL)
		priority_list.append(NIGHT_STRETCHER)
		priority_list.append(RESCUE_STRETCHER)
		priority_list.append(SECRET_BOX)
	elif _must_force_first_gardevoir(player):
		priority_list.append(ULTRA_BALL)
		priority_list.append(SECRET_BOX)
		priority_list.append(NIGHT_STRETCHER)
		priority_list.append(RESCUE_STRETCHER)
		if _count_primary_shell_bodies(player) < 2 and not bench_full:
			priority_list.append(BUDDY_BUDDY_POFFIN)
		elif not _hand_has_any_energy(player):
			priority_list.append(EARTHEN_VESSEL)
	elif _shell_lock_active(player):
		if _count_pokemon_on_field(player, RALTS) < 2 and not bench_full:
			priority_list.append(BUDDY_BUDDY_POFFIN)
		elif not _hand_has_any_energy(player) and (_tm_still_accessible(player) or _count_pokemon_on_field(player, KIRLIA) >= 1):
			priority_list.append(EARTHEN_VESSEL)
		priority_list.append(ULTRA_BALL)
		if not bench_full:
			priority_list.append(NEST_BALL)
		if EARTHEN_VESSEL not in priority_list and not _hand_has_any_energy(player):
			priority_list.append(EARTHEN_VESSEL)
	else:
		priority_list.append(ULTRA_BALL)
		if phase == "early" and not bench_full:
			priority_list.append(BUDDY_BUDDY_POFFIN)
		priority_list.append(EARTHEN_VESSEL)
		if not bench_full:
			priority_list.append(NEST_BALL)
	priority_list.append(NIGHT_STRETCHER)
	priority_list.append(RESCUE_STRETCHER)
	priority_list.append(SECRET_BOX)

	for preferred: String in priority_list:
		for item: Variant in items:
			if item is CardInstance and (item as CardInstance).card_data != null:
				if str((item as CardInstance).card_data.name) == preferred:
					return item
	return items[0]


func pick_search_tool(items: Array, game_state: GameState, player_index: int) -> Variant:
	if items.is_empty():
		return null
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return items[0]

	var player: PlayerState = game_state.players[player_index]
	var phase: String = _detect_game_phase(int(game_state.turn_number), player)
	var priority_list: Array[String] = []
	if _shell_lock_active(player) and _count_pokemon_on_field(player, RALTS) < 2 and _count_pokemon_on_field(player, KIRLIA) == 0:
		priority_list.append(TM_EVOLUTION)
	elif _shell_lock_active(player) and _count_evolvable_bench_targets(player) >= 2:
		priority_list.append(TM_EVOLUTION)
	priority_list.append(BRAVERY_CHARM)
	if TM_EVOLUTION not in priority_list and not _tm_support_carrier_cools_off(player, phase) and not _must_force_first_gardevoir(player):
		priority_list.append(TM_EVOLUTION)

	for preferred: String in priority_list:
		for item: Variant in items:
			if item is CardInstance and (item as CardInstance).card_data != null:
				if str((item as CardInstance).card_data.name) == preferred:
					return item
	return items[0]



func _abs_ultra_ball(game_state: GameState, player: PlayerState, player_index: int, phase: String, hand_size: int) -> float:
	var need_gardevoir: bool = _count_pokemon_on_field(player, GARDEVOIR_EX) == 0
	var has_kirlia: bool = _count_pokemon_on_field(player, KIRLIA) >= 1
	var has_ralts: bool = _count_pokemon_on_field(player, RALTS) >= 1
	var discard_penalty: float = 0.0
	if hand_size <= 3:
		discard_penalty = 80.0
	elif hand_size <= 5:
		discard_penalty = 30.0
	var search_value: float = 100.0
	if need_gardevoir and has_kirlia:
		var kirlia_count: int = _count_pokemon_on_field(player, KIRLIA)
		if kirlia_count >= 2:
			search_value = 450.0
		else:
			search_value = 350.0
	elif need_gardevoir and has_ralts:
		search_value = 280.0
	elif need_gardevoir:
		search_value = 250.0
	elif _count_pokemon_on_field(player, KIRLIA) < 2:
		search_value = 200.0
	var psychic_in_hand: int = _count_energy_in_hand(player, "P")
	if psychic_in_hand >= 2:
		discard_penalty -= 40.0
	elif psychic_in_hand >= 1:
		discard_penalty -= 20.0
	return maxf(search_value - discard_penalty, 50.0)


func _abs_secret_box(game_state: GameState, player: PlayerState, player_index: int, phase: String, hand_size: int) -> float:
	if hand_size < 4:
		return 0.0
	var psychic_in_hand: int = _count_energy_in_hand(player, "P")
	var base: float = 200.0
	if phase == "early":
		base = 300.0
	var fuel_bonus: float = float(mini(psychic_in_hand, 3)) * 20.0
	var deck_items: Array[String] = _get_deck_card_names_by_type(player, "Item")
	var deck_tools: Array[String] = _get_deck_card_names_by_type(player, "Tool")
	var deck_supporters: Array[String] = _get_deck_card_names_by_type(player, "Supporter")
	var types_available: int = 0
	if not deck_items.is_empty():
		types_available += 1
	if not deck_tools.is_empty():
		types_available += 1
	if not deck_supporters.is_empty():
		types_available += 1
	base += float(types_available) * 20.0
	return base + fuel_bonus


func _abs_night_stretcher(game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	var discard: Array[CardInstance] = game_state.players[player_index].discard_pile
	var has_gardevoir_in_discard: bool = false
	var has_kirlia_in_discard: bool = false
	var has_attacker: bool = false
	var has_ralts: bool = false
	for card: CardInstance in discard:
		if card == null or card.card_data == null:
			continue
		var cname: String = str(card.card_data.name)
		if cname == GARDEVOIR_EX:
			has_gardevoir_in_discard = true
		elif cname == KIRLIA:
			has_kirlia_in_discard = true
		elif cname in ATTACKER_NAMES or cname == SCREAM_TAIL:
			has_attacker = true
		elif cname == RALTS:
			has_ralts = true
	var shell_lock: bool = _shell_lock_active(player)
	var shell_online: bool = _has_online_shell(player)
	var ready_attackers: int = _count_ready_attackers(player)
	var attacker_bodies: int = _count_attackers_on_field(player)
	var closed_loop_rebuild: bool = _attacker_rebuild_closed_loop_live(game_state, player, player_index)
	if closed_loop_rebuild and has_attacker:
		return 520.0
	if has_gardevoir_in_discard and _count_pokemon_on_field(player, GARDEVOIR_EX) == 0:
		if _count_pokemon_on_field(player, KIRLIA) >= 1:
			return 460.0
		return 320.0
	if has_kirlia_in_discard and _count_pokemon_on_field(player, RALTS) >= 1 and _count_pokemon_on_field(player, KIRLIA) == 0:
		return 320.0
	if has_attacker and shell_online and attacker_bodies == 0:
		return 250.0
	if has_ralts and not player.bench.size() >= 5:
		return 180.0 if _count_primary_shell_bodies(player) < 2 else 60.0
	if shell_lock:
		return -40.0
	if shell_online and ready_attackers >= 1:
		return 20.0
	if attacker_bodies >= 1 and ready_attackers == 0:
		return 20.0
	return 20.0


func _abs_iono(game_state: GameState, player: PlayerState, player_index: int, phase: String, hand_size: int) -> float:
	var my_prizes: int = player.prizes.size()
	var opp_index: int = 1 - player_index
	var opp_prizes: int = game_state.players[opp_index].prizes.size() if opp_index >= 0 and opp_index < game_state.players.size() else 6
	var shell_lock: bool = _shell_lock_active(player)
	var shell_online: bool = _has_established_stage2_shell(player)
	var ready_attackers: int = _count_ready_attackers(player)
	var stable_hand: bool = hand_size >= 3
	var strong_comeback_need: bool = my_prizes >= opp_prizes + 2
	if shell_lock and hand_size >= 4:
		return 0.0
	if _has_deck_out_pressure(player) and ready_attackers >= 1:
		return 0.0
	if shell_online and ready_attackers >= 1:
		if opp_prizes <= 2 and my_prizes > opp_prizes:
			return 120.0
		if stable_hand:
			return -40.0
		if not strong_comeback_need:
			return 0.0
	var my_gain: float = float(my_prizes) - float(hand_size) * 0.5
	var opp_loss: float = 0.0
	if opp_prizes <= 2:
		opp_loss = 80.0
	elif opp_prizes <= 3:
		opp_loss = 40.0

	var base: float = 100.0 + my_gain * 15.0 + opp_loss
	if phase == "early" and hand_size >= 4:
		base -= 80.0
	if hand_size <= 2:
		base += 100.0
	return maxf(base, 0.0)


func _abs_prof_turo(game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	if _has_transition_shell(player) and _count_ready_attackers(player) >= 1:
		return 20.0
	var best: float = 20.0
	for slot: PokemonSlot in _get_all_slots(player):
		if not _slot_is_live(slot):
			continue
		var cd: CardData = slot.get_card_data()
		if cd == null:
			continue
		var remaining_hp: int = slot.get_remaining_hp()
		if cd.mechanic == "ex" and remaining_hp <= 60:
			best = maxf(best, 500.0)
		elif cd.mechanic == "ex" and remaining_hp <= 100:
			best = maxf(best, 300.0)
	return best


func _count_energy_in_hand(player: PlayerState, etype: String) -> int:
	var count: int = 0
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.is_energy() and str(card.card_data.energy_provides) == etype:
			count += 1
	return count


func _detect_game_phase(turn: int, player: PlayerState) -> String:
	if turn <= 2:
		return "early"
	if _count_pokemon_on_field(player, GARDEVOIR_EX) >= 1 and turn >= 5:
		return "late"
	if turn <= 4:
		return "mid"
	return "late"


func _estimate_heuristic_base(kind: String) -> float:
	match kind:
		"attack": return 500.0
		"granted_attack": return 500.0
		"attach_energy": return 220.0
		"play_basic_to_bench": return 180.0
		"evolve": return 170.0
		"use_ability": return 160.0
		"play_trainer": return 110.0
		"retreat": return 90.0
		"end_turn": return 0.0
	return 10.0



func get_mcts_config() -> Dictionary:
	return {
		"branch_factor": 3,
		"max_actions_per_turn": 8,
		"rollouts_per_sequence": 0,
		"time_budget_ms": 3000,
	}



func evaluate_board(game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var opponent_index: int = 1 - player_index
	var opponent: PlayerState = game_state.players[opponent_index] if opponent_index < game_state.players.size() else null
	var score: float = 0.0

	if opponent != null:
		score += float(opponent.prizes.size() - player.prizes.size()) * 400.0

	score += float(_count_pokemon_on_field(player, GARDEVOIR_EX)) * 500.0
	score += float(_count_pokemon_on_field(player, KIRLIA)) * 120.0

	for slot: PokemonSlot in _get_all_slots(player):
		var name: String = slot.get_pokemon_name()
		if name in ATTACKER_NAMES or name == SCREAM_TAIL:
			var pred: Dictionary = predict_attacker_damage(slot)
			score += float(int(pred.get("damage", 0))) * 2.0
			if bool(pred.get("can_attack", false)):
				score += 250.0

	score += float(_count_psychic_energy_in_discard(game_state, player_index)) * 30.0

	score += float(player.bench.size()) * 25.0

	for slot: PokemonSlot in _get_all_slots(player):
		if slot.get_pokemon_name() == MUNKIDORI and _slot_has_energy_type(slot, "D"):
			score += 150.0

	return score




func score_assignment_target(slot: PokemonSlot) -> int:
	if slot == null or slot.get_top_card() == null:
		return 0
	if not _slot_is_live(slot):
		return -1000
	var name: String = slot.get_pokemon_name()
	if name == SCREAM_TAIL or name == DRIFBLIM or name == DRIFLOON:
		if slot.get_remaining_hp() <= 20:
			return 0
		var base: int = 170 if (name == DRIFBLIM or name == DRIFLOON) else 150
		return base + slot.get_remaining_hp() / 10
	return 0


func pick_embrace_target(target_slots: Array, game_state: GameState = null, player_index: int = -1) -> Variant:
	if target_slots.is_empty():
		return null

	var active_slot: PokemonSlot = null
	var player: PlayerState = null
	var defender: PokemonSlot = null
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		player = game_state.players[player_index]
		active_slot = player.active_pokemon
		var opp_idx: int = 1 - player_index
		if opp_idx >= 0 and opp_idx < game_state.players.size():
			defender = game_state.players[opp_idx].active_pokemon

	var best: Variant = null
	var best_score: float = -1.0

	var active_needs_retreat: bool = false
	if active_slot != null:
		var aname: String = active_slot.get_pokemon_name()
		if aname not in ATTACKER_NAMES and aname != SCREAM_TAIL:
			if _get_retreat_energy_gap(active_slot) > 0 and active_slot.get_remaining_hp() > 20:
				if player != null:
					for bench_slot: PokemonSlot in player.bench:
						if _is_ready_attacker(bench_slot):
							active_needs_retreat = true
							break

	for slot_variant: Variant in target_slots:
		if not (slot_variant is PokemonSlot):
			continue
		var slot: PokemonSlot = slot_variant as PokemonSlot
		if not _slot_is_live(slot):
			continue
		var name: String = slot.get_pokemon_name()
		var score: float = 0.0

		if slot.get_remaining_hp() <= 20:
			continue
		if name in ATTACKER_NAMES or name == SCREAM_TAIL:
			var pred: Dictionary = predict_attacker_damage(slot, 0)
			var pred_after: Dictionary = predict_attacker_damage(slot, 1)
			var can_now: bool = bool(pred.get("can_attack", false))
			var now_dmg: int = int(pred.get("damage", 0))
			var after_dmg: int = int(pred_after.get("damage", 0))
			var can_after: bool = bool(pred_after.get("can_attack", false))

			if not can_now and can_after:
				score = 500.0
			elif not can_now:
				score = 400.0
			elif can_now and defender != null and now_dmg < defender.get_remaining_hp() and after_dmg >= defender.get_remaining_hp():
				score = 600.0
			elif can_now and defender != null and now_dmg >= defender.get_remaining_hp():
				score = 10.0
			else:
				score = 50.0 + float(after_dmg - now_dmg)

			if player != null and _has_established_stage2_shell(player) and _count_ready_attackers(player) == 0:
				var preferred_transition_attacker: String = _preferred_transition_attacker_name(game_state, player_index)
				if name == preferred_transition_attacker:
					score += 90.0
				elif name in ATTACKER_NAMES or name == SCREAM_TAIL:
					score -= 35.0

			score = maxf(score, 450.0)
		elif slot == active_slot and active_needs_retreat:
			score = 420.0
		elif player != null and _has_established_stage2_shell(player):
			score = -220.0
		else:
			score = -120.0

		if score > best_score:
			best_score = score
			best = slot_variant

	if best != null:
		return best
	var fallback_best: Variant = null
	var fallback_score: int = -1
	for slot_variant: Variant in target_slots:
		if not (slot_variant is PokemonSlot):
			continue
		var slot: PokemonSlot = slot_variant as PokemonSlot
		if not _slot_is_live(slot):
			continue
		var s: int = score_assignment_target(slot)
		if s > fallback_score:
			fallback_score = s
			fallback_best = slot_variant
	return fallback_best



func predict_attacker_damage(slot: PokemonSlot, extra_embrace_count: int = 0) -> Dictionary:
	if slot == null or slot.get_top_card() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var name: String = slot.get_pokemon_name()
	var current_dc: int = slot.damage_counters + extra_embrace_count * 20
	var counter_count: int = current_dc / 10

	if name == DRIFLOON or name == DRIFBLIM:
		var damage: int = counter_count * 30
		var energy_gap: int = _get_attack_energy_gap(slot) - extra_embrace_count
		return {
			"damage": damage,
			"can_attack": energy_gap <= 0,
			"description": "damage=%d counters=%d balloon" % [damage, counter_count],
		}

	if name == SCREAM_TAIL:
		var damage: int = counter_count * 20
		var energy_gap: int = _get_attack_energy_gap(slot) - extra_embrace_count
		return {
			"damage": damage,
			"can_attack": energy_gap <= 0,
			"description": "damage=%d counters=%d scream_tail" % [damage, counter_count],
		}

	return {"damage": 0, "can_attack": false, "description": ""}



func score_action(action: Dictionary, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state")
	var player_index: int = int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var abs_score: float = score_action_absolute(action, game_state, player_index)
	var base_estimate: float = _estimate_heuristic_base(str(action.get("kind", "")))
	return abs_score - base_estimate



func plan_opening_setup(player: PlayerState) -> Dictionary:
	var basics: Array[Dictionary] = []
	for i: int in player.hand.size():
		var card: CardInstance = player.hand[i]
		if card == null or card.card_data == null:
			continue
		if card.card_data.card_type != "Pokemon" or str(card.card_data.stage) != "Basic":
			continue
		basics.append({"index": i, "name": str(card.card_data.name), "priority": _get_setup_priority(str(card.card_data.name))})
	if basics.is_empty():
		return {"active_hand_index": -1, "bench_hand_indices": []}
	basics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["priority"]) > int(b["priority"])
	)
	var ralts_count: int = 0
	for b in basics:
		if str(b["name"]) == RALTS:
			ralts_count += 1
	var active_index: int = -1
	var bridge_active_preference: Array[String] = [FLUTTER_MANE, KLEFKI]
	var fallback_active_preference: Array[String] = [FLUTTER_MANE, KLEFKI, DRIFLOON, SCREAM_TAIL, MANAPHY, MUNKIDORI, RADIANT_GRENINJA]
	if ralts_count >= 2:
		for preferred in bridge_active_preference:
			if active_index != -1:
				break
			for b in basics:
				if str(b["name"]) == preferred:
					active_index = int(b["index"])
					break
	elif ralts_count == 1:
		for preferred in [FLUTTER_MANE, KLEFKI, DRIFLOON, SCREAM_TAIL]:
			if active_index != -1:
				break
			for b in basics:
				if str(b["name"]) == preferred:
					active_index = int(b["index"])
					break
	if active_index == -1 and ralts_count >= 1:
		for b in basics:
			if str(b["name"]) == RALTS:
				active_index = int(b["index"])
				break
	for preferred in fallback_active_preference:
		if active_index != -1:
			break
		for b in basics:
			if str(b["name"]) == preferred:
				active_index = int(b["index"])
				break
	if active_index == -1:
		active_index = int(basics[0]["index"])
	var bench_indices: Array[int] = []
	var non_essentials: Array[int] = []
	for b in basics:
		if int(b["index"]) == active_index:
			continue
		var bname: String = str(b["name"])
		if bname == RALTS and bench_indices.size() < 2:
			bench_indices.append(int(b["index"]))
		else:
			non_essentials.append(int(b["index"]))
	for idx in non_essentials:
		if bench_indices.size() >= 2:
			break
		bench_indices.append(idx)
	return {"active_hand_index": active_index, "bench_hand_indices": bench_indices}


func _get_setup_priority(pokemon_name: String) -> int:
	match pokemon_name:
		RALTS: return 110
		FLUTTER_MANE: return 95
		KLEFKI: return 90
		DRIFLOON: return 80
		SCREAM_TAIL: return 70
		MUNKIDORI: return 60
		MANAPHY: return 40
		RADIANT_GRENINJA: return 35
		_: return 30


func _opening_tm_bridge_live(player: PlayerState) -> bool:
	if player == null:
		return false
	var has_tm_line: bool = _hand_has_card(player, TM_EVOLUTION) or _hand_has_card(player, ARVEN)
	if not has_tm_line:
		return false
	if _hand_has_energy_type(player, "P") or _hand_has_energy_type(player, "D"):
		return true
	if _hand_has_card(player, EARTHEN_VESSEL):
		return true
	return false



func get_discard_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	var card_type: String = str(card.card_data.card_type)
	var cname: String = str(card.card_data.name)
	if card_type == "Basic Energy" and str(card.card_data.energy_provides) == "P":
		return 250
	if cname in CONTROL_NAMES:
		return 200
	if card_type == "Basic Energy" and str(card.card_data.energy_provides) == "D":
		return 150
	if card_type == "Basic Energy":
		return 120
	if card_type == "Item" or card_type == "Tool":
		if cname in [ULTRA_BALL, NEST_BALL, BUDDY_BUDDY_POFFIN, SECRET_BOX]:
			return 40
		return 100
	if cname in [RALTS, DRIFLOON, FLUTTER_MANE, RADIANT_GRENINJA]:
		return 80
	if cname in [GARDEVOIR_EX, KIRLIA]:
		return 5
	if card_type == "Supporter" or card_type == "Stadium":
		if _get_supporter_search_value(cname) > 0:
			return 10
		return 20
	return 50

func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return get_discard_priority(card)
	var player: PlayerState = game_state.players[player_index]
	var card_type: String = str(card.card_data.card_type)
	var cname: String = str(card.card_data.name)
	var bench_full: bool = player.bench.size() >= 5
	var hand_size: int = player.hand.size()
	if _shell_lock_active(player):
		if cname == TM_EVOLUTION:
			return 20
		if cname == ARVEN:
			return 30
		if cname == ULTRA_BALL:
			return 60
		if cname == NIGHT_STRETCHER or cname == RESCUE_STRETCHER:
			return 100
	if card_type == "Basic Energy" and str(card.card_data.energy_provides) == "P":
		return 250
	if cname in CONTROL_NAMES and _count_pokemon_on_field(player, cname) >= 1:
		return 220
	if bench_full and (cname == NEST_BALL or cname == BUDDY_BUDDY_POFFIN):
		return 180
	if card_type == "Basic Energy" and str(card.card_data.energy_provides) == "D":
		return 150
	if card_type == "Basic Energy":
		return 120
	if cname == TM_EVOLUTION and not _has_evolvable_bench_targets(player):
		return 110
	if card_type == "Item" or card_type == "Tool":
		if cname in [ULTRA_BALL, NEST_BALL, BUDDY_BUDDY_POFFIN, SECRET_BOX]:
			return 40
		return 100
	if cname in CONTROL_NAMES:
		return 90
	if cname == RALTS and _count_pokemon_on_field(player, RALTS) >= 3:
		return 85
	if cname in [RALTS, DRIFLOON, FLUTTER_MANE, RADIANT_GRENINJA, MANAPHY]:
		if bench_full:
			return 80
		return 50
	if card_type == "Supporter" or card_type == "Stadium":
		var search_value: int = _get_supporter_search_value(cname)
		if search_value > 0:
			var hand_penalty: int = maxi(0, 6 - hand_size) * 3
			return maxi(5, 15 - search_value - hand_penalty)
		return 20
	if cname in [GARDEVOIR_EX, KIRLIA]:
		return 5
	if cname == TM_EVOLUTION:
		return 25
	return 50

func _get_supporter_search_value(cname: String) -> int:
	if cname == ARVEN:
		return 15
	if cname == IONO:
		return 12
	if cname == ARTAZON:
		return 10
	if cname == PROF_TURO:
		return 8
	if cname == BOSSS_ORDERS:
		return 6
	if cname == COUNTER_CATCHER:
		return 4
	return 0


func get_search_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	var name: String = str(card.card_data.name)
	for i: int in SEARCH_PRIORITY_NAMES.size():
		if name == SEARCH_PRIORITY_NAMES[i]:
			return 100 - i * 10
	return 10

func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id: String = str(step.get("id", ""))
	var game_state: GameState = context.get("game_state", null)
	var player_index: int = int(context.get("player_index", -1))
	var all_items: Array = context.get("all_items", [])
	if item is CardInstance:
		var card: CardInstance = item as CardInstance
		if card.card_data == null:
			return 0.0
		if step_id == "night_stretcher_choice":
			return _score_night_stretcher_choice_target(card, game_state, player_index)
		if step_id == "search_item":
			return _score_search_item_target(card, all_items, game_state, player_index)
		if step_id == "search_tool":
			return _score_search_tool_target(card, all_items, game_state, player_index)
		if step_id in ["search_pokemon", "search_cards", "basic_pokemon", "buddy_poffin_pokemon", "bench_pokemon"]:
			if game_state != null and player_index >= 0:
				return _score_search_pokemon_target(card, game_state, player_index)
			return float(get_search_priority(card))
		if step_id in ["discard_cards", "discard_card", "discard_energy"]:
			if game_state != null and player_index >= 0:
				return float(get_discard_priority_contextual(card, game_state, player_index))
			return float(get_discard_priority(card))
		if card.card_data.card_type == "Tool":
			return _score_search_tool_target(card, all_items, game_state, player_index)
		if card.card_data.card_type == "Item":
			return _score_search_item_target(card, all_items, game_state, player_index)
		return float(get_search_priority(card))
	if item is PokemonSlot:
		var slot: PokemonSlot = item as PokemonSlot
		if step_id == "embrace_target" and game_state != null and player_index >= 0 and not all_items.is_empty():
			var best_slot: Variant = pick_embrace_target(all_items, game_state, player_index)
			if best_slot == slot:
				return 1000.0
		return float(score_assignment_target(slot))
	return 0.0


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id: String = str(step.get("id", ""))
	if item is PokemonSlot and step_id in ["send_out", "switch_target", "self_switch_target", "pivot_target", "heavy_baton_target", "own_bench_target"]:
		return _score_handoff_target(item as PokemonSlot, step_id, context)
	return score_interaction_target(item, step, context)


func _score_search_item_target(card: CardInstance, all_items: Array, game_state: GameState, player_index: int) -> float:
	if card == null or card.card_data == null:
		return 0.0
	if game_state != null and player_index >= 0 and not all_items.is_empty():
		var best_item: Variant = pick_search_item(all_items, game_state, player_index)
		if best_item == card:
			return 1000.0
	var name: String = str(card.card_data.name)
	if name == ULTRA_BALL:
		return 400.0
	if name == NEST_BALL or name == BUDDY_BUDDY_POFFIN:
		return 300.0
	if name == SECRET_BOX or name == EARTHEN_VESSEL:
		return 250.0
	if name == COUNTER_CATCHER or name == NIGHT_STRETCHER or name == RESCUE_STRETCHER:
		return 200.0
	return 50.0


func _score_search_tool_target(card: CardInstance, all_items: Array, game_state: GameState, player_index: int) -> float:
	if card == null or card.card_data == null:
		return 0.0
	if game_state != null and player_index >= 0 and not all_items.is_empty():
		var best_tool: Variant = pick_search_tool(all_items, game_state, player_index)
		if best_tool == card:
			return 1000.0
	var name: String = str(card.card_data.name)
	if name == TM_EVOLUTION:
		return 300.0
	if name == BRAVERY_CHARM:
		return 250.0
	return 50.0


func _score_search_pokemon_target(card: CardInstance, game_state: GameState, player_index: int) -> float:
	if card == null or card.card_data == null or game_state == null:
		return float(get_search_priority(card))
	if player_index < 0 or player_index >= game_state.players.size():
		return float(get_search_priority(card))
	var player: PlayerState = game_state.players[player_index]
	var name: String = str(card.card_data.name)
	var shell_online: bool = _has_online_shell(player)
	var attacker_bodies: int = _count_attackers_on_field(player)
	var ready_attackers: int = _count_ready_attackers(player)
	var weak_bench_target: bool = _opponent_has_scream_tail_prize_target(game_state, player_index)
	var charizard_rebuild_lock: bool = _charizard_rebuild_lock(game_state, player, player_index)
	var preferred_transition_attacker: String = _preferred_transition_attacker_name(game_state, player_index)
	if _must_force_first_gardevoir(player):
		if name == GARDEVOIR_EX:
			return 1000.0
		if name == RALTS and _count_pokemon_on_field(player, KIRLIA) == 0:
			return 400.0
		if name == RALTS:
			return -40.0
		if name == MUNKIDORI or name == MANAPHY:
			return -100.0
		return -60.0

	if shell_online and ready_attackers == 0 and (name in ATTACKER_NAMES or name == SCREAM_TAIL):
		var on_field_count: int = _count_pokemon_on_field(player, name)
		if name == preferred_transition_attacker:
			if name == SCREAM_TAIL and weak_bench_target:
				return 520.0 if on_field_count == 0 else 340.0
			return 460.0 if on_field_count == 0 else 300.0
		return 260.0 if on_field_count == 0 else 120.0
	if shell_online and weak_bench_target and name == SCREAM_TAIL and _count_pokemon_on_field(player, SCREAM_TAIL) == 0:
		return 360.0 if ready_attackers == 0 else 320.0
	if shell_online and attacker_bodies == 0:
		if name == DRIFLOON:
			return 320.0
		if name == SCREAM_TAIL:
			return 260.0
		if name == MUNKIDORI:
			return -40.0
	if charizard_rebuild_lock:
		if name == MUNKIDORI:
			return -80.0
		if name == RALTS:
			return -60.0
	if name == RALTS and _count_pokemon_on_field(player, RALTS) >= 2:
		return -20.0
	return float(get_search_priority(card))


func _score_night_stretcher_choice_target(card: CardInstance, game_state: GameState, player_index: int) -> float:
	if card == null or card.card_data == null or game_state == null:
		return 0.0
	if player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var name: String = str(card.card_data.name)
	var shell_lock: bool = _shell_lock_active(player)
	var transition_shell: bool = _has_transition_shell(player)
	var attacker_bodies: int = _count_attackers_on_field(player)
	var ready_attackers: int = _count_ready_attackers(player)
	var closed_loop_rebuild: bool = _attacker_rebuild_closed_loop_live(game_state, player, player_index)
	var preferred_transition_attacker: String = _preferred_transition_attacker_name(game_state, player_index)
	if card.card_data.card_type == "Basic Energy":
		if str(card.card_data.energy_provides) == "P":
			return 180.0 if _count_pokemon_on_field(player, GARDEVOIR_EX) >= 1 else 80.0
		return 20.0
	if name == GARDEVOIR_EX:
		if _count_pokemon_on_field(player, GARDEVOIR_EX) == 0:
			return 1000.0 if _count_pokemon_on_field(player, KIRLIA) >= 1 else 240.0
		return 40.0
	if name == KIRLIA:
		if _count_pokemon_on_field(player, KIRLIA) == 0 and _count_pokemon_on_field(player, RALTS) >= 1:
			return 720.0
		return 60.0
	if name == RALTS:
		if _count_primary_shell_bodies(player) < 2 and player.bench.size() < 5:
			return 360.0
		return 40.0
	if name in ATTACKER_NAMES or name == SCREAM_TAIL:
		if closed_loop_rebuild:
			if name == preferred_transition_attacker:
				return 960.0 if _count_pokemon_on_field(player, name) == 0 else 700.0
			return 720.0 if _count_pokemon_on_field(player, name) == 0 else 440.0
		if transition_shell and ready_attackers == 0:
			if name == preferred_transition_attacker:
				return 860.0 if _count_pokemon_on_field(player, name) == 0 else 520.0
			return 380.0 if _count_pokemon_on_field(player, name) == 0 else 180.0
		if transition_shell and attacker_bodies == 0:
			return 800.0
		if _count_pokemon_on_field(player, GARDEVOIR_EX) >= 1 and ready_attackers == 0:
			return 520.0
		return 140.0
	if name == MUNKIDORI:
		if shell_lock:
			return -80.0
		if transition_shell and attacker_bodies == 0:
			return -60.0
		if ready_attackers >= 1:
			return -80.0
		return 40.0
	return 20.0


func _score_handoff_target(slot: PokemonSlot, step_id: String, context: Dictionary) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index: int = int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return score_interaction_target(slot, {"id": step_id}, context)
	var player: PlayerState = game_state.players[player_index]
	var name: String = slot.get_pokemon_name()
	var preferred_transition_attacker: String = _preferred_transition_attacker_name(game_state, player_index)
	var ready_attackers: int = _count_ready_attackers(player)
	var attacker_bodies: int = _count_attackers_on_field(player)
	var score: float = 0.0

	if _shell_lock_active(player):
		match name:
			RALTS:
				return 420.0
			FLUTTER_MANE, KLEFKI:
				return 260.0
			DRIFLOON:
				return 180.0
			MUNKIDORI:
				return 60.0
			_:
				return 0.0

	if _has_online_shell(player):
		if _is_ready_attacker(slot):
			score = 920.0 if name == preferred_transition_attacker else 800.0
		elif ready_attackers == 0:
			if name == preferred_transition_attacker:
				score = 720.0 if attacker_bodies == 0 else 620.0
			elif name in ATTACKER_NAMES or name == SCREAM_TAIL:
				score = 420.0 if attacker_bodies == 0 else 300.0
			elif name == GARDEVOIR_EX:
				score = 180.0
			elif name == KIRLIA:
				score = 120.0
			elif name == MUNKIDORI:
				score = -120.0
			else:
				score = -40.0
		else:
			if name == preferred_transition_attacker and _is_attacker_body(slot):
				score = 220.0
			elif name == GARDEVOIR_EX:
				score = 120.0
			elif name == KIRLIA:
				score = 80.0
			elif name == MUNKIDORI:
				score = -120.0
			else:
				score = -40.0

	if step_id in ["self_switch_target", "switch_target", "pivot_target", "heavy_baton_target", "own_bench_target"]:
		score += 20.0

	return score if score != 0.0 else score_interaction_target(slot, {"id": step_id}, context)



func _count_pokemon_on_field(player: PlayerState, pokemon_name: String) -> int:
	var count: int = 0
	if _slot_is_live(player.active_pokemon) and player.active_pokemon.get_pokemon_name() == pokemon_name:
		count += 1
	for slot: PokemonSlot in player.bench:
		if _slot_is_live(slot) and slot.get_pokemon_name() == pokemon_name:
			count += 1
	return count


func _has_pokemon_on_bench(player: PlayerState, pokemon_name: String) -> bool:
	for slot: PokemonSlot in player.bench:
		if _slot_is_live(slot) and slot.get_pokemon_name() == pokemon_name:
			return true
	return false


func _hand_has_card(player: PlayerState, card_name: String) -> bool:
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and str(card.card_data.name) == card_name:
			return true
	return false


func _get_retreat_energy_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 999
	var retreat_cost: int = int(slot.get_card_data().retreat_cost)
	var attached: int = slot.attached_energy.size()
	return maxi(0, retreat_cost - attached)


func _is_ready_attacker(slot: PokemonSlot) -> bool:
	if not _slot_is_live(slot):
		return false
	var name: String = slot.get_pokemon_name()
	if name not in ATTACKER_NAMES and name != SCREAM_TAIL:
		return false
	var pred: Dictionary = predict_attacker_damage(slot)
	if int(pred.get("damage", 0)) > 0 and bool(pred.get("can_attack", false)):
		return true
	return _get_attack_energy_gap(slot) <= 0


func _hand_has_any_energy(player: PlayerState) -> bool:
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.is_energy():
			return true
	return false


func _hand_has_energy_type(player: PlayerState, etype: String) -> bool:
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.is_energy() and str(card.card_data.energy_provides) == etype:
			return true
	return false


func _slot_has_energy_type(slot: PokemonSlot, etype: String) -> bool:
	for energy: CardInstance in slot.attached_energy:
		if energy != null and energy.card_data != null and str(energy.card_data.energy_provides) == etype:
			return true
	return false


func _get_attack_energy_gap(slot: PokemonSlot) -> int:
	var card_data: CardData = slot.get_card_data()
	if card_data == null or card_data.attacks.is_empty():
		return 999
	var attached: int = slot.attached_energy.size()
	var min_gap: int = 999
	for attack: Dictionary in card_data.attacks:
		var cost: String = str(attack.get("cost", ""))
		var gap: int = maxi(0, cost.length() - attached)
		if gap < min_gap:
			min_gap = gap
	return min_gap


func _count_psychic_energy_in_discard(state: GameState, player_index: int) -> int:
	if player_index < 0 or player_index >= state.players.size():
		return 0
	var count: int = 0
	for card: CardInstance in state.players[player_index].discard_pile:
		if card != null and card.card_data != null and card.card_data.is_energy() and str(card.card_data.energy_provides) == "P":
			count += 1
	return count


func _has_attacker_in_discard(state: GameState, player_index: int) -> bool:
	if player_index < 0 or player_index >= state.players.size():
		return false
	for card: CardInstance in state.players[player_index].discard_pile:
		if card != null and card.card_data != null and str(card.card_data.name) in ATTACKER_NAMES:
			return true
		if card != null and card.card_data != null and str(card.card_data.name) == SCREAM_TAIL:
			return true
	return false


func _munkidori_can_threaten_ko(state: GameState, player_index: int) -> bool:
	if player_index < 0 or player_index >= state.players.size():
		return false
	var player: PlayerState = state.players[player_index]
	var max_movable_damage: int = 0
	for slot: PokemonSlot in _get_all_slots(player):
		max_movable_damage = maxi(max_movable_damage, mini(slot.damage_counters, 30))
	if max_movable_damage < 20:
		return false
	var opponent: PokemonSlot = state.players[1 - player_index].active_pokemon if (1 - player_index) < state.players.size() else null
	if opponent == null:
		return false
	return opponent.get_remaining_hp() <= max_movable_damage


func _has_ability_named(card_data: CardData, ability_name: String) -> bool:
	if card_data == null:
		return false
	for ability: Dictionary in card_data.abilities:
		if str(ability.get("name", "")) == ability_name:
			return true
	return false


func _has_any_ability(card_data: CardData, ability_names: Array) -> bool:
	if card_data == null:
		return false
	for ability: Dictionary in card_data.abilities:
		var aname: String = str(ability.get("name", ""))
		for candidate: Variant in ability_names:
			if aname == str(candidate):
				return true
	return false


func _find_gardevoir_ex_on_field(player: PlayerState) -> PokemonSlot:
	for slot: PokemonSlot in _get_all_slots(player):
		if _slot_is_live(slot) and slot.get_pokemon_name() == GARDEVOIR_EX:
			return slot
	return null


func _get_all_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


func _count_essential_slots_needed(player: PlayerState) -> int:
	var needed: int = 0
	var ralts_line: int = _count_primary_shell_bodies(player)
	needed += maxi(0, 2 - ralts_line)
	if _has_online_shell(player):
		if _count_attackers_on_field(player) == 0:
			needed += 1
	return needed


func _is_essential_pokemon(pname: String, player: PlayerState) -> bool:
	if pname == RALTS:
		return _count_primary_shell_bodies(player) < 2
	if _has_online_shell(player) and (pname == DRIFLOON or pname == SCREAM_TAIL):
		return _count_attackers_on_field(player) == 0
	return false


func _count_attackers_on_field(player: PlayerState) -> int:
	var count: int = 0
	for slot: PokemonSlot in _get_all_slots(player):
		if not _slot_is_live(slot):
			continue
		var name: String = slot.get_pokemon_name()
		if name in ATTACKER_NAMES or name == SCREAM_TAIL:
			count += 1
	return count


func _should_bench(pname: String, player: PlayerState, phase: String) -> bool:
	if not _hand_has_card(player, pname):
		return false
	if player.bench.size() >= 5:
		return false
	if _is_essential_pokemon(pname, player):
		return true
	var essential_needed: int = _count_essential_slots_needed(player)
	var free_slots: int = 5 - player.bench.size()
	if free_slots <= essential_needed:
		return false
	if pname == MANAPHY and _count_pokemon_on_field(player, MANAPHY) >= 1:
		return false
	return true


func _best_attacker_for_tool(player: PlayerState) -> String:
	for pname: String in [SCREAM_TAIL, DRIFBLIM, DRIFLOON]:
		for slot: PokemonSlot in _get_all_slots(player):
			if slot.get_pokemon_name() == pname and not _slot_has_tool(slot):
				return pname
	return ""


func _best_energy_target(player: PlayerState) -> String:
	for pname: String in [GARDEVOIR_EX, DRIFBLIM, DRIFLOON, SCREAM_TAIL]:
		for slot: PokemonSlot in _get_all_slots(player):
			if slot.get_pokemon_name() == pname and _get_attack_energy_gap(slot) > 0:
				return pname
	return ""


func _best_retreat_target(player: PlayerState) -> String:
	var active: PokemonSlot = player.active_pokemon
	if active == null:
		return ""
	var active_name: String = active.get_pokemon_name()
	if active_name in ATTACKER_NAMES or active_name == SCREAM_TAIL or active_name == GARDEVOIR_EX:
		if active.attached_energy.size() >= 1:
			return ""
	for slot: PokemonSlot in player.bench:
		if slot == null or slot.get_top_card() == null:
			continue
		var name: String = slot.get_pokemon_name()
		if (name in ATTACKER_NAMES or name == SCREAM_TAIL or name == GARDEVOIR_EX) and slot.attached_energy.size() >= 1:
			return name
	return ""


func _slot_has_tool(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	var card_data: CardData = slot.get_card_data()
	if card_data == null:
		return false
	for card: CardInstance in slot.pokemon_stack:
		if card != null and card.card_data != null and card.card_data.card_type == "Tool":
			return true
	return false


func _has_evolvable_bench_targets(player: PlayerState) -> bool:
	for slot: PokemonSlot in player.bench:
		if slot == null or slot.get_top_card() == null:
			continue
		var cd: CardData = slot.get_card_data()
		if cd == null:
			continue
		if cd.stage == "Basic" and cd.name == RALTS:
			return true
		if cd.stage == "Stage 1" and cd.name == KIRLIA:
			return true
	return false


func _count_evolvable_bench_targets(player: PlayerState) -> int:
	var count: int = 0
	for slot: PokemonSlot in player.bench:
		if slot == null or slot.get_top_card() == null:
			continue
		var cd: CardData = slot.get_card_data()
		if cd == null:
			continue
		if cd.stage == "Basic" and cd.name == RALTS:
			count += 1
		elif cd.stage == "Stage 1" and cd.name == KIRLIA:
			count += 1
	return count


func _active_has_tm_evolution(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	var tool: CardInstance = player.active_pokemon.attached_tool
	if tool != null and tool.card_data != null and str(tool.card_data.name) == TM_EVOLUTION:
		return true
	for card: CardInstance in player.active_pokemon.pokemon_stack:
		if card != null and card.card_data != null and str(card.card_data.name) == TM_EVOLUTION:
			return true
	return false


func _shell_lock_active(player: PlayerState) -> bool:
	return not _has_online_shell(player)


func _should_delay_attacker_investment_during_shell_lock(player: PlayerState) -> bool:
	if not _shell_lock_active(player):
		return false
	if _count_primary_shell_bodies(player) < 2:
		return true
	if _must_force_first_gardevoir(player):
		return true
	if _has_shell_search(player):
		return true
	return false


func _must_force_first_gardevoir(player: PlayerState) -> bool:
	return _count_pokemon_on_field(player, GARDEVOIR_EX) == 0 and _count_pokemon_on_field(player, KIRLIA) >= 1


func _first_gardevoir_emergency(player: PlayerState) -> bool:
	return _must_force_first_gardevoir(player) and _count_primary_shell_bodies(player) >= 2


func _has_direct_first_gardevoir_line(state: GameState, player: PlayerState, player_index: int) -> bool:
	if player == null:
		return false
	if not _must_force_first_gardevoir(player):
		return false
	if _hand_has_card(player, GARDEVOIR_EX):
		return true
	if _hand_has_card(player, ULTRA_BALL):
		return true
	if _hand_has_card(player, SECRET_BOX):
		return true
	if _hand_has_card(player, ARVEN):
		return true
	if state != null and _discard_has_card(state, player_index, GARDEVOIR_EX):
		if _hand_has_card(player, NIGHT_STRETCHER) or _hand_has_card(player, RESCUE_STRETCHER):
			return true
	return false


func _first_gardevoir_fuel_gate(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null:
		return false
	if not _must_force_first_gardevoir(player):
		return false
	if _count_primary_shell_bodies(player) < 2:
		return false
	if _count_psychic_energy_in_discard(game_state, player_index) >= 2:
		return false
	if _count_pokemon_on_field(player, KIRLIA) >= 1:
		return true
	if _count_pokemon_on_field(player, RADIANT_GRENINJA) >= 1 and (_hand_has_energy_type(player, "P") or _hand_has_energy_type(player, "D")):
		return true
	return false


func _post_tm_refill_window(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null:
		return false
	if not _shell_lock_active(player):
		return false
	if _count_primary_shell_bodies(player) < 2:
		return false
	if _count_pokemon_on_field(player, KIRLIA) < 2:
		return false
	if _count_psychic_energy_in_discard(game_state, player_index) >= 2:
		return false
	return true


func _gardevoir_handoff_window(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if _count_pokemon_on_field(player, GARDEVOIR_EX) == 0:
		return false
	if _count_attackers_on_field(player) == 0:
		return false
	return _count_psychic_energy_in_discard(game_state, player_index) >= 2


func _post_stage2_handoff_live(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null:
		return false
	if not _has_online_shell(player):
		return false
	if _count_attackers_on_field(player) == 0:
		return false
	if _count_psychic_energy_in_discard(game_state, player_index) < 2:
		return false
	return true


func _attacker_rebuild_closed_loop_live(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if game_state == null or player == null:
		return false
	if not _has_online_shell(player):
		return false
	if not _needs_attacker_recovery(game_state, player, player_index):
		return false
	if not _has_attacker_in_discard(game_state, player_index):
		return false
	return _count_psychic_energy_in_discard(game_state, player_index) >= 2


func _has_transition_shell(player: PlayerState) -> bool:
	return _has_established_stage2_shell(player)


func _has_online_shell(player: PlayerState) -> bool:
	return _count_pokemon_on_field(player, GARDEVOIR_EX) >= 1


func _tm_precharge_window(player: PlayerState) -> bool:
	return _shell_lock_active(player) and _count_pokemon_on_field(player, RALTS) >= 2 and _tm_still_accessible(player)


func _tm_still_accessible(player: PlayerState) -> bool:
	if player == null:
		return false
	if _hand_has_card(player, TM_EVOLUTION) or _active_has_tm_evolution(player):
		return true
	if (_hand_has_card(player, ARVEN) or _hand_has_card(player, SECRET_BOX)) and _deck_has_card_name(player, TM_EVOLUTION):
		return true
	return false


func _deck_has_card_name(player: PlayerState, target_name: String) -> bool:
	if player == null or target_name == "":
		return false
	for card: CardInstance in player.deck:
		if card == null or card.card_data == null:
			continue
		if str(card.card_data.name) == target_name:
			return true
	return false


func _turn_intent(player: PlayerState, phase: String) -> String:
	if _shell_lock_active(player):
		if _first_gardevoir_emergency(player):
			return "force_first_gardevoir"
		if _tm_setup_priority_live(player, phase) or _tm_precharge_window(player):
			return "launch_shell_tm"
		return "launch_shell"
	if _has_transition_shell(player) and _count_ready_attackers(player) < 1:
		return "transition_shell"
	return "conversion"


func _tm_support_carrier_cools_off(player: PlayerState, phase: String) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	var active_name: String = player.active_pokemon.get_pokemon_name()
	if active_name == KIRLIA:
		if _must_force_first_gardevoir(player) and _count_pokemon_on_field(player, KIRLIA) >= 2:
			return true
		if _has_transition_shell(player) and phase != "early":
			return true
		return false
	if active_name not in [MUNKIDORI, KLEFKI]:
		return false
	if _has_online_shell(player):
		return true
	if _has_transition_shell(player) and phase != "early":
		return true
	return false


func _charizard_rebuild_lock(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if not _is_charizard_pressure_matchup(game_state, player_index):
		return false
	if not _has_established_stage2_shell(player):
		return false
	if _needs_attacker_recovery(game_state, player, player_index):
		return false
	return _count_attackers_on_field(player) >= 1


func _is_charizard_pressure_matchup(game_state: GameState, player_index: int) -> bool:
	if game_state == null:
		return false
	var opponent_index: int = 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[opponent_index]
	for slot: PokemonSlot in _get_all_slots(opponent):
		if slot == null or slot.get_top_card() == null:
			continue
		var cd: CardData = slot.get_card_data()
		var cname: String = slot.get_pokemon_name()
		var name_en: String = str(cd.name_en) if cd != null else ""
		if cname in ["喷火龙ex", "大比鸟ex", "波波", "小火龙", "夜巡灵", "洛托姆V"]:
			return true
		if name_en in [CHARIZARD_EX_EN, PIDGEOT_EX_EN, PIDGEY_EN, CHARMANDER_EN, DUSKULL_EN, ROTOM_V_EN]:
			return true
	return false
func _tm_setup_priority_live(player: PlayerState, phase: String) -> bool:
	if not _shell_lock_active(player):
		return false
	if not _has_evolvable_bench_targets(player):
		return false
	if player.active_pokemon == null:
		return false
	if _tm_support_carrier_cools_off(player, phase):
		return false
	if not (_hand_has_card(player, TM_EVOLUTION) or _active_has_tm_evolution(player)):
		return false
	if player.active_pokemon.attached_energy.size() >= 1 or _hand_has_any_energy(player):
		return true
	return phase == "early"


func _can_ko_bench_target(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	var active: PokemonSlot = player.active_pokemon
	if active == null:
		return false
	var pred: Dictionary = predict_attacker_damage(active)
	var my_damage: int = int(pred.get("damage", 0))
	if my_damage <= 0:
		var cd: CardData = active.get_card_data()
		if cd != null:
			for attack: Dictionary in cd.attacks:
				var dmg: int = int(str(attack.get("damage", "0")).strip_edges())
				if dmg > my_damage:
					my_damage = dmg
	if my_damage <= 0:
		return false
	var opponent_index: int = 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	for slot: PokemonSlot in game_state.players[opponent_index].bench:
		if slot == null or slot.get_top_card() == null:
			continue
		if slot.get_remaining_hp() <= my_damage:
			return true
	return false


func _has_core_in_discard(state: GameState, player_index: int) -> bool:
	if player_index < 0 or player_index >= state.players.size():
		return false
	for card: CardInstance in state.players[player_index].discard_pile:
		if card != null and card.card_data != null and str(card.card_data.name) in CORE_NAMES:
			return true
	return false


func _count_ready_attackers(player: PlayerState) -> int:
	var count: int = 0
	for slot: PokemonSlot in _get_all_slots(player):
		if _is_ready_attacker(slot):
			count += 1
	return count


func _count_live_attackers(player: PlayerState) -> int:
	var count: int = 0
	for slot: PokemonSlot in _get_all_slots(player):
		if not _slot_is_live(slot):
			continue
		var name: String = slot.get_pokemon_name()
		if name not in ATTACKER_NAMES and name != SCREAM_TAIL:
			continue
		var pred: Dictionary = predict_attacker_damage(slot)
		if bool(pred.get("can_attack", false)) and int(pred.get("damage", 0)) > 0:
			count += 1
	return count


func _count_primary_shell_bodies(player: PlayerState) -> int:
	return _count_pokemon_on_field(player, RALTS) + _count_pokemon_on_field(player, KIRLIA)


func _slot_is_live(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_top_card() == null:
		return false
	return slot.get_remaining_hp() > 0


func _has_established_stage2_shell(player: PlayerState) -> bool:
	return _has_online_shell(player) and _count_pokemon_on_field(player, KIRLIA) >= 1


func _needs_attacker_recovery(state: GameState, player: PlayerState, player_index: int) -> bool:
	if state == null:
		return false
	if not _has_online_shell(player):
		return false
	if _count_ready_attackers(player) >= 1:
		return false
	if _count_attackers_on_field(player) >= 1:
		return false
	return _has_attacker_in_discard(state, player_index)


func _needs_first_attacker_body(player: PlayerState) -> bool:
	if player == null:
		return false
	if not _has_online_shell(player):
		return false
	return _count_attackers_on_field(player) == 0


func _night_stretcher_has_live_target(state: GameState, player: PlayerState, player_index: int) -> bool:
	if state == null or player == null:
		return false
	if _has_attacker_in_discard(state, player_index):
		return true
	if _count_pokemon_on_field(player, GARDEVOIR_EX) == 0 and _discard_has_card(state, player_index, GARDEVOIR_EX):
		return true
	if _count_pokemon_on_field(player, KIRLIA) == 0 and _count_pokemon_on_field(player, RALTS) >= 1 and _discard_has_card(state, player_index, KIRLIA):
		return true
	if _count_primary_shell_bodies(player) < 2 and _discard_has_card(state, player_index, RALTS):
		return true
	if _count_psychic_energy_in_discard(state, player_index) >= 2:
		return true
	return false


func _has_deck_out_pressure(player: PlayerState) -> bool:
	return player.deck.size() > 0 and player.deck.size() <= 10


func _has_shell_search(player: PlayerState) -> bool:
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		var cname: String = str(card.card_data.name)
		if cname in [ULTRA_BALL, NEST_BALL, BUDDY_BUDDY_POFFIN, ARVEN, ARTAZON]:
			return true
	return false


func _opponent_has_scream_tail_prize_target(game_state: GameState, player_index: int) -> bool:
	return _best_scream_tail_bench_prize_value(game_state, player_index, 120) > 0.0




func _tm_attack_payment_gap(slot: PokemonSlot) -> int:
	if slot == null:
		return 999
	return maxi(0, 1 - slot.attached_energy.size())




func _has_immediate_attack_window(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	var pred: Dictionary = predict_attacker_damage(player.active_pokemon)
	if bool(pred.get("can_attack", false)) and int(pred.get("damage", 0)) > 0:
		return true
	return _can_pivot_into_ready_attacker(player)


func _can_pivot_into_ready_attacker(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if _get_retreat_energy_gap(player.active_pokemon) > 0:
		return false
	for bench_slot: PokemonSlot in player.bench:
		if _is_ready_attacker(bench_slot):
			return true
	return false


func _preferred_transition_attacker_name(game_state: GameState, player_index: int) -> String:
	if game_state != null and player_index >= 0 and _opponent_has_scream_tail_prize_target(game_state, player_index):
		return SCREAM_TAIL
	return DRIFLOON


func _is_attacker_body(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_top_card() == null:
		return false
	var name: String = slot.get_pokemon_name()
	return name in ATTACKER_NAMES or name == SCREAM_TAIL




func _count_searchable_basic_targets(player: PlayerState) -> int:
	if player.bench.size() >= 5:
		return 0
	if player.deck.size() > 0:
		var searchable_in_deck: bool = false
		for card: CardInstance in player.deck:
			if card == null or card.card_data == null:
				continue
			if str(card.card_data.card_type) != "Pokemon" or str(card.card_data.stage) != "Basic":
				continue
			searchable_in_deck = true
			break
		if not searchable_in_deck:
			return 0
	var count: int = 0
	if _count_primary_shell_bodies(player) < 2:
		count += 1
	elif _has_established_stage2_shell(player) and _count_attackers_on_field(player) == 0:
		count += 1
	return count




func _best_scream_tail_bench_prize_value(game_state: GameState, player_index: int, damage: int) -> float:
	if game_state == null or damage <= 0:
		return 0.0
	var opponent_index: int = 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return 0.0
	var best: float = 0.0
	for slot: PokemonSlot in game_state.players[opponent_index].bench:
		if slot == null or slot.get_top_card() == null:
			continue
		if slot.get_remaining_hp() > damage:
			continue
		var slot_value: float = 220.0
		var cd: CardData = slot.get_card_data()
		if cd != null:
			var name_en: String = str(cd.name_en)
			if cd.mechanic == "ex" or cd.mechanic == "V":
				slot_value = 420.0
			elif name_en in ["Pidgey", "Charmander", "Duskull"]:
				slot_value = 320.0
			elif name_en in ["Rotom V", "Lumineon V"]:
				slot_value = 380.0
		best = maxf(best, slot_value)
	return best




func _discard_has_card(state: GameState, player_index: int, card_name: String) -> bool:
	if state == null or player_index < 0 or player_index >= state.players.size():
		return false
	for card: CardInstance in state.players[player_index].discard_pile:
		if card != null and card.card_data != null and str(card.card_data.name) == card_name:
			return true
	return false




func _active_attack_can_be_finished_with_one_attach(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	var active_name: String = player.active_pokemon.get_pokemon_name()
	if active_name not in [SCREAM_TAIL, DRIFLOON]:
		return false
	return _get_attack_energy_gap(player.active_pokemon) <= 1




func _should_cool_off_tm_evolution(player: PlayerState, phase: String) -> bool:
	if _must_force_first_gardevoir(player) and _count_pokemon_on_field(player, KIRLIA) >= 2:
		return true
	if _has_transition_shell(player) and (_count_ready_attackers(player) >= 1 or phase != "early"):
		return true
	if _has_online_shell(player) and phase == "late":
		return true
	return false
