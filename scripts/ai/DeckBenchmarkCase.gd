class_name DeckBenchmarkCase
extends RefCounted

const PHASE2_DECK_ID_TO_KEY: Dictionary = {
	569061: "arceus_giratina",
	575720: "miraidon",
	578647: "gardevoir",
	575716: "charizard_ex",
}
const PHASE2_DEFAULT_SEED_SET: Array[int] = [11, 29, 47, 83]
const VALID_COMPARISON_MODES: Array[String] = ["shared_agent_mirror", "version_regression"]
const PIPELINE_FIXED_THREE_DECK := "fixed_three_deck_training"
const PIPELINE_MIRAIDON_FOCUS := "miraidon_focus_training"
const PIPELINE_GARDEVOIR_FOCUS := "gardevoir_focus_training"
const PIPELINE_GARDEVOIR_MIRROR := "gardevoir_mirror_training"
const PHASE1_DEFAULT_PAIRINGS: Array[Array] = [
	[575720, 578647],
	[575720, 575716],
	[578647, 575716],
]
const MIRAIDON_FOCUS_PAIRINGS: Array[Array] = [
	[575720, 578647],
	[575720, 575716],
	[575720, 569061],
]
const GARDEVOIR_FOCUS_PAIRINGS: Array[Array] = [
	[578647, 575720],
	[578647, 575716],
	[578647, 569061],
]
const GARDEVOIR_MIRROR_PAIRINGS: Array[Array] = [
	[578647, 578647],
]

var deck_a_id: int = 0
var deck_b_id: int = 0
var deck_a_key: String = ""
var deck_b_key: String = ""
var comparison_mode: String = "shared_agent_mirror"
var agent_a_config: Dictionary = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
var agent_b_config: Dictionary = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
var seed_set: Array = []
var match_count: int = 0
var allow_mirror_pairing: bool = false


func get_effective_seed_set() -> Array:
	if seed_set.is_empty():
		return PHASE2_DEFAULT_SEED_SET.duplicate()
	return seed_set.duplicate()


func refresh_match_count() -> int:
	match_count = get_effective_seed_set().size() * 2
	return match_count


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var effective_seed_set: Array = get_effective_seed_set()

	if comparison_mode not in VALID_COMPARISON_MODES:
		errors.append("comparison_mode must be shared_agent_mirror or version_regression")

	errors.append_array(_validate_agent_config(agent_a_config, "agent_a_config"))
	errors.append_array(_validate_agent_config(agent_b_config, "agent_b_config"))

	if deck_a_id <= 0:
		errors.append("deck_a_id must be set to a pinned Phase 2 deck")
	else:
		var expected_a := _get_phase2_deck_key(deck_a_id)
		if expected_a == "":
			errors.append("deck_a_id %d is not a pinned Phase 2 deck" % deck_a_id)
		elif deck_a_key != "" and deck_a_key != expected_a:
			errors.append("deck_a_key must match pinned deck id %d (%s)" % [deck_a_id, expected_a])
	if deck_b_id <= 0:
		errors.append("deck_b_id must be set to a pinned Phase 2 deck")
	else:
		var expected_b := _get_phase2_deck_key(deck_b_id)
		if expected_b == "":
			errors.append("deck_b_id %d is not a pinned Phase 2 deck" % deck_b_id)
		elif deck_b_key != "" and deck_b_key != expected_b:
			errors.append("deck_b_key must match pinned deck id %d (%s)" % [deck_b_id, expected_b])
	if not allow_mirror_pairing and deck_a_id > 0 and deck_b_id > 0 and deck_a_id == deck_b_id:
		errors.append("Phase 2 benchmark cases must compare two distinct deck ids")

	for seed_variant: Variant in effective_seed_set:
		if not seed_variant is int:
			errors.append("seed_set entries must be integers")
			break

	if comparison_mode == "shared_agent_mirror":
		if agent_a_config != agent_b_config:
			errors.append("shared_agent_mirror cases require identical agent configs on both sides")
	elif comparison_mode == "version_regression":
		if str(agent_a_config.get("agent_id", "")) != str(agent_b_config.get("agent_id", "")):
			errors.append("version_regression cases require the same agent_id on both sides")
		if effective_seed_set.size() % 2 != 0:
			errors.append("version_regression cases require an even effective seed count for balanced deck exposure")

	refresh_match_count()

	return errors


func resolve_decks() -> Dictionary:
	deck_a_key = _get_phase2_deck_key(deck_a_id)
	deck_b_key = _get_phase2_deck_key(deck_b_id)
	refresh_match_count()
	return {
		"deck_a_id": deck_a_id,
		"deck_a_key": deck_a_key,
		"deck_b_id": deck_b_id,
		"deck_b_key": deck_b_key,
	}


func get_pairing_name() -> String:
	var left_label := deck_a_key if deck_a_key != "" else str(deck_a_id)
	var right_label := deck_b_key if deck_b_key != "" else str(deck_b_id)
	return "%s_vs_%s" % [left_label, right_label]


static func make_phase2_default_cases(seed_override: Array = []) -> Array:
	return [
		_make_phase2_case(575720, 578647, false, seed_override),
		_make_phase2_case(575720, 575716, false, seed_override),
		_make_phase2_case(578647, 575716, false, seed_override),
	]


static func make_miraidon_focus_cases(seed_override: Array = []) -> Array:
	return [
		_make_phase2_case(575720, 578647, false, seed_override),
		_make_phase2_case(575720, 575716, false, seed_override),
		_make_phase2_case(575720, 569061, false, seed_override),
	]


static func make_gardevoir_focus_cases(seed_override: Array = []) -> Array:
	return [
		_make_phase2_case(578647, 575720, false, seed_override),
		_make_phase2_case(578647, 575716, false, seed_override),
		_make_phase2_case(578647, 569061, false, seed_override),
	]


static func make_gardevoir_mirror_cases(seed_override: Array = []) -> Array:
	return [
		_make_phase2_case(578647, 578647, true, seed_override),
	]


static func make_phase2_cases_for_pipeline(pipeline_name: String, seed_override: Array = []) -> Array:
	match pipeline_name:
		PIPELINE_MIRAIDON_FOCUS:
			return make_miraidon_focus_cases(seed_override)
		PIPELINE_GARDEVOIR_FOCUS:
			return make_gardevoir_focus_cases(seed_override)
		PIPELINE_GARDEVOIR_MIRROR:
			return make_gardevoir_mirror_cases(seed_override)
		_:
			return make_phase2_default_cases(seed_override)


static func get_training_deck_pairings(pipeline_name: String) -> Array[Array]:
	match pipeline_name:
		PIPELINE_MIRAIDON_FOCUS:
			return _duplicate_pairings(MIRAIDON_FOCUS_PAIRINGS)
		PIPELINE_GARDEVOIR_FOCUS:
			return _duplicate_pairings(GARDEVOIR_FOCUS_PAIRINGS)
		PIPELINE_GARDEVOIR_MIRROR:
			return _duplicate_pairings(GARDEVOIR_MIRROR_PAIRINGS)
		_:
			return _duplicate_pairings(PHASE1_DEFAULT_PAIRINGS)


static func _make_phase2_case(deck_a: int, deck_b: int, allow_mirror: bool = false, seed_override: Array = []):
	var benchmark_case_script = load("res://scripts/ai/DeckBenchmarkCase.gd")
	var benchmark_case = benchmark_case_script.new()
	benchmark_case.deck_a_id = deck_a
	benchmark_case.deck_b_id = deck_b
	benchmark_case.seed_set = seed_override.duplicate() if not seed_override.is_empty() else PHASE2_DEFAULT_SEED_SET.duplicate()
	benchmark_case.allow_mirror_pairing = allow_mirror
	benchmark_case.resolve_decks()
	return benchmark_case


static func _duplicate_pairings(source_pairings: Array[Array]) -> Array[Array]:
	var copy: Array[Array] = []
	for pairing: Array in source_pairings:
		copy.append(pairing.duplicate())
	return copy


func _validate_agent_config(config: Dictionary, label: String) -> PackedStringArray:
	var errors := PackedStringArray()
	var agent_id := str(config.get("agent_id", ""))
	var version_tag := str(config.get("version_tag", ""))
	if agent_id == "":
		errors.append("%s must include agent_id" % label)
	if version_tag == "":
		errors.append("%s must include version_tag" % label)
	return errors


func _get_phase2_deck_key(deck_id: int) -> String:
	return str(PHASE2_DECK_ID_TO_KEY.get(deck_id, ""))
