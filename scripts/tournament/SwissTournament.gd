class_name SwissTournament
extends RefCounted

const POINTS_WIN := 3
const POINTS_DRAW := 1
const POINTS_LOSS := 0
const AIFixedDeckOrderRegistryScript := preload("res://scripts/ai/AIFixedDeckOrderRegistry.gd")

const DEFAULT_AI_DECK_POOL: Array[int] = [575716, 575720, 569061, 575657, 578647, 575718]
const LLM_RAGING_BOLT_DECK_ID := 575718
const LLM_OPPONENT_PROBABILITY := 0.12

const DECK_RATINGS := {
	575716: 1690.0,  # Charizard / Pidgeot
	575720: 1630.0,  # Miraidon
	569061: 1560.0,  # Arceus / Giratina
	575657: 1510.0,  # Lugia / Archeops
	578647: 1460.0,  # Gardevoir
	575718: 1430.0,  # Raging Bolt / Ogerpon
}

const NAME_PREFIXES := [
	"Alpha", "Bravo", "Cinder", "Drift", "Echo", "Flint", "Gale", "Harbor",
	"Iris", "Jade", "Kite", "Lumen", "Morrow", "Nova", "Orion", "Pine",
]

const NAME_SUFFIXES := [
	"Fox", "Vale", "Stone", "Ray", "Ward", "Lake", "Bloom", "Rune",
	"Crest", "Dawn", "Ash", "Quill", "Brook", "Skye", "Reed", "Frost",
]

var tournament_size: int = 0
var total_rounds: int = 0
var current_round: int = 0
var player_participant_id: int = -1
var player_name: String = ""
var player_deck_id: int = 0
var participants: Array[Dictionary] = []
var current_pairings: Array[Dictionary] = []
var current_player_pairing: Dictionary = {}
var last_round_summary: Dictionary = {}
var finished: bool = false
var llm_opponents_enabled: bool = false

var _rng := RandomNumberGenerator.new()
var _fixed_order_registry: RefCounted = AIFixedDeckOrderRegistryScript.new()


func setup(next_player_name: String, next_player_deck_id: int, next_tournament_size: int, seed: int = 0, enable_llm_opponents: bool = false) -> void:
	player_name = next_player_name.strip_edges()
	if player_name == "":
		player_name = "玩家"
	player_deck_id = next_player_deck_id
	tournament_size = next_tournament_size
	total_rounds = rounds_for_size(tournament_size)
	llm_opponents_enabled = enable_llm_opponents
	current_round = 0
	player_participant_id = 0
	participants.clear()
	current_pairings.clear()
	current_player_pairing.clear()
	last_round_summary.clear()
	finished = false
	if seed != 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	_build_field()


func rounds_for_size(size: int) -> int:
	match size:
		16:
			return 4
		32:
			return 5
		64:
			return 6
		128:
			return 7
		_:
			return maxi(1, int(ceil(log(size) / log(2.0))))


func prepare_next_round() -> Dictionary:
	if finished:
		return {}
	if not current_pairings.is_empty() and not current_player_pairing.is_empty():
		return current_player_pairing.duplicate(true)
	current_round += 1
	current_pairings = _build_round_pairings()
	current_player_pairing = {}
	for pairing: Dictionary in current_pairings:
		if int(pairing.get("player_a_id", -1)) == player_participant_id or int(pairing.get("player_b_id", -1)) == player_participant_id:
			current_player_pairing = pairing.duplicate(true)
			break
	return current_player_pairing.duplicate(true)


func record_player_match(player_won: bool, reason: String = "") -> Dictionary:
	if current_player_pairing.is_empty():
		return {}
	var a_id := int(current_player_pairing.get("player_a_id", -1))
	var b_id := int(current_player_pairing.get("player_b_id", -1))
	if a_id < 0 or b_id < 0:
		return {}
	var winner_id := player_participant_id if player_won else (b_id if a_id == player_participant_id else a_id)
	var loser_id := b_id if winner_id == a_id else a_id
	_apply_match_result(winner_id, loser_id, "win", {
		"reason": reason,
		"simulated": false,
	})
	for i: int in current_pairings.size():
		var pairing := current_pairings[i]
		if int(pairing.get("table", -1)) == int(current_player_pairing.get("table", -2)):
			pairing["result_recorded"] = true
			pairing["winner_id"] = winner_id
			pairing["result"] = "win"
			current_pairings[i] = pairing
			break
	_simulate_remaining_pairings()
	_recompute_tiebreakers()
	var player_entry := _participant_by_id(player_participant_id)
	var opponent_id := _opponent_id_for_pairing(current_player_pairing, player_participant_id)
	var opponent_entry := _participant_by_id(opponent_id)
	var standings := get_standings()
	last_round_summary = {
		"round": current_round,
		"result": "win" if player_won else "loss",
		"reason": reason,
		"player": player_entry.duplicate(true) if not player_entry.is_empty() else {},
		"opponent": opponent_entry.duplicate(true) if not opponent_entry.is_empty() else {},
		"standings": standings,
		"is_final_round": current_round >= total_rounds,
	}
	current_pairings.clear()
	current_player_pairing.clear()
	if current_round >= total_rounds:
		finished = true
	return last_round_summary.duplicate(true)


func get_standings() -> Array[Dictionary]:
	var standings: Array[Dictionary] = []
	for participant: Dictionary in participants:
		standings.append(participant.duplicate(true))
	standings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var points_a := int(a.get("points", 0))
		var points_b := int(b.get("points", 0))
		if points_a != points_b:
			return points_a > points_b
		var opp_a := float(a.get("opponent_points", 0.0))
		var opp_b := float(b.get("opponent_points", 0.0))
		if not is_equal_approx(opp_a, opp_b):
			return opp_a > opp_b
		var wins_a := int(a.get("wins", 0))
		var wins_b := int(b.get("wins", 0))
		if wins_a != wins_b:
			return wins_a > wins_b
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	for i: int in standings.size():
		standings[i]["rank"] = i + 1
	return standings


func participant_display_name(participant_id: int) -> String:
	return str(_participant_by_id(participant_id).get("name", ""))


func participant_deck_id(participant_id: int) -> int:
	return int(_participant_by_id(participant_id).get("deck_id", 0))


func participant_ai_mode(participant_id: int) -> String:
	return str(_participant_by_id(participant_id).get("ai_mode", "weak"))


func participant_deck_name(participant_id: int) -> String:
	var deck_id := participant_deck_id(participant_id)
	var deck := CardDatabase.get_ai_deck(deck_id)
	if deck == null:
		deck = CardDatabase.get_deck(deck_id)
	return deck.deck_name if deck != null else ("卡组 %d" % deck_id)


func current_round_label() -> String:
	return "第 %d / %d 轮" % [current_round, total_rounds]


func get_overview_participants() -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	for participant: Dictionary in participants:
		var entry := participant.duplicate(true)
		entry["deck_name"] = participant_deck_name(int(participant.get("id", -1)))
		entry["ai_mode"] = participant_ai_mode(int(participant.get("id", -1)))
		roster.append(entry)
	roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_player := bool(a.get("is_player", false))
		var b_player := bool(b.get("is_player", false))
		if a_player != b_player:
			return a_player
		var a_name := str(a.get("name", ""))
		var b_name := str(b.get("name", ""))
		if a_name != b_name:
			return a_name < b_name
		return int(a.get("id", 0)) < int(b.get("id", 0))
	)
	return roster


func get_deck_distribution() -> Array[Dictionary]:
	var counts := {}
	for participant: Dictionary in participants:
		var deck_id := int(participant.get("deck_id", 0))
		counts[deck_id] = int(counts.get(deck_id, 0)) + 1
	var distribution: Array[Dictionary] = []
	for deck_id_variant: Variant in counts.keys():
		var deck_id := int(deck_id_variant)
		var count := int(counts.get(deck_id, 0))
		distribution.append({
			"deck_id": deck_id,
			"deck_name": participant_deck_name(_participant_id_for_deck(deck_id)),
			"count": count,
			"share": float(count) / float(maxi(1, participants.size())),
		})
	distribution.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var count_a := int(a.get("count", 0))
		var count_b := int(b.get("count", 0))
		if count_a != count_b:
			return count_a > count_b
		return str(a.get("deck_name", "")) < str(b.get("deck_name", ""))
	)
	return distribution


func get_overview_snapshot() -> Dictionary:
	return {
		"player_name": player_name,
		"player_deck_id": player_deck_id,
		"player_deck_name": participant_deck_name(player_participant_id),
		"tournament_size": tournament_size,
		"total_rounds": total_rounds,
		"participants": get_overview_participants(),
		"deck_distribution": get_deck_distribution(),
	}


func serialize_state() -> Dictionary:
	return {
		"tournament_size": tournament_size,
		"total_rounds": total_rounds,
		"current_round": current_round,
		"player_participant_id": player_participant_id,
		"player_name": player_name,
		"player_deck_id": player_deck_id,
		"participants": participants.duplicate(true),
		"current_pairings": current_pairings.duplicate(true),
		"current_player_pairing": current_player_pairing.duplicate(true),
		"last_round_summary": last_round_summary.duplicate(true),
		"finished": finished,
		"rng_state": _rng.state,
		"llm_opponents_enabled": llm_opponents_enabled,
	}


func restore_state(data: Dictionary) -> void:
	tournament_size = int(data.get("tournament_size", 0))
	total_rounds = int(data.get("total_rounds", rounds_for_size(tournament_size)))
	current_round = int(data.get("current_round", 0))
	player_participant_id = int(data.get("player_participant_id", 0))
	player_name = str(data.get("player_name", "玩家"))
	player_deck_id = int(data.get("player_deck_id", 0))
	participants.clear()
	for entry_variant: Variant in data.get("participants", []):
		if entry_variant is Dictionary:
			participants.append((entry_variant as Dictionary).duplicate(true))
	current_pairings.clear()
	for entry_variant: Variant in data.get("current_pairings", []):
		if entry_variant is Dictionary:
			current_pairings.append((entry_variant as Dictionary).duplicate(true))
	current_player_pairing = (data.get("current_player_pairing", {}) as Dictionary).duplicate(true)
	last_round_summary = (data.get("last_round_summary", {}) as Dictionary).duplicate(true)
	finished = bool(data.get("finished", false))
	llm_opponents_enabled = bool(data.get("llm_opponents_enabled", false))
	if data.has("rng_state"):
		_rng.state = int(data.get("rng_state", _rng.state))


func _build_field() -> void:
	var used_names := {}
	participants.append(_make_participant(player_participant_id, player_name, player_deck_id, true))
	used_names[player_name] = true
	var ai_deck_pool := CardDatabase.get_supported_ai_deck_ids()
	if ai_deck_pool.is_empty():
		ai_deck_pool = DEFAULT_AI_DECK_POOL.duplicate()
	var llm_inserted := false
	for i: int in range(1, tournament_size):
		var next_name := _generate_unique_name(used_names)
		var next_ai_mode := _roll_ai_mode(i, llm_inserted)
		var next_deck_id := LLM_RAGING_BOLT_DECK_ID if next_ai_mode == "llm" else int(ai_deck_pool[_rng.randi_range(0, ai_deck_pool.size() - 1)])
		if next_ai_mode == "llm":
			llm_inserted = true
		participants.append(_make_participant(i, next_name, next_deck_id, false, next_ai_mode))


func _roll_ai_mode(participant_index: int, llm_inserted: bool) -> String:
	if llm_opponents_enabled:
		var remaining_after_this := tournament_size - participant_index - 1
		if _rng.randf() < LLM_OPPONENT_PROBABILITY or (not llm_inserted and remaining_after_this <= 0):
			return "llm"
	return "strong" if _rng.randf() < 0.5 else "weak"


func _make_participant(id: int, name: String, deck_id: int, is_player: bool, ai_mode: String = "weak") -> Dictionary:
	return {
		"id": id,
		"name": name,
		"deck_id": deck_id,
		"is_player": is_player,
		"ai_mode": "player" if is_player else ai_mode,
		"wins": 0,
		"losses": 0,
		"draws": 0,
		"points": 0,
		"opponent_points": 0.0,
		"opponents": [],
		"rounds": [],
	}


func _generate_unique_name(used_names: Dictionary) -> String:
	for _attempt in 64:
		var candidate := "%s%s" % [
			NAME_PREFIXES[_rng.randi_range(0, NAME_PREFIXES.size() - 1)],
			NAME_SUFFIXES[_rng.randi_range(0, NAME_SUFFIXES.size() - 1)],
		]
		if not used_names.has(candidate):
			used_names[candidate] = true
			return candidate
	var fallback_index := used_names.size() + 1
	var fallback := "选手%d" % fallback_index
	used_names[fallback] = true
	return fallback


func _build_round_pairings() -> Array[Dictionary]:
	var sorted_ids := _sorted_participant_ids_for_pairing()
	var unpaired := sorted_ids.duplicate()
	var pairings: Array[Dictionary] = []
	var table_number := 1
	while unpaired.size() >= 2:
		var a_id := int(unpaired[0])
		unpaired.remove_at(0)
		var b_index := _select_pairing_index(a_id, unpaired)
		var b_id := int(unpaired[b_index])
		unpaired.remove_at(b_index)
		pairings.append({
			"round": current_round,
			"table": table_number,
			"player_a_id": a_id,
			"player_b_id": b_id,
			"result_recorded": false,
		})
		table_number += 1
	return pairings


func _sorted_participant_ids_for_pairing() -> Array[int]:
	var ids: Array[int] = []
	for participant: Dictionary in participants:
		ids.append(int(participant.get("id", -1)))
	if current_round <= 1:
		for i: int in range(ids.size() - 1, 0, -1):
			var swap_index := _rng.randi_range(0, i)
			var temp := ids[i]
			ids[i] = ids[swap_index]
			ids[swap_index] = temp
		return ids
	ids.sort_custom(func(a_id: int, b_id: int) -> bool:
		var a := _participant_by_id(a_id)
		var b := _participant_by_id(b_id)
		var points_a := int(a.get("points", 0))
		var points_b := int(b.get("points", 0))
		if points_a != points_b:
			return points_a > points_b
		var opp_a := float(a.get("opponent_points", 0.0))
		var opp_b := float(b.get("opponent_points", 0.0))
		if not is_equal_approx(opp_a, opp_b):
			return opp_a > opp_b
		return int(a.get("id", 0)) < int(b.get("id", 0))
	)
	return ids


func _select_pairing_index(a_id: int, candidate_ids: Array[int]) -> int:
	var a := _participant_by_id(a_id)
	var previous_opponents: Array = a.get("opponents", [])
	for i: int in candidate_ids.size():
		if int(candidate_ids[i]) not in previous_opponents:
			return i
	return 0


func _simulate_remaining_pairings() -> void:
	for i: int in current_pairings.size():
		var pairing := current_pairings[i]
		if bool(pairing.get("result_recorded", false)):
			continue
		var a_id := int(pairing.get("player_a_id", -1))
		var b_id := int(pairing.get("player_b_id", -1))
		var simulated := _simulate_match(a_id, b_id)
		var winner_id := int(simulated.get("winner_id", -1))
		var loser_id := b_id if winner_id == a_id else a_id
		_apply_match_result(winner_id, loser_id, "win", {
			"reason": "simulated",
			"simulated": true,
		})
		pairing["result_recorded"] = true
		pairing["winner_id"] = winner_id
		pairing["result"] = "win"
		current_pairings[i] = pairing


func _simulate_match(a_id: int, b_id: int) -> Dictionary:
	var a := _participant_by_id(a_id)
	var b := _participant_by_id(b_id)
	var a_mode := str(a.get("ai_mode", "weak"))
	var b_mode := str(b.get("ai_mode", "weak"))
	if a_mode == "llm" or b_mode == "llm":
		var llm_id := a_id if a_mode == "llm" else b_id
		var opponent_mode := b_mode if a_mode == "llm" else a_mode
		var llm_win_probability := _llm_win_probability_against_mode(opponent_mode)
		return {
			"winner_id": llm_id if _rng.randf() < llm_win_probability else (b_id if llm_id == a_id else a_id),
		}
	if a_mode != b_mode and (a_mode == "strong" or b_mode == "strong"):
		return {
			"winner_id": a_id if a_mode == "strong" else b_id,
		}
	var rating_a := _deck_rating(int(a.get("deck_id", 0)))
	var rating_b := _deck_rating(int(b.get("deck_id", 0)))
	var expected_a := 1.0 / (1.0 + pow(10.0, (rating_b - rating_a) / 400.0))
	expected_a = clampf(expected_a, 0.15, 0.85)
	var winner_id := a_id if _rng.randf() < expected_a else b_id
	return {
		"winner_id": winner_id,
	}


func _llm_win_probability_against_mode(opponent_mode: String) -> float:
	match opponent_mode:
		"weak":
			return 1.0
		"strong":
			return 0.60
		"llm":
			return 0.50
		_:
			return 0.85


func _apply_match_result(winner_id: int, loser_id: int, result: String, meta: Dictionary = {}) -> void:
	var winner_index := _participant_index_by_id(winner_id)
	var loser_index := _participant_index_by_id(loser_id)
	if winner_index < 0 or loser_index < 0:
		return
	var winner := participants[winner_index].duplicate(true)
	var loser := participants[loser_index].duplicate(true)
	winner["wins"] = int(winner.get("wins", 0)) + 1
	winner["points"] = int(winner.get("points", 0)) + POINTS_WIN
	_append_round_record(winner, loser_id, result, meta)
	loser["losses"] = int(loser.get("losses", 0)) + 1
	loser["points"] = int(loser.get("points", 0)) + POINTS_LOSS
	_append_round_record(loser, winner_id, "loss", meta)
	participants[winner_index] = winner
	participants[loser_index] = loser


func _append_round_record(participant: Dictionary, opponent_id: int, result: String, meta: Dictionary) -> void:
	var opponents: Array = participant.get("opponents", []).duplicate()
	opponents.append(opponent_id)
	participant["opponents"] = opponents
	var rounds: Array = participant.get("rounds", []).duplicate(true)
	rounds.append({
		"round": current_round,
		"opponent_id": opponent_id,
		"result": result,
		"meta": meta.duplicate(true),
	})
	participant["rounds"] = rounds


func _recompute_tiebreakers() -> void:
	for i: int in participants.size():
		var participant := participants[i].duplicate(true)
		var opponent_points := 0.0
		for opponent_id_variant: Variant in participant.get("opponents", []):
			var opponent := _participant_by_id(int(opponent_id_variant))
			opponent_points += float(opponent.get("points", 0))
		participant["opponent_points"] = opponent_points
		participants[i] = participant


func _participant_by_id(participant_id: int) -> Dictionary:
	var index := _participant_index_by_id(participant_id)
	return participants[index] if index >= 0 else {}


func _participant_index_by_id(participant_id: int) -> int:
	for i: int in participants.size():
		if int(participants[i].get("id", -1)) == participant_id:
			return i
	return -1


func _opponent_id_for_pairing(pairing: Dictionary, participant_id: int) -> int:
	var a_id := int(pairing.get("player_a_id", -1))
	var b_id := int(pairing.get("player_b_id", -1))
	return b_id if a_id == participant_id else a_id


func _deck_rating(deck_id: int) -> float:
	return float(DECK_RATINGS.get(deck_id, 1500.0))


func _participant_id_for_deck(deck_id: int) -> int:
	for participant: Dictionary in participants:
		if int(participant.get("deck_id", 0)) == deck_id:
			return int(participant.get("id", -1))
	return -1


func participant_has_strong_opening(participant_id: int) -> bool:
	if participant_ai_mode(participant_id) != "strong":
		return false
	return _fixed_order_registry.has_fixed_order(participant_deck_id(participant_id))


func participant_fixed_order_path(participant_id: int) -> String:
	if not participant_has_strong_opening(participant_id):
		return ""
	return _fixed_order_registry.get_fixed_order_path(participant_deck_id(participant_id))
