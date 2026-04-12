class_name TestDeckStrategyContract
extends TestBase


const GARDEVOIR_SCRIPT_PATH := "res://scripts/ai/DeckStrategyGardevoir.gd"
const MIRAIDON_SCRIPT_PATH := "res://scripts/ai/DeckStrategyMiraidon.gd"
const STRATEGY_BASE_SCRIPT_PATH := "res://scripts/ai/DeckStrategyBase.gd"
const STRATEGY_REGISTRY_SCRIPT_PATH := "res://scripts/ai/DeckStrategyRegistry.gd"
const EXPANDED_STRATEGY_SCRIPT_PATHS := {
	"charizard_ex": "res://scripts/ai/DeckStrategyCharizardEx.gd",
	"dragapult_dusknoir": "res://scripts/ai/DeckStrategyDragapultDusknoir.gd",
	"dragapult_banette": "res://scripts/ai/DeckStrategyDragapultBanette.gd",
	"dragapult_charizard": "res://scripts/ai/DeckStrategyDragapultCharizard.gd",
	"regidrago": "res://scripts/ai/DeckStrategyRegidrago.gd",
	"lugia_archeops": "res://scripts/ai/DeckStrategyLugiaArcheops.gd",
	"dialga_metang": "res://scripts/ai/DeckStrategyDialgaMetang.gd",
	"arceus_giratina": "res://scripts/ai/DeckStrategyArceusGiratina.gd",
	"palkia_gholdengo": "res://scripts/ai/DeckStrategyPalkiaGholdengo.gd",
	"palkia_dusknoir": "res://scripts/ai/DeckStrategyPalkiaDusknoir.gd",
	"lost_box": "res://scripts/ai/DeckStrategyLostBox.gd",
	"future_box": "res://scripts/ai/DeckStrategyFutureBox.gd",
	"iron_thorns": "res://scripts/ai/DeckStrategyIronThorns.gd",
	"raging_bolt_ogerpon": "res://scripts/ai/DeckStrategyRagingBoltOgerpon.gd",
	"blissey_tank": "res://scripts/ai/DeckStrategyBlisseyTank.gd",
	"gouging_fire_ancient": "res://scripts/ai/DeckStrategyGougingFireAncient.gd",
}

const REQUIRED_METHODS := [
	"get_strategy_id",
	"get_signature_names",
	"get_state_encoder_class",
	"load_value_net",
	"get_value_net",
	"get_mcts_config",
	"plan_opening_setup",
	"score_action_absolute",
	"score_action",
	"evaluate_board",
	"predict_attacker_damage",
	"get_discard_priority",
	"get_discard_priority_contextual",
	"get_search_priority",
	"score_interaction_target",
]


func _make_pokemon_cd(pname: String, energy_type: String = "C") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.energy_type = energy_type
	cd.hp = 100
	return cd


func _make_player_with_hand(names: Array[String]) -> PlayerState:
	CardInstance.reset_id_counter()
	var player := PlayerState.new()
	player.player_index = 0
	for name: String in names:
		player.hand.append(CardInstance.create(_make_pokemon_cd(name), 0))
	return player


func _load_script(script_path: String) -> GDScript:
	var script: Variant = load(script_path)
	return script if script is GDScript else null


func _missing_methods(instance: Object, required_methods: Array) -> Array[String]:
	var methods: Dictionary = {}
	for method_info: Dictionary in instance.get_method_list():
		methods[str(method_info.get("name", ""))] = true
	var missing: Array[String] = []
	for method_name: String in required_methods:
		if not methods.has(method_name):
			missing.append(method_name)
	return missing


func test_unified_strategy_base_script_exists() -> String:
	var script := _load_script(STRATEGY_BASE_SCRIPT_PATH)
	return assert_not_null(script, "DeckStrategyBase.gd should exist and load")


func test_unified_strategy_registry_script_exists() -> String:
	var script := _load_script(STRATEGY_REGISTRY_SCRIPT_PATH)
	return assert_not_null(script, "DeckStrategyRegistry.gd should exist and load")


func test_gardevoir_and_miraidon_expose_unified_strategy_contract() -> String:
	var gardevoir_script := _load_script(GARDEVOIR_SCRIPT_PATH)
	var miraidon_script := _load_script(MIRAIDON_SCRIPT_PATH)
	var checks: Array[String] = [
		assert_not_null(gardevoir_script, "DeckStrategyGardevoir.gd should load"),
		assert_not_null(miraidon_script, "DeckStrategyMiraidon.gd should load"),
	]
	if gardevoir_script == null or miraidon_script == null:
		return run_checks(checks)
	var gardevoir = gardevoir_script.new()
	var miraidon = miraidon_script.new()
	var gardevoir_missing := _missing_methods(gardevoir, REQUIRED_METHODS)
	var miraidon_missing := _missing_methods(miraidon, REQUIRED_METHODS)
	checks.append(assert_eq(gardevoir_missing, [], "Gardevoir strategy should implement the unified contract"))
	checks.append(assert_eq(miraidon_missing, [], "Miraidon strategy should implement the unified contract"))
	return run_checks(checks)


func test_expanded_strategies_expose_unified_strategy_contract() -> String:
	var checks: Array[String] = []
	for strategy_id: String in EXPANDED_STRATEGY_SCRIPT_PATHS.keys():
		var script_path: String = str(EXPANDED_STRATEGY_SCRIPT_PATHS[strategy_id])
		var script := _load_script(script_path)
		checks.append(assert_not_null(script, "%s strategy should load from %s" % [strategy_id, script_path]))
		if script == null:
			continue
		var strategy = script.new()
		var missing := _missing_methods(strategy, REQUIRED_METHODS)
		checks.append(assert_eq(missing, [], "%s strategy should implement the unified contract" % strategy_id))
	return run_checks(checks)


func test_registry_detects_gardevoir_and_miraidon_from_visible_cards() -> String:
	var registry_script := _load_script(STRATEGY_REGISTRY_SCRIPT_PATH)
	if registry_script == null:
		return "DeckStrategyRegistry.gd should exist before deck detection can be unified"
	var registry = registry_script.new()
	var gardevoir_player := _make_player_with_hand(["沙奈朵ex"])
	var miraidon_player := _make_player_with_hand(["密勒顿ex"])
	var gardevoir_id: String = str(registry.call("detect_strategy_id_for_player", gardevoir_player))
	var miraidon_id: String = str(registry.call("detect_strategy_id_for_player", miraidon_player))
	return run_checks([
		assert_eq(gardevoir_id, "gardevoir", "Registry should resolve Gardevoir from visible signature cards"),
		assert_eq(miraidon_id, "miraidon", "Registry should resolve Miraidon from visible signature cards"),
	])
