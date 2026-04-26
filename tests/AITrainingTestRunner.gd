extends SceneTree

const TestSuiteFilterScript = preload("res://scripts/tools/TestSuiteFilter.gd")

const RUN_MODE_SUITE := "suite"
const RUN_MODE_MATCHUP_SWEEP := "matchup_sweep"
const RUN_MODE_MIRAIDON_BASELINE_REGRESSION := "miraidon_baseline_regression"
const RUN_MODE_ACTION_CAP_PROBE := "action_cap_probe"
const BUNDLED_DECKS_DIR := "res://data/bundled_user/decks"
const DEFAULT_ANCHOR_DECK_ID := 575720
const DEFAULT_GAMES_PER_MATCHUP := 10
const DEFAULT_MAX_STEPS := 200
const DEFAULT_SEED_BASE := 9000
const DECK_ID_TO_STRATEGY_ID := {
	561444: "dialga_metang",
	569061: "arceus_giratina",
	572568: "future_box",
	575479: "palkia_gholdengo",
	575620: "lost_box",
	575653: "regidrago",
	575657: "lugia_archeops",
	575716: "charizard_ex",
	575718: "raging_bolt_ogerpon",
	575720: "miraidon",
	575723: "dragapult_dusknoir",
	577861: "palkia_dusknoir",
	578647: "gardevoir",
	579502: "dragapult_charizard",
	579577: "iron_thorns",
	580445: "dragapult_banette",
	581056: "regidrago",
	581614: "blissey_tank",
	582754: "gouging_fire_ancient",
}


func _initialize() -> void:
	var runner_script = load("res://tests/AITrainingRunnerScene.gd")
	if runner_script == null:
		print("AITrainingTestRunner failed: unable to load res://tests/AITrainingRunnerScene.gd")
		quit(1)
		return
	var runner = runner_script.new()
	get_root().add_child(runner)


static func parse_runner_args(args: PackedStringArray) -> Dictionary:
	var options := {
		"mode": RUN_MODE_SUITE,
		"selected_suites": TestSuiteFilterScript.parse_suite_filter(args),
		"anchor_deck_id": DEFAULT_ANCHOR_DECK_ID,
		"anchor_strategy_override": "",
		"games_per_matchup": DEFAULT_GAMES_PER_MATCHUP,
		"max_steps": DEFAULT_MAX_STEPS,
		"seed_base": DEFAULT_SEED_BASE,
		"seed_bases": [],
		"exclude_deck_ids": [],
		"explicit_deck_ids": [],
		"json_output": "",
		"trace_jsonl_output": "",
		"deck_id": 0,
		"seed": 0,
		"tracked_player_index": 0,
		"tracked_value_net_path": "",
		"tracked_action_scorer_path": "",
		"tracked_interaction_scorer_path": "",
		"tracked_decision_mode": "",
		"anchor_value_net_path": "",
		"anchor_action_scorer_path": "",
		"anchor_interaction_scorer_path": "",
		"anchor_decision_mode": "",
	}
	for raw_arg: String in args:
		if raw_arg == "--mode=miraidon_baseline_regression":
			options["mode"] = RUN_MODE_MIRAIDON_BASELINE_REGRESSION
		elif raw_arg == "--mode=action_cap_probe":
			options["mode"] = RUN_MODE_ACTION_CAP_PROBE
		elif raw_arg == "--matchup-sweep" or raw_arg == "--mode=matchup_sweep" or raw_arg.begins_with("--matchup-anchor-deck="):
			options["mode"] = RUN_MODE_MATCHUP_SWEEP
		if raw_arg.begins_with("--matchup-anchor-deck="):
			options["anchor_deck_id"] = _parse_int_suffix(raw_arg, "--matchup-anchor-deck=", DEFAULT_ANCHOR_DECK_ID)
		elif raw_arg.begins_with("--anchor-strategy-override="):
			options["anchor_strategy_override"] = raw_arg.trim_prefix("--anchor-strategy-override=")
		elif raw_arg.begins_with("--anchor-deck-id="):
			if str(options.get("mode", RUN_MODE_SUITE)) == RUN_MODE_SUITE:
				options["mode"] = RUN_MODE_MATCHUP_SWEEP
			options["anchor_deck_id"] = _parse_int_suffix(raw_arg, "--anchor-deck-id=", DEFAULT_ANCHOR_DECK_ID)
		elif raw_arg.begins_with("--games-per-matchup="):
			options["games_per_matchup"] = max(1, _parse_int_suffix(raw_arg, "--games-per-matchup=", DEFAULT_GAMES_PER_MATCHUP))
		elif raw_arg.begins_with("--max-steps="):
			options["max_steps"] = max(1, _parse_int_suffix(raw_arg, "--max-steps=", DEFAULT_MAX_STEPS))
		elif raw_arg.begins_with("--seed-base="):
			options["seed_base"] = _parse_int_suffix(raw_arg, "--seed-base=", DEFAULT_SEED_BASE)
		elif raw_arg.begins_with("--seed-bases="):
			options["seed_bases"] = _parse_int_list_suffix(raw_arg, "--seed-bases=")
		elif raw_arg.begins_with("--exclude-decks="):
			options["exclude_deck_ids"] = _parse_int_list_suffix(raw_arg, "--exclude-decks=")
		elif raw_arg.begins_with("--deck-ids="):
			if str(options.get("mode", RUN_MODE_SUITE)) == RUN_MODE_SUITE:
				options["mode"] = RUN_MODE_MATCHUP_SWEEP
			options["explicit_deck_ids"] = _parse_int_list_suffix(raw_arg, "--deck-ids=")
		elif raw_arg.begins_with("--json-output="):
			options["json_output"] = raw_arg.trim_prefix("--json-output=")
		elif raw_arg.begins_with("--trace-jsonl-output="):
			options["trace_jsonl_output"] = raw_arg.trim_prefix("--trace-jsonl-output=")
		elif raw_arg.begins_with("--deck-id="):
			options["deck_id"] = _parse_int_suffix(raw_arg, "--deck-id=", 0)
		elif raw_arg.begins_with("--seed="):
			options["seed"] = _parse_int_suffix(raw_arg, "--seed=", 0)
		elif raw_arg.begins_with("--tracked-player-index="):
			options["tracked_player_index"] = max(0, min(1, _parse_int_suffix(raw_arg, "--tracked-player-index=", 0)))
		elif raw_arg.begins_with("--tracked-value-net="):
			options["tracked_value_net_path"] = raw_arg.trim_prefix("--tracked-value-net=")
		elif raw_arg.begins_with("--tracked-action-scorer="):
			options["tracked_action_scorer_path"] = raw_arg.trim_prefix("--tracked-action-scorer=")
		elif raw_arg.begins_with("--tracked-interaction-scorer="):
			options["tracked_interaction_scorer_path"] = raw_arg.trim_prefix("--tracked-interaction-scorer=")
		elif raw_arg.begins_with("--tracked-decision-mode="):
			options["tracked_decision_mode"] = raw_arg.trim_prefix("--tracked-decision-mode=")
		elif raw_arg.begins_with("--anchor-value-net="):
			options["anchor_value_net_path"] = raw_arg.trim_prefix("--anchor-value-net=")
		elif raw_arg.begins_with("--anchor-action-scorer="):
			options["anchor_action_scorer_path"] = raw_arg.trim_prefix("--anchor-action-scorer=")
		elif raw_arg.begins_with("--anchor-interaction-scorer="):
			options["anchor_interaction_scorer_path"] = raw_arg.trim_prefix("--anchor-interaction-scorer=")
		elif raw_arg.begins_with("--anchor-decision-mode="):
			options["anchor_decision_mode"] = raw_arg.trim_prefix("--anchor-decision-mode=")
	return options


static func resolve_matchup_sweep_deck_ids(options: Dictionary) -> Array[int]:
	var explicit_ids_variant: Variant = options.get("explicit_deck_ids", [])
	var explicit_ids: Array[int] = _variant_to_int_array(explicit_ids_variant)
	var anchor_deck_id: int = int(options.get("anchor_deck_id", DEFAULT_ANCHOR_DECK_ID))
	var exclude_ids: Array[int] = _variant_to_int_array(options.get("exclude_deck_ids", []))
	var source_ids: Array[int] = explicit_ids if not explicit_ids.is_empty() else _discover_bundled_deck_ids()
	var resolved: Array[int] = []
	var seen := {}
	for deck_id: int in source_ids:
		if deck_id == anchor_deck_id:
			continue
		if exclude_ids.has(deck_id):
			continue
		if seen.has(deck_id):
			continue
		seen[deck_id] = true
		resolved.append(deck_id)
	resolved.sort()
	return resolved


static func resolve_seed_bases(options: Dictionary) -> Array[int]:
	var explicit_seed_bases: Array[int] = _variant_to_int_array(options.get("seed_bases", []))
	if not explicit_seed_bases.is_empty():
		return explicit_seed_bases
	return [int(options.get("seed_base", DEFAULT_SEED_BASE))]


static func truncate_name(name: String, limit: int) -> String:
	if name.length() <= limit:
		return name
	if limit <= 3:
		return name.substr(0, limit)
	return "%s..." % name.substr(0, limit - 3)


static func parse_strategy_id_for_deck(deck_id: int) -> String:
	return str(DECK_ID_TO_STRATEGY_ID.get(deck_id, ""))


static func _parse_int_suffix(raw_arg: String, prefix: String, fallback: int) -> int:
	var payload := raw_arg.trim_prefix(prefix)
	return int(payload) if payload.is_valid_int() else fallback


static func _parse_int_list_suffix(raw_arg: String, prefix: String) -> Array[int]:
	var payload := raw_arg.trim_prefix(prefix)
	var values: Array[int] = []
	for entry: String in payload.split(",", false):
		var trimmed := entry.strip_edges()
		if trimmed.is_valid_int():
			values.append(int(trimmed))
	return values


static func _variant_to_int_array(value: Variant) -> Array[int]:
	var results: Array[int] = []
	if not value is Array:
		return results
	for entry: Variant in value:
		if entry is int:
			results.append(int(entry))
		elif str(entry).is_valid_int():
			results.append(int(str(entry)))
	return results


static func _discover_bundled_deck_ids() -> Array[int]:
	var deck_ids: Array[int] = []
	var dir := DirAccess.open(BUNDLED_DECKS_DIR)
	if dir == null:
		return deck_ids
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var stem := file_name.trim_suffix(".json")
			if stem.is_valid_int():
				deck_ids.append(int(stem))
		file_name = dir.get_next()
	dir.list_dir_end()
	deck_ids.sort()
	return deck_ids
