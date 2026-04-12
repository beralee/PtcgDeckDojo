class_name TestDeckStrategyRegistryExpansion
extends TestBase


const STRATEGY_REGISTRY_SCRIPT_PATH := "res://scripts/ai/DeckStrategyRegistry.gd"
const EXPANDED_STRATEGIES := {
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


func _load_script(script_path: String) -> GDScript:
	var script: Variant = load(script_path)
	return script if script is GDScript else null


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


func test_expanded_strategy_scripts_exist() -> String:
	var checks: Array[String] = []
	for strategy_id: String in EXPANDED_STRATEGIES.keys():
		var script_path: String = str(EXPANDED_STRATEGIES[strategy_id])
		checks.append(assert_not_null(
			_load_script(script_path),
			"%s should load from %s" % [strategy_id, script_path]
		))
	return run_checks(checks)


func test_expanded_strategy_scripts_report_matching_strategy_ids() -> String:
	var checks: Array[String] = []
	for strategy_id: String in EXPANDED_STRATEGIES.keys():
		var script_path: String = str(EXPANDED_STRATEGIES[strategy_id])
		var script := _load_script(script_path)
		checks.append(assert_not_null(script, "%s script should load" % strategy_id))
		if script == null:
			continue
		var strategy = script.new()
		checks.append(assert_eq(
			strategy.get_strategy_id(),
			strategy_id,
			"%s strategy should report its registry id" % strategy_id
		))
	return run_checks(checks)


func test_registry_detects_expanded_families_from_signature_cards() -> String:
	var registry_script := _load_script(STRATEGY_REGISTRY_SCRIPT_PATH)
	if registry_script == null:
		return "DeckStrategyRegistry.gd should exist before expanded family detection can be tested"
	var registry = registry_script.new()
	var checks: Array[String] = []
	for strategy_id: String in EXPANDED_STRATEGIES.keys():
		var script_path: String = str(EXPANDED_STRATEGIES[strategy_id])
		var script := _load_script(script_path)
		checks.append(assert_not_null(script, "%s script should load for registry detection" % strategy_id))
		if script == null:
			continue
		var strategy = script.new()
		var signature_names: Array[String] = strategy.get_signature_names()
		checks.append(assert_true(signature_names.size() > 0, "%s should expose at least one signature card" % strategy_id))
		if signature_names.is_empty():
			continue
		var player := _make_player_with_hand(signature_names)
		var detected_id: String = str(registry.detect_strategy_id_for_player(player))
		checks.append(assert_eq(
			detected_id,
			strategy_id,
			"Registry should detect %s from its signature cards" % strategy_id
		))
	return run_checks(checks)
