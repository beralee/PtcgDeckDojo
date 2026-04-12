class_name DeckStrategyPalkiaDusknoir
extends "res://scripts/ai/DeckStrategyBase.gd"


const NeuralNetInferenceScript = preload("res://scripts/ai/NeuralNetInference.gd")
const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")

const PALKIA_V := "起源帕路奇亚V"
const PALKIA_VSTAR := "起源帕路奇亚VSTAR"
const DUSKULL := "夜巡灵"
const DUSCLOPS := "彷徨夜灵"
const DUSKNOIR := "黑夜魔灵"
const FROAKIE := "呱呱泡蛙"
const GRENINJA_EX := "甲贺忍蛙ex"
const RADIANT_GRENINJA := "光辉甲贺忍蛙"
const BLOODMOON_URSALUNA_EX := "月月熊 赫月ex"

const TM_DEVOLUTION := "招式学习器·退化"
const RARE_CANDY := "神奇糖果"
const COUNTER_CATCHER := "反击捕捉器"
const PRIME_CATCHER := "顶尖捕捉器"
const NIGHT_STRETCHER := "夜间担架"
const BUDDY_BUDDY_POFFIN := "友好宝芬"

const WATER_ENERGY := "W"

var _value_net: RefCounted = null


func get_strategy_id() -> String:
	return "palkia_dusknoir"


func get_signature_names() -> Array[String]:
	return [PALKIA_VSTAR, DUSKNOIR, DUSKULL]


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
	var basics: Array[int] = []
	for i: int in player.hand.size():
		var card: CardInstance = player.hand[i]
		if card != null and card.is_basic_pokemon():
			basics.append(i)
	if basics.is_empty():
		return {}

	var active_idx: int = basics[0]
	var active_score: int = -999
	for hand_index: int in basics:
		var score: int = _opening_active_priority(_card_name(player.hand[hand_index]))
		if score > active_score:
			active_idx = hand_index
			active_score = score

	var bench_pairs: Array[Dictionary] = []
	for hand_index: int in basics:
		if hand_index == active_idx:
			continue
		bench_pairs.append({
			"idx": hand_index,
			"score": _opening_bench_priority(_card_name(player.hand[hand_index])),
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
	var kind: String = str(action.get("kind", ""))
	match kind:
		"play_basic_to_bench":
			return float(_opening_bench_priority(_card_name(action.get("card"))))
		"evolve":
			return _score_evolve(action, player)
		"attach_energy":
			return _score_attach_energy(action, game_state, player, player_index)
		"play_trainer":
			return _score_trainer(action, game_state, player, player_index)
		"use_ability":
			return _score_ability(action, game_state, player_index)
		"attack":
			return _score_attack(action, game_state, player_index)
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
	var opponent: PlayerState = game_state.players[1 - player_index]
	var score: float = 0.0
	score += float(_count_name_on_field(player, PALKIA_VSTAR)) * 170.0
	score += float(_count_name_on_field(player, PALKIA_V)) * 90.0
	score += float(_count_name_on_field(player, DUSKULL)) * 60.0
	score += float(_count_name_on_field(player, DUSCLOPS)) * 95.0
	score += float(_count_name_on_field(player, DUSKNOIR)) * 130.0
	score += float(_count_high_value_counter_targets(opponent)) * 110.0
	return score


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_top_card() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	if _slot_name(slot) == PALKIA_VSTAR:
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
		return 160 if str(card.card_data.energy_provides) == WATER_ENERGY else 100
	if name in [DUSKULL, FROAKIE]:
		return 120
	if name == TM_DEVOLUTION:
		return 15
	if name in [PALKIA_VSTAR, DUSKNOIR]:
		return 5
	return 60


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return get_discard_priority(card)
	var opponent: PlayerState = game_state.players[1 - player_index]
	if _card_name(card) == TM_DEVOLUTION and _count_evolved_targets(opponent) > 0:
		return 10
	return get_discard_priority(card)


func get_search_priority(card: CardInstance) -> int:
	var name: String = _card_name(card)
	if name == PALKIA_VSTAR:
		return 100
	if name == DUSKNOIR:
		return 95
	if name == DUSCLOPS:
		return 90
	if name == DUSKULL:
		return 85
	if name == PALKIA_V:
		return 80
	if name == TM_DEVOLUTION:
		return 72
	return 25


func score_interaction_target(item: Variant, step: Dictionary, _context: Dictionary = {}) -> float:
	var step_id: String = str(step.get("id", ""))
	if item is CardInstance:
		var card := item as CardInstance
		if step_id in ["search_pokemon", "search_cards", "basic_pokemon"]:
			return float(get_search_priority(card))
		if step_id in ["discard_card", "discard_cards"]:
			return float(get_discard_priority(card))
		return float(get_search_priority(card))
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if step_id in ["damage_counter_target", "devolution_target"]:
			return _score_counter_target(slot)
		if step_id in ["attach_energy_target", "energy_target"]:
			return _score_attach_target(slot)
	return 0.0


func _score_evolve(action: Dictionary, player: PlayerState) -> float:
	var name: String = _card_name(action.get("card"))
	if name == PALKIA_VSTAR:
		return 420.0 if _count_name_on_field(player, PALKIA_VSTAR) == 0 else 220.0
	if name == DUSKNOIR:
		return 350.0
	if name == DUSCLOPS:
		return 260.0
	if name == GRENINJA_EX:
		return 180.0
	return 90.0


func _score_attach_energy(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int) -> float:
	var slot: PokemonSlot = action.get("target_slot")
	var card: CardInstance = action.get("card")
	if slot == null or card == null or card.card_data == null:
		return 0.0
	var energy_type: String = str(card.card_data.energy_provides)
	if energy_type != WATER_ENERGY:
		return 25.0
	if _has_high_value_spread_line(game_state, player_index):
		if _slot_name(slot) == PALKIA_VSTAR:
			return 180.0
		return 120.0
	if _slot_name(slot) in [PALKIA_V, PALKIA_VSTAR]:
		return 340.0
	if _slot_name(slot) == GRENINJA_EX:
		return 220.0
	return 80.0


func _score_trainer(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int) -> float:
	var name: String = _card_name(action.get("card"))
	var opponent: PlayerState = game_state.players[1 - player_index]
	if name == TM_DEVOLUTION:
		var value: float = _score_devolution_line(opponent)
		if value > 0.0:
			return value
		return 120.0
	if name == RARE_CANDY:
		if _count_name_on_field(player, DUSKULL) > 0 and _count_name_on_field(player, DUSKNOIR) == 0:
			return 280.0
		return 90.0
	if name == COUNTER_CATCHER or name == PRIME_CATCHER:
		return 320.0 if _count_high_value_counter_targets(opponent) > 0 else 150.0
	if name == NIGHT_STRETCHER:
		return 220.0 if _has_recoverable_spread_piece(player) else 90.0
	if name == BUDDY_BUDDY_POFFIN:
		return 210.0 if player.bench.size() < 4 and _count_name_on_field(player, DUSKULL) == 0 else 110.0
	return 70.0


func _score_ability(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var slot: PokemonSlot = action.get("source_slot")
	if slot == null:
		return 0.0
	var name: String = _slot_name(slot)
	if name == DUSKNOIR or name == DUSCLOPS:
		return _best_counter_target_score(game_state.players[1 - player_index])
	if name == RADIANT_GRENINJA:
		return 180.0
	return 40.0


func _score_attack(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var player: PlayerState = game_state.players[player_index]
	var active: PokemonSlot = player.active_pokemon
	if active == null:
		return 0.0
	var opponent: PokemonSlot = game_state.players[1 - player_index].active_pokemon
	var projected_damage: int = int(action.get("projected_damage", 0))
	if projected_damage <= 0 and _slot_name(active) == PALKIA_VSTAR:
		projected_damage = 60 + _count_total_bench(game_state) * 20
	if projected_damage <= 0:
		projected_damage = int(_predict_generic_attack(active).get("damage", 0))
	var base: float = 240.0
	if opponent != null and projected_damage >= opponent.get_remaining_hp():
		base += 520.0
	elif projected_damage > 0:
		base += 150.0
	if _has_high_value_spread_line(game_state, player_index):
		base += 100.0
	return base


func _score_retreat(game_state: GameState, player: PlayerState, player_index: int) -> float:
	if player.active_pokemon == null:
		return 0.0
	if _slot_name(player.active_pokemon) in [DUSKULL, RADIANT_GRENINJA] and _has_ready_palkia(player, game_state, player_index):
		return 190.0
	return 70.0


func _opening_active_priority(name: String) -> int:
	if name == PALKIA_V:
		return 100
	if name == DUSKULL:
		return 75
	if name == FROAKIE:
		return 65
	if name == RADIANT_GRENINJA:
		return 55
	return 25


func _opening_bench_priority(name: String) -> int:
	if name == DUSKULL:
		return 95
	if name == PALKIA_V:
		return 90
	if name == FROAKIE:
		return 70
	if name == RADIANT_GRENINJA:
		return 60
	return 0


func _score_devolution_line(opponent: PlayerState) -> float:
	var best: float = 0.0
	for slot: PokemonSlot in _get_all_slots(opponent):
		if slot == null or slot.get_top_card() == null:
			continue
		var card_data: CardData = slot.get_card_data()
		if card_data == null or card_data.stage in ["", "Basic"]:
			continue
		var score: float = 300.0 + float(slot.damage_counters)
		if slot.damage_counters >= slot.get_remaining_hp():
			score += 200.0
		if card_data.stage == "Stage 2":
			score += 120.0
		best = maxf(best, score)
	return best


func _score_counter_target(slot: PokemonSlot) -> float:
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var data: CardData = slot.get_card_data()
	if data == null:
		return 0.0
	var score: float = float(slot.damage_counters) * 1.5
	if data.stage != "Basic":
		score += 120.0
	if str(data.mechanic) in ["ex", "V"]:
		score += 120.0
	score += float(slot.get_prize_count()) * 40.0
	if slot.damage_counters > 0:
		score += 60.0
	return score


func _score_attach_target(slot: PokemonSlot) -> float:
	var name: String = _slot_name(slot)
	if name == PALKIA_VSTAR or name == PALKIA_V:
		return 340.0
	if name == GRENINJA_EX:
		return 220.0
	if name == DUSKNOIR or name == DUSCLOPS:
		return 160.0
	return 70.0


func _count_name_on_field(player: PlayerState, target_name: String) -> int:
	var count: int = 0
	if player.active_pokemon != null and _slot_is(player.active_pokemon, [target_name]):
		count += 1
	for slot: PokemonSlot in player.bench:
		if slot != null and _slot_is(slot, [target_name]):
			count += 1
	return count


func _count_evolved_targets(player: PlayerState) -> int:
	var count: int = 0
	for slot: PokemonSlot in _get_all_slots(player):
		if slot != null and slot.get_card_data() != null and slot.get_card_data().stage != "Basic":
			count += 1
	return count


func _count_high_value_counter_targets(player: PlayerState) -> int:
	var count: int = 0
	for slot: PokemonSlot in _get_all_slots(player):
		if _score_counter_target(slot) >= 250.0:
			count += 1
	return count


func _best_counter_target_score(player: PlayerState) -> float:
	var best: float = 0.0
	for slot: PokemonSlot in _get_all_slots(player):
		best = maxf(best, _score_counter_target(slot))
	return best


func _has_high_value_spread_line(game_state: GameState, player_index: int) -> bool:
	var opponent: PlayerState = game_state.players[1 - player_index]
	return _score_devolution_line(opponent) >= 500.0 or _best_counter_target_score(opponent) >= 250.0


func _has_recoverable_spread_piece(player: PlayerState) -> bool:
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and _card_name(card) in [DUSKULL, DUSCLOPS, DUSKNOIR]:
			return true
	return false


func _has_ready_palkia(player: PlayerState, game_state: GameState, player_index: int) -> bool:
	for slot: PokemonSlot in _get_all_slots(player):
		if slot == null:
			continue
		if _slot_name(slot) not in [PALKIA_V, PALKIA_VSTAR]:
			continue
		var predicted: int = 0
		if _slot_name(slot) == PALKIA_VSTAR:
			predicted = 60 + _count_total_bench(game_state) * 20
		else:
			predicted = int(_predict_generic_attack(slot).get("damage", 0))
		if predicted > 0:
			return true
	return false


func _predict_generic_attack(slot: PokemonSlot) -> Dictionary:
	if slot == null or slot.get_top_card() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var attached: int = slot.attached_energy.size()
	var best_damage: int = 0
	var can_attack: bool = false
	for attack: Dictionary in slot.get_attacks():
		var cost: String = str(attack.get("cost", ""))
		var damage_text: String = str(attack.get("damage", "0")).replace("x", "").replace("×", "").replace("+", "")
		var damage: int = int(damage_text) if damage_text.is_valid_int() else 0
		if attached >= cost.length():
			can_attack = true
			best_damage = maxi(best_damage, damage)
	return {"damage": best_damage, "can_attack": can_attack, "description": ""}


func _count_total_bench(game_state: GameState) -> int:
	var total: int = 0
	for player: PlayerState in game_state.players:
		total += player.bench.size()
	return total


func _get_all_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


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
			return str(instance.card_data.name)
	return ""
