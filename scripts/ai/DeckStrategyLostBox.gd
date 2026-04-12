class_name DeckStrategyLostBox
extends "res://scripts/ai/DeckStrategyBase.gd"


const NeuralNetInferenceScript = preload("res://scripts/ai/NeuralNetInference.gd")
const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")

const COMFEY := "Comfey"
const CRAMORANT := "Cramorant"
const COLRESS := "Colress's Experiment"
const MIRAGE_GATE := "Mirage Gate"
const SWITCH_CART := "Switch Cart"
const RESCUE_BOARD := "Rescue Board"
const NEST_BALL := "Nest Ball"
const BUDDY_BUDDY_POFFIN := "Buddy-Buddy Poffin"
const DUNSPARCE := "Dunsparce"
const DUDUNSPARCE := "Dudunsparce"
const IRON_BUNDLE := "Iron Bundle"
const RADIANT_GRENINJA := "Radiant Greninja"
const ROTOM_V := "Rotom V"
const ROARING_MOON_EX := "Roaring Moon ex"
const RAIKOU_V := "Raikou V"
const IRON_HANDS_EX := "Iron Hands ex"
const BLOODMOON_URSALUNA_EX := "Bloodmoon Ursaluna ex"
const BOSS_ORDERS := "Boss's Orders"
const ROXANNE := "Roxanne"
const SECRET_BOX := "Secret Box"
const SUPER_ROD := "Super Rod"
const LOST_VACUUM := "Lost Vacuum"
const TEMPLE_OF_SINNOH := "Temple of Sinnoh"
const TOWN_STORE := "Town Store"

const WATER_ENERGY := "W"
const LIGHTNING_ENERGY := "L"
const DARK_ENERGY := "D"

const NAME_ALIASES := {
	COMFEY: [COMFEY, "花疗环环"],
	CRAMORANT: [CRAMORANT, "古月鸟"],
	COLRESS: [COLRESS, "阿克罗玛的实验"],
	MIRAGE_GATE: [MIRAGE_GATE, "幻象之门"],
	SWITCH_CART: [SWITCH_CART, "交替推车"],
	RESCUE_BOARD: [RESCUE_BOARD, "紧急滑板"],
	NEST_BALL: [NEST_BALL, "巢穴球"],
	BUDDY_BUDDY_POFFIN: [BUDDY_BUDDY_POFFIN, "友好宝芬"],
	DUNSPARCE: [DUNSPARCE, "土龙弟弟"],
	DUDUNSPARCE: [DUDUNSPARCE, "土龙节节"],
	IRON_BUNDLE: [IRON_BUNDLE, "铁包袱"],
	RADIANT_GRENINJA: [RADIANT_GRENINJA, "光辉甲贺忍蛙"],
	ROTOM_V: [ROTOM_V, "洛托姆V"],
	ROARING_MOON_EX: [ROARING_MOON_EX, "轰鸣月ex"],
	RAIKOU_V: [RAIKOU_V, "雷公V"],
	IRON_HANDS_EX: [IRON_HANDS_EX, "铁臂膀ex"],
	BLOODMOON_URSALUNA_EX: [BLOODMOON_URSALUNA_EX, "月月熊 赫月ex"],
	BOSS_ORDERS: [BOSS_ORDERS, "老大的指令"],
	ROXANNE: [ROXANNE, "杜鹃"],
	SECRET_BOX: [SECRET_BOX, "秘密箱"],
	SUPER_ROD: [SUPER_ROD, "厉害钓竿"],
	LOST_VACUUM: [LOST_VACUUM, "放逐吸尘器"],
	TEMPLE_OF_SINNOH: [TEMPLE_OF_SINNOH, "神奥神殿"],
	TOWN_STORE: [TOWN_STORE, "城镇百货"],
}

var _value_net: RefCounted = null


func get_strategy_id() -> String:
	return "lost_box"


func get_signature_names() -> Array[String]:
	return [COMFEY, "花疗环环", COLRESS, "阿克罗玛的实验", MIRAGE_GATE, "幻象之门", CRAMORANT, "古月鸟"]


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
		bench_pairs.append({"idx": idx, "score": int(entry.get("bench_priority", 0))})
	bench_pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)

	var bench_indices: Array[int] = []
	for pair: Dictionary in bench_pairs:
		if bench_indices.size() >= 4:
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
		"attach_energy":
			return _score_attach_energy(action, game_state, player_index)
		"play_trainer":
			return _score_trainer(action, game_state, player_index)
		"use_ability":
			return _score_ability(action, game_state, player_index)
		"attack":
			return _score_attack(action, game_state, player_index)
		"retreat":
			return _score_retreat(player)
	return 0.0


func score_action(action: Dictionary, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index: int = int(context.get("player_index", -1))
	return score_action_absolute(action, game_state, player_index) - _estimate_heuristic_base(str(action.get("kind", "")))


func evaluate_board(game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var lost_count: int = player.lost_zone.size()
	var score: float = float(lost_count) * 38.0
	score += float(_count_name_on_field(player, COMFEY)) * 80.0
	score += float(_count_name_on_field(player, CRAMORANT)) * 60.0
	score += float(_count_name_on_field(player, DUDUNSPARCE)) * 45.0
	score += float(_count_name_on_field(player, RADIANT_GRENINJA)) * 40.0
	if lost_count >= 4 and _count_name_on_field(player, CRAMORANT) > 0:
		score += 130.0
	if lost_count >= 7:
		score += 110.0
		if _count_name_on_field(player, IRON_HANDS_EX) > 0:
			score += 110.0
		if _count_name_on_field(player, RAIKOU_V) > 0:
			score += 70.0
		if _count_name_on_field(player, ROARING_MOON_EX) > 0:
			score += 90.0
	if player.active_pokemon != null and _slot_name(player.active_pokemon) == COMFEY and not player.bench.is_empty():
		score += 55.0
	return score


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_top_card() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var name: String = _slot_name(slot)
	var attached: int = slot.attached_energy.size()
	if name == CRAMORANT:
		return {"damage": 110, "can_attack": extra_context >= 4 or attached >= 3, "description": "Spit Innocently"}
	if name == IRON_HANDS_EX:
		return {"damage": 160, "can_attack": attached >= 3, "description": "Amp You Very Much"}
	if name == RAIKOU_V:
		return {"damage": 100, "can_attack": attached >= 1, "description": "Lightning Rondo"}
	if name == ROARING_MOON_EX:
		return {"damage": 220, "can_attack": attached >= 3, "description": "Calamity Storm"}
	if name == BLOODMOON_URSALUNA_EX:
		return {"damage": 240, "can_attack": attached >= 3, "description": "Blood Moon"}
	if name == COMFEY:
		return {"damage": 30, "can_attack": attached >= 2, "description": "Spin Attack"}
	return _predict_generic_attack(slot)


func get_discard_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	var name: String = _card_name(card)
	if card.card_data.is_energy():
		return 140
	if name in [COLRESS, MIRAGE_GATE]:
		return 10
	if name in [COMFEY, CRAMORANT]:
		return 20
	if name in [IRON_HANDS_EX, RAIKOU_V, ROARING_MOON_EX, BLOODMOON_URSALUNA_EX]:
		return 120
	return 80


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return get_discard_priority(card)
	var player: PlayerState = game_state.players[player_index]
	var name: String = _card_name(card)
	if name == NEST_BALL and player.bench.size() >= 5:
		return 190
	if name == SWITCH_CART and _count_name_on_field(player, COMFEY) <= 1:
		return 25
	return get_discard_priority(card)


func get_search_priority(card: CardInstance) -> int:
	var name: String = _card_name(card)
	if name == COMFEY:
		return 100
	if name == CRAMORANT:
		return 90
	if name == DUNSPARCE:
		return 84
	if name == RADIANT_GRENINJA:
		return 76
	if name == IRON_BUNDLE:
		return 72
	if name == ROTOM_V:
		return 68
	if name == IRON_HANDS_EX:
		return 62
	if name == RAIKOU_V:
		return 60
	if name == ROARING_MOON_EX:
		return 58
	if name == BLOODMOON_URSALUNA_EX:
		return 54
	if name == DUDUNSPARCE:
		return 48
	if name == MIRAGE_GATE:
		return 90
	if name == COLRESS:
		return 88
	return 20


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id: String = str(step.get("id", ""))
	if item is CardInstance:
		var card := item as CardInstance
		if step_id in ["search_pokemon", "basic_pokemon", "bench_pokemon", "search_cards"]:
			return float(get_search_priority(card))
		if step_id in ["discard_card", "discard_cards", "discard_energy"]:
			var game_state: GameState = context.get("game_state", null)
			var player_index: int = int(context.get("player_index", -1))
			return float(get_discard_priority_contextual(card, game_state, player_index))
		return float(get_search_priority(card))
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if step_id in ["attach_energy_target", "energy_target", "mirage_gate_assignments"]:
			return _score_attach_target(slot, context)
		if step_id in ["send_out", "pivot_target"]:
			return float(_opening_active_priority(_slot_name(slot)))
	return 0.0


func _score_attach_energy(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var slot: PokemonSlot = action.get("target_slot")
	var card: CardInstance = action.get("card")
	if slot == null or card == null or card.card_data == null:
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var lost_count: int = player.lost_zone.size()
	var energy_type: String = str(card.card_data.energy_provides)
	var name: String = _slot_name(slot)
	if energy_type == WATER_ENERGY:
		if name == RADIANT_GRENINJA:
			return 260.0
		if name == CRAMORANT:
			return 220.0 if lost_count < 4 else 120.0
		if name == COMFEY and player.active_pokemon == slot:
			return 90.0
		return 120.0
	if energy_type == LIGHTNING_ENERGY:
		if lost_count >= 7 and name == IRON_HANDS_EX:
			return 380.0
		if lost_count >= 7 and name == RAIKOU_V:
			return 320.0
		return 110.0
	if energy_type == DARK_ENERGY:
		if lost_count >= 7 and name == ROARING_MOON_EX:
			return 340.0
		return 110.0
	return 80.0


func _score_trainer(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var player: PlayerState = game_state.players[player_index]
	var lost_count: int = player.lost_zone.size()
	var name: String = _card_name(action.get("card"))
	if name == COLRESS:
		if lost_count < 7:
			return 520.0
		if lost_count < 10:
			return 360.0
		return 180.0
	if name == MIRAGE_GATE:
		if lost_count >= 7 and _has_finisher_on_field(player):
			return 500.0
		return 120.0
	if name == SWITCH_CART:
		if player.active_pokemon != null and _slot_name(player.active_pokemon) == COMFEY and not player.bench.is_empty():
			return 360.0 if lost_count >= 4 else 280.0
		return 140.0
	if name == RESCUE_BOARD:
		if _count_name_on_field(player, COMFEY) > 0:
			return 300.0
		return 130.0
	if name == SECRET_BOX:
		return 340.0 if lost_count < 7 else 220.0
	if name == NEST_BALL or name == BUDDY_BUDDY_POFFIN:
		if _count_name_on_field(player, COMFEY) < 2:
			return 300.0
		if _count_name_on_field(player, DUNSPARCE) == 0 and _count_name_on_field(player, DUDUNSPARCE) == 0:
			return 230.0
		return 150.0
	if name == SUPER_ROD:
		return 220.0 if _has_recoverable_piece(player) else 120.0
	if name == BOSS_ORDERS:
		return 280.0 if _can_take_prize_with_active(game_state, player_index) else 150.0
	if name == ROXANNE:
		return 230.0
	if name == LOST_VACUUM:
		return 180.0 if game_state.stadium_card != null else 120.0
	if name == TEMPLE_OF_SINNOH:
		return 180.0
	if name == TOWN_STORE:
		return 210.0 if not _has_name_on_field(player, RESCUE_BOARD) else 130.0
	return 70.0


func _score_ability(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var slot: PokemonSlot = action.get("source_slot")
	if slot == null:
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var name: String = _slot_name(slot)
	if name == COMFEY:
		return 400.0 if slot == player.active_pokemon else 30.0
	if name == RADIANT_GRENINJA:
		return 260.0 if _count_energy(player.hand, WATER_ENERGY) + _count_energy(player.hand, LIGHTNING_ENERGY) + _count_energy(player.hand, DARK_ENERGY) > 0 else 70.0
	if name == DUDUNSPARCE:
		return 180.0 if player.hand.size() <= 4 else 120.0
	return 40.0


func _score_attack(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var player: PlayerState = game_state.players[player_index]
	var active: PokemonSlot = player.active_pokemon
	if active == null:
		return 0.0
	var lost_count: int = player.lost_zone.size()
	var active_name: String = _slot_name(active)
	var opponent: PokemonSlot = game_state.players[1 - player_index].active_pokemon
	var projected_damage: int = int(action.get("projected_damage", 0))
	var projected_knockout: bool = bool(action.get("projected_knockout", false))
	if projected_damage <= 0:
		projected_damage = int(predict_attacker_damage(active, lost_count).get("damage", 0))
	var base: float = 160.0
	if active_name == CRAMORANT and lost_count >= 4:
		base += 280.0
	if active_name == IRON_HANDS_EX and projected_knockout:
		base += 520.0
	if active_name == ROARING_MOON_EX and projected_knockout:
		base += 440.0
	if active_name == BLOODMOON_URSALUNA_EX and projected_knockout:
		base += 420.0
	if opponent != null and projected_damage >= opponent.get_remaining_hp():
		base += 360.0
	elif projected_damage > 0:
		base += 100.0
	return base


func _score_retreat(player: PlayerState) -> float:
	if player.active_pokemon == null:
		return 0.0
	if _slot_name(player.active_pokemon) == COMFEY and not player.bench.is_empty():
		return 220.0
	return 70.0


func _opening_active_priority(name: String) -> int:
	if name == COMFEY:
		return 100
	if name == CRAMORANT:
		return 82
	if name == DUNSPARCE:
		return 74
	if name == IRON_BUNDLE:
		return 68
	if name == RADIANT_GRENINJA:
		return 58
	if name in [ROTOM_V, RAIKOU_V]:
		return 40
	return 20


func _opening_bench_priority(name: String) -> int:
	if name == COMFEY:
		return 100
	if name == CRAMORANT:
		return 90
	if name == DUNSPARCE:
		return 82
	if name == RADIANT_GRENINJA:
		return 74
	if name == IRON_BUNDLE:
		return 70
	if name == ROTOM_V:
		return 60
	if name in [IRON_HANDS_EX, RAIKOU_V]:
		return 52
	return 0


func _score_attach_target(slot: PokemonSlot, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index: int = int(context.get("player_index", -1))
	var lost_count: int = 0
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		lost_count = game_state.players[player_index].lost_zone.size()
	var source_card: CardInstance = context.get("source_card", null)
	var energy_type: String = str(source_card.card_data.energy_provides) if source_card != null and source_card.card_data != null else ""
	var name: String = _slot_name(slot)
	if energy_type == LIGHTNING_ENERGY:
		if lost_count >= 7 and name == IRON_HANDS_EX:
			return 420.0
		if lost_count >= 7 and name == RAIKOU_V:
			return 340.0
		return 80.0
	if energy_type == DARK_ENERGY:
		if lost_count >= 7 and name == ROARING_MOON_EX:
			return 380.0
		return 80.0
	if energy_type == WATER_ENERGY:
		if name == RADIANT_GRENINJA:
			return 300.0
		if name == CRAMORANT:
			return 220.0
		return 100.0
	if lost_count >= 7 and name == IRON_HANDS_EX:
		return 360.0
	if name == CRAMORANT:
		return 220.0
	if name == COMFEY:
		return 140.0
	return 60.0


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


func _has_finisher_on_field(player: PlayerState) -> bool:
	for name: String in [IRON_HANDS_EX, RAIKOU_V, ROARING_MOON_EX, BLOODMOON_URSALUNA_EX]:
		if _count_name_on_field(player, name) > 0:
			return true
	return false


func _has_recoverable_piece(player: PlayerState) -> bool:
	for card: CardInstance in player.discard_pile:
		if card == null or card.card_data == null:
			continue
		if _card_name(card) in [COMFEY, CRAMORANT, IRON_HANDS_EX, RAIKOU_V, ROARING_MOON_EX]:
			return true
	return false


func _can_take_prize_with_active(game_state: GameState, player_index: int) -> bool:
	var player: PlayerState = game_state.players[player_index]
	var opponent: PokemonSlot = game_state.players[1 - player_index].active_pokemon
	if player.active_pokemon == null or opponent == null:
		return false
	var damage: int = int(predict_attacker_damage(player.active_pokemon, player.lost_zone.size()).get("damage", 0))
	return damage >= opponent.get_remaining_hp()


func _count_energy(cards: Array, energy_type: String) -> int:
	var count: int = 0
	for item: Variant in cards:
		if item is CardInstance:
			var card := item as CardInstance
			if card.card_data != null and card.card_data.is_energy() and str(card.card_data.energy_provides) == energy_type:
				count += 1
	return count


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
