class_name DeckStrategyPalkiaGholdengo
extends "res://scripts/ai/DeckStrategyBase.gd"


const NeuralNetInferenceScript = preload("res://scripts/ai/NeuralNetInference.gd")
const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")

const GHOLDENGO_EX := "Gholdengo ex"
const GIMMIGHOUL := "Gimmighoul"
const PALKIA_V := "Origin Forme Palkia V"
const PALKIA_VSTAR := "Origin Forme Palkia VSTAR"
const MANAPHY := "Manaphy"
const BIDOOF := "Bidoof"
const BIBAREL := "Bibarel"
const RADIANT_GRENINJA := "Radiant Greninja"

const SUPERIOR_ENERGY_RETRIEVAL := "Superior Energy Retrieval"
const ENERGY_RETRIEVAL := "Energy Retrieval"
const EARTHEN_VESSEL := "Earthen Vessel"
const BUDDY_BUDDY_POFFIN := "Buddy-Buddy Poffin"
const NEST_BALL := "Nest Ball"
const IRIDA := "Irida"
const CIPHERMANIACS_CODEBREAKING := "Ciphermaniac's Codebreaking"
const BOSS_ORDERS := "Boss's Orders"
const PRIME_CATCHER := "Prime Catcher"
const PROFESSORS_RESEARCH := "Professor's Research"
const IONO := "Iono"
const JUDGE := "Judge"
const FULL_METAL_LAB := "Full Metal Lab"
const CANCELING_COLOGNE := "Canceling Cologne"

const WATER_ENERGY := "W"
const METAL_ENERGY := "M"

const NAME_ALIASES := {
	GHOLDENGO_EX: [GHOLDENGO_EX, "赛富豪ex"],
	GIMMIGHOUL: [GIMMIGHOUL, "索财灵"],
	PALKIA_V: [PALKIA_V, "起源帕路奇亚V"],
	PALKIA_VSTAR: [PALKIA_VSTAR, "起源帕路奇亚VSTAR"],
	MANAPHY: [MANAPHY, "玛纳霏"],
	BIDOOF: [BIDOOF, "大牙狸"],
	BIBAREL: [BIBAREL, "大尾狸"],
	RADIANT_GRENINJA: [RADIANT_GRENINJA, "光辉甲贺忍蛙"],
	SUPERIOR_ENERGY_RETRIEVAL: [SUPERIOR_ENERGY_RETRIEVAL, "超级能量回收"],
	ENERGY_RETRIEVAL: [ENERGY_RETRIEVAL, "能量回收"],
	EARTHEN_VESSEL: [EARTHEN_VESSEL, "大地容器"],
	BUDDY_BUDDY_POFFIN: [BUDDY_BUDDY_POFFIN, "友好宝芬"],
	NEST_BALL: [NEST_BALL, "巢穴球"],
	IRIDA: [IRIDA, "珠贝"],
	CIPHERMANIACS_CODEBREAKING: [CIPHERMANIACS_CODEBREAKING, "暗码迷的解读"],
	BOSS_ORDERS: [BOSS_ORDERS, "老大的指令"],
	PRIME_CATCHER: [PRIME_CATCHER, "顶尖捕捉器"],
	PROFESSORS_RESEARCH: [PROFESSORS_RESEARCH, "博士的研究"],
	IONO: [IONO, "奇树"],
	JUDGE: [JUDGE, "裁判"],
	FULL_METAL_LAB: [FULL_METAL_LAB, "全金属实验室"],
	CANCELING_COLOGNE: [CANCELING_COLOGNE, "清除古龙水"],
}

var _value_net: RefCounted = null


func get_strategy_id() -> String:
	return "palkia_gholdengo"


func get_signature_names() -> Array[String]:
	return [
		GHOLDENGO_EX, "赛富豪ex",
		PALKIA_VSTAR, "起源帕路奇亚VSTAR",
		PALKIA_V, "起源帕路奇亚V",
		GIMMIGHOUL, "索财灵",
	]


func get_state_encoder_class() -> GDScript:
	return StateEncoderScript


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
		"time_budget_ms": 80,
		"rollouts_per_sequence": 0,
	}


func plan_opening_setup(player: PlayerState) -> Dictionary:
	var basics: Array[Dictionary] = []
	for i: int in player.hand.size():
		var card: CardInstance = player.hand[i]
		if card != null and card.is_basic_pokemon():
			basics.append({
				"index": i,
				"active_priority": _opening_active_priority(_card_name(card)),
				"bench_priority": _opening_bench_priority(_card_name(card)),
			})
	if basics.is_empty():
		return {}

	basics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("active_priority", 0)) > int(b.get("active_priority", 0))
	)

	var active_idx: int = int(basics[0].get("index", -1))
	var bench_pairs: Array[Dictionary] = []
	for entry: Dictionary in basics:
		var idx: int = int(entry.get("index", -1))
		if idx == active_idx:
			continue
		bench_pairs.append({
			"idx": idx,
			"score": int(entry.get("bench_priority", 0)),
		})
	bench_pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)

	var bench_indices: Array[int] = []
	for pair: Dictionary in bench_pairs:
		if bench_indices.size() >= 3:
			break
		if int(pair.get("score", 0)) <= 0:
			continue
		bench_indices.append(int(pair.get("idx", -1)))

	return {
		"active_hand_index": active_idx,
		"bench_hand_indices": bench_indices,
	}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	match str(action.get("kind", "")):
		"play_basic_to_bench":
			return float(_opening_bench_priority(_card_name(action.get("card"))))
		"evolve":
			return _score_evolve(action, player)
		"attach_energy":
			return _score_attach_energy(action, game_state, player, player_index)
		"play_trainer":
			return _score_trainer(action, game_state, player, player_index)
		"use_ability":
			return _score_ability(action, game_state, player, player_index)
		"attack":
			return _score_attack(action, game_state, player, player_index)
		"retreat":
			return _score_retreat(game_state, player, player_index)
	return 0.0


func score_action(action: Dictionary, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index: int = int(context.get("player_index", -1))
	return score_action_absolute(action, game_state, player_index) - _estimate_heuristic_base(str(action.get("kind", "")))


func evaluate_board(game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var score: float = 0.0
	score += float(_count_name_on_field(player, PALKIA_VSTAR)) * 180.0
	score += float(_count_name_on_field(player, PALKIA_V)) * 85.0
	score += float(_count_name_on_field(player, GHOLDENGO_EX)) * 240.0
	score += float(_count_name_on_field(player, GIMMIGHOUL)) * 70.0
	score += float(_count_name_on_field(player, BIBAREL)) * 95.0
	score += float(_count_name_on_field(player, RADIANT_GRENINJA)) * 50.0
	score += float(_count_energy(player.hand, METAL_ENERGY)) * 40.0
	score += float(_count_energy(player.discard_pile, METAL_ENERGY)) * 28.0
	score += float(_count_energy(player.discard_pile, WATER_ENERGY)) * 14.0
	if _has_name_on_field(player, FULL_METAL_LAB):
		score += 45.0
	if _is_burst_turn(game_state, player_index):
		score += 130.0
	return score


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_top_card() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var name: String = _slot_name(slot)
	if name == GHOLDENGO_EX:
		return {
			"damage": extra_context * 50,
			"can_attack": slot.attached_energy.size() >= 1,
			"description": "Make It Rain",
		}
	if name == PALKIA_VSTAR:
		return {
			"damage": 60 + extra_context * 20,
			"can_attack": slot.attached_energy.size() >= 2,
			"description": "Subspace Swell",
		}
	return _predict_generic_attack(slot)


func get_discard_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	var name: String = _card_name(card)
	if card.card_data.is_energy():
		if str(card.card_data.energy_provides) == METAL_ENERGY:
			return 220
		if str(card.card_data.energy_provides) == WATER_ENERGY:
			return 120
	if name in [BIDOOF, MANAPHY]:
		return 140
	if name in [BUDDY_BUDDY_POFFIN, NEST_BALL]:
		return 90
	if name in [GHOLDENGO_EX, PALKIA_VSTAR]:
		return 5
	return 60


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return get_discard_priority(card)
	var player: PlayerState = game_state.players[player_index]
	var name: String = _card_name(card)
	if name == BUDDY_BUDDY_POFFIN and player.bench.size() >= 5:
		return 200
	if name == SUPERIOR_ENERGY_RETRIEVAL and _count_energy(player.discard_pile, METAL_ENERGY) >= 2:
		return 10
	return get_discard_priority(card)


func get_search_priority(card: CardInstance) -> int:
	var name: String = _card_name(card)
	if name == GHOLDENGO_EX:
		return 100
	if name == GIMMIGHOUL:
		return 97
	if name == PALKIA_VSTAR:
		return 94
	if name == PALKIA_V:
		return 92
	if name == BIBAREL:
		return 84
	if name == BIDOOF:
		return 82
	if name == RADIANT_GRENINJA:
		return 72
	if name == MANAPHY:
		return 68
	return 20


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id: String = str(step.get("id", ""))
	if item is CardInstance:
		var card := item as CardInstance
		if step_id in ["search_pokemon", "basic_pokemon", "bench_pokemon", "water_pokemon"]:
			return float(get_search_priority(card))
		if step_id in ["item_card", "search_item", "search_cards"]:
			return _score_item_search_target(card, context)
		if step_id in ["discard_card", "discard_cards", "discard_energy"]:
			var game_state: GameState = context.get("game_state", null)
			var player_index: int = int(context.get("player_index", -1))
			return float(get_discard_priority_contextual(card, game_state, player_index))
		return float(get_search_priority(card))
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if step_id in ["attach_energy_target", "energy_target", "star_portal_assignments"]:
			return _score_attach_target(slot)
		if step_id == "send_out":
			return float(_opening_active_priority(_slot_name(slot)))
	return 0.0


func _score_evolve(action: Dictionary, player: PlayerState) -> float:
	var name: String = _card_name(action.get("card"))
	if name == PALKIA_VSTAR:
		return 430.0 if _count_name_on_field(player, PALKIA_VSTAR) == 0 else 220.0
	if name == GHOLDENGO_EX:
		return 420.0 if _count_name_on_field(player, GHOLDENGO_EX) == 0 else 240.0
	if name == BIBAREL:
		return 260.0
	return 80.0


func _score_attach_energy(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int) -> float:
	var slot: PokemonSlot = action.get("target_slot")
	var card: CardInstance = action.get("card")
	if slot == null or card == null or card.card_data == null:
		return 0.0
	var energy_type: String = str(card.card_data.energy_provides)
	var name: String = _slot_name(slot)
	var setup_gap: int = _engine_setup_gap(player)
	if energy_type == WATER_ENERGY:
		if name == PALKIA_V or name == PALKIA_VSTAR:
			if slot.attached_energy.size() == 0:
				return 390.0
			return 340.0 if not _is_burst_turn(game_state, player_index) else 220.0
		if name == RADIANT_GRENINJA:
			return 210.0 if _count_energy(player.hand, METAL_ENERGY) + _count_energy(player.hand, WATER_ENERGY) > 0 else 110.0
		return 90.0
	if energy_type == METAL_ENERGY:
		if name == GHOLDENGO_EX:
			return 360.0 if not _is_burst_turn(game_state, player_index) else 460.0
		if name == GIMMIGHOUL:
			return 260.0 if setup_gap > 0 else 170.0
		return 70.0
	return 20.0


func _score_trainer(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int) -> float:
	var name: String = _card_name(action.get("card"))
	var setup_gap: int = _engine_setup_gap(player)
	var discard_metal: int = _count_energy(player.discard_pile, METAL_ENERGY)
	var hand_metal: int = _count_energy(player.hand, METAL_ENERGY)
	var active_name: String = _slot_name(player.active_pokemon)
	if name == SUPERIOR_ENERGY_RETRIEVAL:
		if discard_metal >= 2:
			if active_name == GHOLDENGO_EX and _is_burst_turn(game_state, player_index):
				return 380.0
			return 330.0
		return 110.0
	if name == ENERGY_RETRIEVAL:
		return 280.0 if discard_metal >= 1 else 100.0
	if name == EARTHEN_VESSEL:
		if discard_metal + hand_metal < 4:
			return 320.0
		return 190.0
	if name == IRIDA:
		if setup_gap >= 2:
			return 420.0
		if setup_gap > 0:
			return 340.0
		if discard_metal < 2:
			return 230.0
		return 170.0
	if name == CIPHERMANIACS_CODEBREAKING:
		if setup_gap > 0:
			return 290.0
		if _is_burst_turn(game_state, player_index):
			return 260.0
		return 180.0
	if name == BUDDY_BUDDY_POFFIN or name == NEST_BALL:
		if _is_burst_turn(game_state, player_index):
			return 120.0
		return 280.0 if player.bench.size() < 4 and setup_gap > 0 else 150.0
	if name == BOSS_ORDERS:
		return 320.0 if _can_current_attacker_take_ko(game_state, player_index) else 150.0
	if name == PRIME_CATCHER:
		return 380.0 if _can_current_attacker_take_ko(game_state, player_index) else 180.0
	if name == FULL_METAL_LAB:
		return 240.0 if _count_name_on_field(player, GHOLDENGO_EX) > 0 else 120.0
	if name == IONO or name == JUDGE:
		return 200.0 if _can_current_attacker_take_ko(game_state, player_index) else 140.0
	if name == CANCELING_COLOGNE:
		return 150.0
	if name == PROFESSORS_RESEARCH:
		return 180.0 if setup_gap > 0 else 210.0
	return 70.0


func _score_ability(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int) -> float:
	var slot: PokemonSlot = action.get("source_slot")
	if slot == null:
		return 0.0
	var name: String = _slot_name(slot)
	if name == GHOLDENGO_EX:
		if _is_burst_turn(game_state, player_index):
			return 180.0
		return 280.0 if player.hand.size() <= 4 else 210.0
	if name == RADIANT_GRENINJA:
		return 320.0 if _count_energy(player.hand, WATER_ENERGY) + _count_energy(player.hand, METAL_ENERGY) > 0 else 70.0
	if name == BIBAREL:
		return 260.0 if player.hand.size() <= 4 else 170.0
	return 40.0


func _score_attack(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int) -> float:
	var active: PokemonSlot = player.active_pokemon
	if active == null:
		return 0.0
	var opponent: PokemonSlot = game_state.players[1 - player_index].active_pokemon
	var projected_damage: int = int(action.get("projected_damage", 0))
	if projected_damage <= 0:
		projected_damage = _predict_attack_with_board(active, game_state)
	var target_hp: int = opponent.get_remaining_hp() if opponent != null else 999
	var base: float = 320.0 if _is_burst_turn(game_state, player_index) else 140.0
	if projected_damage >= target_hp:
		base += 520.0
	elif projected_damage >= 180:
		base += 280.0
	elif projected_damage > 0:
		base += 120.0
	if _slot_name(active) == GHOLDENGO_EX and _count_energy(player.hand, METAL_ENERGY) >= 3:
		base += 180.0
	return base


func _score_retreat(game_state: GameState, player: PlayerState, player_index: int) -> float:
	if player.active_pokemon == null:
		return 0.0
	var active_name: String = _slot_name(player.active_pokemon)
	if active_name == GHOLDENGO_EX and _is_burst_turn(game_state, player_index):
		return 20.0
	if active_name in [MANAPHY, BIBAREL, RADIANT_GRENINJA]:
		return 180.0 if _has_ready_attacker(player, game_state) else 80.0
	return 60.0


func _opening_active_priority(name: String) -> int:
	if name == PALKIA_V:
		return 100
	if name == GIMMIGHOUL:
		return 82
	if name == MANAPHY:
		return 55
	if name == BIDOOF:
		return 48
	if name == RADIANT_GRENINJA:
		return 40
	return 20


func _opening_bench_priority(name: String) -> int:
	if name == GIMMIGHOUL:
		return 100
	if name == PALKIA_V:
		return 95
	if name == BIDOOF:
		return 78
	if name == RADIANT_GRENINJA:
		return 72
	if name == MANAPHY:
		return 65
	return 0


func _is_burst_turn(game_state: GameState, player_index: int) -> bool:
	var player: PlayerState = game_state.players[player_index]
	if player.active_pokemon == null or _slot_name(player.active_pokemon) != GHOLDENGO_EX:
		return false
	if _count_energy(player.hand, METAL_ENERGY) >= 3:
		return true
	var opponent: PokemonSlot = game_state.players[1 - player_index].active_pokemon
	if opponent == null:
		return false
	return _predict_attack_with_board(player.active_pokemon, game_state) >= opponent.get_remaining_hp()


func _engine_setup_gap(player: PlayerState) -> int:
	var gap: int = 0
	if _count_name_on_field(player, GHOLDENGO_EX) == 0:
		gap += 1
	if _count_name_on_field(player, PALKIA_VSTAR) == 0:
		gap += 1
	if _count_name_on_field(player, BIBAREL) == 0 and _count_name_on_field(player, BIDOOF) == 0:
		gap += 1
	return gap


func _score_item_search_target(card: CardInstance, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index: int = int(context.get("player_index", -1))
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	var name: String = _card_name(card)
	if name == SUPERIOR_ENERGY_RETRIEVAL:
		return 360.0 if player != null and _count_energy(player.discard_pile, METAL_ENERGY) >= 2 else 180.0
	if name == EARTHEN_VESSEL:
		return 320.0
	if name == BUDDY_BUDDY_POFFIN or name == NEST_BALL:
		return 260.0
	if name == PRIME_CATCHER:
		return 250.0
	if name == ENERGY_RETRIEVAL:
		return 220.0
	if name == CANCELING_COLOGNE:
		return 150.0
	return 80.0


func _score_attach_target(slot: PokemonSlot) -> float:
	var name: String = _slot_name(slot)
	if name == GHOLDENGO_EX:
		return 420.0
	if name == PALKIA_VSTAR or name == PALKIA_V:
		return 340.0
	if name == GIMMIGHOUL:
		return 220.0
	if name == RADIANT_GRENINJA:
		return 180.0
	return 60.0


func _predict_attack_with_board(slot: PokemonSlot, game_state: GameState) -> int:
	if slot == null:
		return 0
	if _slot_name(slot) == GHOLDENGO_EX:
		var player_index: int = _find_owner_index(game_state, slot)
		if player_index >= 0:
			return _count_energy(game_state.players[player_index].hand, METAL_ENERGY) * 50
	if _slot_name(slot) == PALKIA_VSTAR:
		return 60 + _count_total_bench(game_state) * 20
	var generic: Dictionary = _predict_generic_attack(slot)
	return int(generic.get("damage", 0))


func _predict_generic_attack(slot: PokemonSlot) -> Dictionary:
	if slot == null or slot.get_top_card() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var attached: int = slot.attached_energy.size()
	var best_damage: int = 0
	var can_attack: bool = false
	for attack: Dictionary in slot.get_attacks():
		var cost: String = str(attack.get("cost", ""))
		var damage_text: String = str(attack.get("damage", "0")).replace("x", "").replace("脳", "").replace("+", "")
		var damage: int = int(damage_text) if damage_text.is_valid_int() else 0
		if attached >= cost.length():
			can_attack = true
			best_damage = maxi(best_damage, damage)
	return {"damage": best_damage, "can_attack": can_attack, "description": ""}


func _count_name_on_field(player: PlayerState, target_name: String) -> int:
	var count: int = 0
	if player.active_pokemon != null and _slot_name(player.active_pokemon) == target_name:
		count += 1
	for slot: PokemonSlot in player.bench:
		if slot != null and _slot_name(slot) == target_name:
			count += 1
	return count


func _has_name_on_field(player: PlayerState, target_name: String) -> bool:
	return _count_name_on_field(player, target_name) > 0


func _count_energy(cards: Array, energy_type: String) -> int:
	var count: int = 0
	for item: Variant in cards:
		if item is CardInstance:
			var card := item as CardInstance
			if card.card_data != null and card.card_data.is_energy() and str(card.card_data.energy_provides) == energy_type:
				count += 1
	return count


func _count_total_bench(game_state: GameState) -> int:
	var total: int = 0
	for player: PlayerState in game_state.players:
		total += player.bench.size()
	return total


func _can_current_attacker_take_ko(game_state: GameState, player_index: int) -> bool:
	var player: PlayerState = game_state.players[player_index]
	var opponent: PokemonSlot = game_state.players[1 - player_index].active_pokemon
	if player.active_pokemon == null or opponent == null:
		return false
	return _predict_attack_with_board(player.active_pokemon, game_state) >= opponent.get_remaining_hp()


func _has_ready_attacker(player: PlayerState, game_state: GameState) -> bool:
	for slot: PokemonSlot in _get_all_slots(player):
		if _predict_attack_with_board(slot, game_state) > 0:
			return true
	return false


func _get_all_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


func _find_owner_index(game_state: GameState, target_slot: PokemonSlot) -> int:
	for i: int in game_state.players.size():
		var player: PlayerState = game_state.players[i]
		if player.active_pokemon == target_slot:
			return i
		for slot: PokemonSlot in player.bench:
			if slot == target_slot:
				return i
	return -1


func _estimate_heuristic_base(kind: String) -> float:
	match kind:
		"attack": return 500.0
		"attach_energy": return 220.0
		"play_trainer": return 110.0
		"play_basic_to_bench": return 180.0
		"use_ability": return 160.0
		"retreat": return 90.0
	return 10.0


func _card_name(card: Variant) -> String:
	if card is CardInstance:
		var instance := card as CardInstance
		if instance.card_data != null:
			return _canonical_name(str(instance.card_data.name))
	return ""


func _slot_name(slot: PokemonSlot) -> String:
	if slot == null or slot.get_card_data() == null:
		return ""
	return _canonical_name(str(slot.get_pokemon_name()))


func _canonical_name(name: String) -> String:
	for canonical: Variant in NAME_ALIASES.keys():
		var aliases: Array = NAME_ALIASES[canonical]
		for alias: Variant in aliases:
			if name == str(alias):
				return str(canonical)
	return name
