class_name LLMDecisionTreeExecutor
extends RefCounted

const ACTION_FIELDS: Array[String] = [
	"card", "energy_type", "target", "position", "pokemon", "ability",
	"bench_target", "bench_position", "attack_name", "discard_energy_type",
	"search_target", "discard_choice",
]

const VALID_ACTION_TYPES: Dictionary = {
	"action_ref": true,
	"play_basic_to_bench": true,
	"attach_energy": true,
	"attach_tool": true,
	"evolve": true,
	"play_trainer": true,
	"play_stadium": true,
	"use_ability": true,
	"retreat": true,
	"attack": true,
	"end_turn": true,
}


func select_action_queue(tree: Dictionary, game_state: GameState, player_index: int) -> Array[Dictionary]:
	if tree.is_empty() or game_state == null:
		return []
	if player_index < 0 or player_index >= game_state.players.size():
		return []
	var queue: Array[Dictionary] = []
	_collect_from_node(tree, game_state, player_index, queue, 0)
	return queue


func normalize_action(raw: Variant) -> Dictionary:
	if raw is String:
		var raw_id: String = str(raw).strip_edges()
		if raw_id == "":
			return {}
		return {"type": "action_ref", "action_id": raw_id}
	if not (raw is Dictionary):
		return {}
	var raw_dict: Dictionary = raw
	var action_id: String = str(raw_dict.get("id", raw_dict.get("action_id", ""))).strip_edges()
	var action_type: String = str(raw_dict.get("type", "")).strip_edges()
	if action_type == "" and action_id != "":
		action_type = "action_ref"
	if not bool(VALID_ACTION_TYPES.get(action_type, false)):
		return {}
	var parsed: Dictionary = {"type": action_type}
	if action_id != "":
		parsed["action_id"] = action_id
	for key: String in ACTION_FIELDS:
		var val: String = str(raw.get(key, "")).strip_edges()
		if val != "":
			parsed[key] = val
	var interactions: Variant = raw.get("interactions", {})
	if interactions is Dictionary:
		parsed["interactions"] = (interactions as Dictionary).duplicate(true)
	var selection_policy: Variant = raw.get("selection_policy", {})
	if selection_policy is Dictionary:
		parsed["selection_policy"] = (selection_policy as Dictionary).duplicate(true)
	if action_type == "attach_energy" and str(parsed.get("energy_type", "")) == "":
		return {}
	return parsed


func normalize_actions(raw_actions: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (raw_actions is Array):
		return result
	for raw: Variant in raw_actions:
		var parsed := normalize_action(raw)
		if not parsed.is_empty():
			result.append(parsed)
	return result


func _collect_from_node(
	node: Dictionary,
	game_state: GameState,
	player_index: int,
	queue: Array[Dictionary],
	depth: int
) -> void:
	if depth > 8:
		return
	queue.append_array(normalize_actions(node.get("actions", [])))
	var selected_branch: Dictionary = _select_branch(node.get("branches", node.get("children", [])), game_state, player_index)
	if selected_branch.is_empty():
		queue.append_array(normalize_actions(node.get("fallback_actions", node.get("fallback", []))))
		return
	queue.append_array(normalize_actions(selected_branch.get("actions", [])))
	var next_node: Variant = selected_branch.get("then", {})
	if next_node is Dictionary:
		_collect_from_node(next_node, game_state, player_index, queue, depth + 1)
	elif selected_branch.has("branches") or selected_branch.has("children") or selected_branch.has("fallback_actions"):
		_collect_from_node(selected_branch, game_state, player_index, queue, depth + 1)


func _select_branch(raw_branches: Variant, game_state: GameState, player_index: int) -> Dictionary:
	if not (raw_branches is Array):
		return {}
	for raw: Variant in raw_branches:
		if not (raw is Dictionary):
			continue
		var branch: Dictionary = raw
		if _conditions_match(branch.get("when", branch.get("conditions", [])), game_state, player_index):
			return branch
	return {}


func _conditions_match(raw_conditions: Variant, game_state: GameState, player_index: int) -> bool:
	if raw_conditions == null:
		return true
	if raw_conditions is Dictionary:
		return _condition_matches(raw_conditions, game_state, player_index)
	if not (raw_conditions is Array):
		return false
	for raw: Variant in raw_conditions:
		if not (raw is Dictionary):
			return false
		if not _condition_matches(raw, game_state, player_index):
			return false
	return true


func _condition_matches(condition: Dictionary, game_state: GameState, player_index: int) -> bool:
	var fact: String = str(condition.get("fact", condition.get("type", ""))).strip_edges()
	var expected: bool = bool(condition.get("value", true))
	var actual: bool = false
	match fact:
		"always":
			actual = true
		"can_attack":
			actual = not game_state.is_first_turn_for_player(player_index) or player_index != game_state.first_player_index
		"can_use_supporter":
			actual = not game_state.supporter_used_this_turn and (not game_state.is_first_turn_for_player(player_index) or player_index != game_state.first_player_index)
		"energy_not_attached":
			actual = not game_state.energy_attached_this_turn
		"energy_attached_this_turn":
			actual = game_state.energy_attached_this_turn
		"supporter_not_used":
			actual = not game_state.supporter_used_this_turn
		"supporter_used_this_turn":
			actual = game_state.supporter_used_this_turn
		"retreat_not_used":
			actual = not game_state.retreat_used_this_turn
		"retreat_used_this_turn":
			actual = game_state.retreat_used_this_turn
		"hand_has_card":
			actual = _zone_has_card(game_state.players[player_index].hand, condition, int(condition.get("min_count", 1)))
		"discard_has_card":
			actual = _zone_has_card(game_state.players[player_index].discard_pile, condition, int(condition.get("min_count", 1)))
		"hand_has_type":
			actual = _hand_has_type(game_state.players[player_index], condition, int(condition.get("min_count", 1)))
		"discard_basic_energy_count_at_least":
			actual = _basic_energy_count(game_state.players[player_index].discard_pile, str(condition.get("energy_type", ""))) >= int(condition.get("count", 1))
		"active_has_energy_at_least":
			actual = _active_energy_count(game_state.players[player_index], str(condition.get("energy_type", ""))) >= int(condition.get("count", 1))
		"active_attack_ready":
			actual = _active_attack_ready(game_state.players[player_index], str(condition.get("attack_name", "")))
		"has_bench_space":
			actual = not game_state.players[player_index].is_bench_full()
		_:
			return false
	return actual == expected


func _zone_has_card(cards: Array[CardInstance], condition: Dictionary, min_count: int) -> bool:
	var query: String = str(condition.get("card", condition.get("name", ""))).strip_edges()
	if query == "":
		return false
	var count: int = 0
	for card: CardInstance in cards:
		if card != null and card.card_data != null and _card_matches(card.card_data, query):
			count += 1
	return count >= max(1, min_count)


func _hand_has_type(player: PlayerState, condition: Dictionary, min_count: int) -> bool:
	var card_type: String = str(condition.get("card_type", "")).strip_edges().to_lower()
	var energy_type: String = str(condition.get("energy_type", "")).strip_edges()
	if card_type == "" and energy_type == "":
		return false
	var count: int = 0
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		if card_type != "" and not str(card.card_data.card_type).to_lower().contains(card_type):
			continue
		if energy_type != "" and not _energy_matches(str(card.card_data.energy_provides), energy_type):
			continue
		count += 1
	return count >= max(1, min_count)


func _basic_energy_count(cards: Array[CardInstance], energy_type: String) -> int:
	var count: int = 0
	for card: CardInstance in cards:
		if card == null or card.card_data == null or not card.card_data.is_energy():
			continue
		if energy_type != "" and not _energy_matches(str(card.card_data.energy_provides), energy_type):
			continue
		count += 1
	return count


func _active_energy_count(player: PlayerState, energy_type: String) -> int:
	if player.active_pokemon == null:
		return 0
	var count: int = 0
	for card: CardInstance in player.active_pokemon.attached_energy:
		if card == null or card.card_data == null:
			continue
		if energy_type != "" and not _energy_matches(str(card.card_data.energy_provides), energy_type):
			continue
		count += 1
	return count


func _active_attack_ready(player: PlayerState, attack_name: String) -> bool:
	if player.active_pokemon == null or player.active_pokemon.get_card_data() == null:
		return false
	var attacks: Array = player.active_pokemon.get_card_data().attacks
	for attack: Dictionary in attacks:
		if attack_name != "" and not _text_matches(str(attack.get("name", "")), attack_name):
			continue
		if _slot_can_pay_cost(player.active_pokemon, str(attack.get("cost", ""))):
			return true
	return false


func _slot_can_pay_cost(slot: PokemonSlot, cost: String) -> bool:
	var counts: Dictionary = {}
	var total: int = 0
	for card: CardInstance in slot.attached_energy:
		if card == null or card.card_data == null:
			continue
		var provides: String = str(card.card_data.energy_provides)
		counts[provides] = int(counts.get(provides, 0)) + 1
		total += 1
	for i: int in cost.length():
		var symbol: String = cost.substr(i, 1)
		if symbol == "C":
			continue
		if int(counts.get(symbol, 0)) <= 0:
			return false
		counts[symbol] = int(counts.get(symbol, 0)) - 1
		total -= 1
	var colorless_needed: int = cost.count("C")
	return total >= colorless_needed


func _card_matches(card_data: CardData, query: String) -> bool:
	if _text_matches(str(card_data.name), query):
		return true
	return _text_matches(str(card_data.name_en), query)


func _text_matches(value: String, query: String) -> bool:
	var lhs: String = value.strip_edges().to_lower()
	var rhs: String = query.strip_edges().to_lower()
	if lhs == "" or rhs == "":
		return false
	return lhs.contains(rhs) or rhs.contains(lhs)


func _energy_matches(provides: String, query: String) -> bool:
	var lhs: String = provides.strip_edges().to_lower()
	var rhs: String = query.strip_edges().to_lower()
	if lhs == "" or rhs == "":
		return false
	return lhs == rhs or _energy_word_to_code(rhs) == provides


func _energy_word_to_code(value: String) -> String:
	match value:
		"lightning", "electric", "l":
			return "L"
		"fighting", "f":
			return "F"
		"grass", "g":
			return "G"
		"fire", "r":
			return "R"
		"water", "w":
			return "W"
		"psychic", "p":
			return "P"
		"dark", "d":
			return "D"
		"metal", "m":
			return "M"
	return ""
