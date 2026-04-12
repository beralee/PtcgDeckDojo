class_name DeckStrategyIronThorns
extends "res://scripts/ai/DeckStrategyBase.gd"


const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")

const IRON_THORNS_EX := "Iron Thorns ex"
const DITTO := "Ditto"

const FUTURE_BOOSTER := "Future Booster Energy Capsule"
const TECHNO_RADAR := "Techno Radar"
const TM_TURBO_ENERGIZE := "Technical Machine: Turbo Energize"
const JUDGE := "Judge"
const CRUSHING_HAMMER := "Crushing Hammer"
const LOST_CITY := "Lost City"
const PROFESSORS_RESEARCH := "Professor's Research"
const ARVEN := "Arven"
const PRIME_CATCHER := "Prime Catcher"
const CANCELING_COLOGNE := "Canceling Cologne"
const COLRESS_TENACITY := "Colress's Tenacity"

const NAME_ALIASES := {
	IRON_THORNS_EX: [IRON_THORNS_EX, "铁荆棘ex"],
	DITTO: [DITTO, "百变怪"],
	FUTURE_BOOSTER: [FUTURE_BOOSTER, "驱劲能量 未来"],
	TECHNO_RADAR: [TECHNO_RADAR, "高科技雷达"],
	TM_TURBO_ENERGIZE: [TM_TURBO_ENERGIZE, "招式学习器 能量涡轮"],
	JUDGE: [JUDGE, "裁判"],
	CRUSHING_HAMMER: [CRUSHING_HAMMER, "粉碎之锤"],
	LOST_CITY: [LOST_CITY, "放逐市"],
	PROFESSORS_RESEARCH: [PROFESSORS_RESEARCH, "博士的研究"],
	ARVEN: [ARVEN, "派帕"],
	PRIME_CATCHER: [PRIME_CATCHER, "顶尖捕捉器"],
	CANCELING_COLOGNE: [CANCELING_COLOGNE, "清除古龙水"],
	COLRESS_TENACITY: [COLRESS_TENACITY, "阿克罗玛的执念"],
}


func get_strategy_id() -> String:
	return "iron_thorns"


func get_signature_names() -> Array[String]:
	return [IRON_THORNS_EX, "铁荆棘ex", JUDGE, "裁判", CRUSHING_HAMMER, "粉碎之锤"]


func get_state_encoder_class() -> GDScript:
	return StateEncoderScript


func load_value_net(_path: String) -> bool:
	return false


func get_value_net() -> RefCounted:
	return null


func get_mcts_config() -> Dictionary:
	return {
		"branch_factor": 4,
		"max_actions_per_turn": 9,
		"rollouts_per_sequence": 0,
		"time_budget_ms": 2600,
	}


func plan_opening_setup(player: PlayerState) -> Dictionary:
	var basics: Array[Dictionary] = []
	for i: int in player.hand.size():
		var card: CardInstance = player.hand[i]
		if _is_basic_pokemon(card):
			basics.append({
				"index": i,
				"priority": _setup_priority(_card_name(card)),
			})
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
	var player: PlayerState = game_state.players[player_index]
	match str(action.get("kind", "")):
		"play_basic_to_bench":
			return _score_bench_basic(action.get("card"))
		"attach_energy":
			return _score_attach_energy(action.get("card"), action.get("target_slot"), player)
		"attach_tool":
			return _score_attach_tool(action.get("card"), action.get("target_slot"), player)
		"play_trainer":
			return _score_trainer(action.get("card"), game_state, player_index)
		"attack", "granted_attack":
			return _score_attack(action)
		"retreat":
			return 90.0
	return 0.0


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
	var opponent: PlayerState = game_state.players[1 - player_index]
	var score: float = 0.0
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null:
			continue
		if _slot_matches(slot, IRON_THORNS_EX):
			score += 140.0
			score += float(slot.attached_energy.size()) * 80.0
			if slot == player.active_pokemon:
				score += 280.0
				if slot.attached_tool != null and _card_is(slot.attached_tool, FUTURE_BOOSTER):
					score += 80.0
		elif slot == player.active_pokemon:
			score -= 120.0
	if _slot_matches(player.active_pokemon, IRON_THORNS_EX) and _opponent_rule_box_active(opponent):
		score += 160.0
	return score


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var attached: int = slot.attached_energy.size() + extra_context
	var best_damage: int = 0
	var can_attack: bool = false
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
	var name: String = _card_name(card)
	if name in [FUTURE_BOOSTER, JUDGE, CRUSHING_HAMMER, TM_TURBO_ENERGIZE]:
		return 12
	if name == DITTO:
		return 180
	if card.card_data.card_type == "Basic Energy":
		return 110
	return 80


func get_discard_priority_contextual(card: CardInstance, _game_state: GameState, _player_index: int) -> int:
	return get_discard_priority(card)


func get_search_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	var name: String = _card_name(card)
	if name == IRON_THORNS_EX:
		return 100
	if name == FUTURE_BOOSTER:
		return 80
	if name == TM_TURBO_ENERGIZE:
		return 76
	if name == DITTO:
		return 60
	return 20


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id: String = str(step.get("id", ""))
	if item is CardInstance:
		var card := item as CardInstance
		if step_id in ["search_future_pokemon", "search_pokemon", "search_cards", "search_item", "search_tool"]:
			return float(get_search_priority(card))
		if step_id in ["discard_cards", "discard_card", "discard_energy"]:
			return float(get_discard_priority_contextual(card, context.get("game_state"), int(context.get("player_index", -1))))
		if _card_is(card, FUTURE_BOOSTER):
			return 300.0
		if _card_is(card, TM_TURBO_ENERGIZE):
			return 260.0
		return 40.0
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if _slot_matches(slot, IRON_THORNS_EX):
			if context.get("game_state", null) != null and int(context.get("player_index", -1)) >= 0:
				var game_state: GameState = context.get("game_state")
				var player_index: int = int(context.get("player_index", -1))
				if slot == game_state.players[player_index].active_pokemon:
					return 320.0
			return 240.0
		return 40.0
	return 0.0


func _score_bench_basic(card: CardInstance) -> float:
	if card == null or card.card_data == null:
		return 0.0
	return float(_setup_priority(_card_name(card)) * 3)


func _score_attach_energy(card: CardInstance, target_slot: PokemonSlot, player: PlayerState) -> float:
	if card == null or card.card_data == null or target_slot == null:
		return 0.0
	if _slot_matches(target_slot, IRON_THORNS_EX):
		if target_slot == player.active_pokemon:
			return 390.0 if target_slot.attached_energy.size() <= 1 else 320.0
		return 260.0
	return 40.0


func _score_attach_tool(card: CardInstance, target_slot: PokemonSlot, player: PlayerState) -> float:
	if card == null or target_slot == null:
		return 0.0
	if _card_is(card, TM_TURBO_ENERGIZE):
		if _slot_matches(target_slot, IRON_THORNS_EX) and target_slot == player.active_pokemon:
			return 340.0 if target_slot.attached_energy.size() <= 1 else 220.0
		if _slot_matches(target_slot, IRON_THORNS_EX):
			return 240.0
		return 80.0
	if _card_is(card, FUTURE_BOOSTER):
		if _slot_matches(target_slot, IRON_THORNS_EX):
			return 380.0 if target_slot == player.active_pokemon else 280.0
		return -120.0
	return 50.0


func _score_trainer(card: CardInstance, game_state: GameState, player_index: int) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	var name: String = _card_name(card)
	if name == JUDGE:
		return 500.0 if _slot_matches(player.active_pokemon, IRON_THORNS_EX) and _opponent_rule_box_active(opponent) else 340.0
	if name == CRUSHING_HAMMER:
		return 450.0 if _opponent_has_attached_energy(opponent) else 320.0
	if name == LOST_CITY:
		return 320.0 if _slot_matches(player.active_pokemon, IRON_THORNS_EX) else 220.0
	if name == ARVEN:
		if _needs_turbo_bridge(player):
			return 400.0
		if _first_untooled_thorns(player) != null:
			return 360.0
		return 240.0
	if name == TECHNO_RADAR:
		return 300.0 if _count_matching_on_field(player, IRON_THORNS_EX) < 2 else 220.0
	if name == TM_TURBO_ENERGIZE:
		return 320.0 if _needs_turbo_bridge(player) else 180.0
	if name == PRIME_CATCHER:
		return 300.0
	if name == CANCELING_COLOGNE:
		return 180.0
	if name == COLRESS_TENACITY:
		return 240.0 if game_state.stadium_card == null else 170.0
	if name == PROFESSORS_RESEARCH:
		return 120.0
	return 160.0


func _score_attack(action: Dictionary) -> float:
	var projected_damage: int = int(action.get("projected_damage", 0))
	if bool(action.get("projected_knockout", false)):
		return 820.0
	if projected_damage >= 140:
		return 680.0
	return 520.0


func _setup_priority(name: String) -> int:
	if name == IRON_THORNS_EX:
		return 100
	if name == DITTO:
		return 60
	return 25


func _count_matching_on_field(player: PlayerState, target_name: String) -> int:
	var count: int = 0
	for slot: PokemonSlot in player.get_all_pokemon():
		if _slot_matches(slot, target_name):
			count += 1
	return count


func _first_untooled_thorns(player: PlayerState) -> PokemonSlot:
	for slot: PokemonSlot in player.get_all_pokemon():
		if _slot_matches(slot, IRON_THORNS_EX) and slot.attached_tool == null:
			return slot
	return null


func _needs_turbo_bridge(player: PlayerState) -> bool:
	if player.active_pokemon == null or not _slot_matches(player.active_pokemon, IRON_THORNS_EX):
		return false
	if player.active_pokemon.attached_energy.size() >= 2:
		return false
	return not player.bench.is_empty()


func _opponent_rule_box_active(opponent: PlayerState) -> bool:
	if opponent == null or opponent.active_pokemon == null:
		return false
	var cd: CardData = opponent.active_pokemon.get_card_data()
	return cd != null and cd.is_rule_box_pokemon() and not cd.is_future_pokemon()


func _opponent_has_attached_energy(opponent: PlayerState) -> bool:
	if opponent == null:
		return false
	for slot: PokemonSlot in opponent.get_all_pokemon():
		if slot != null and not slot.attached_energy.is_empty():
			return true
	return false


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


func _is_basic_pokemon(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.card_type == "Pokemon" and str(card.card_data.stage) == "Basic"


func _slot_matches(slot: PokemonSlot, canonical: String) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	return _canonical_name(str(slot.get_card_data().name)) == canonical or _canonical_name(str(slot.get_card_data().name_en)) == canonical


func _card_is(card: CardInstance, canonical: String) -> bool:
	return card != null and card.card_data != null and _canonical_name(str(card.card_data.name)) == canonical


func _card_name(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	return _canonical_name(str(card.card_data.name))


func _canonical_name(name: String) -> String:
	for canonical: Variant in NAME_ALIASES.keys():
		var aliases: Array = NAME_ALIASES[canonical]
		for alias: Variant in aliases:
			if name == str(alias):
				return str(canonical)
	return name


func _parse_damage_value(damage_text: String) -> int:
	var digits := ""
	for i: int in damage_text.length():
		var ch := damage_text[i]
		if ch >= "0" and ch <= "9":
			digits += ch
	return int(digits) if digits != "" else 0
