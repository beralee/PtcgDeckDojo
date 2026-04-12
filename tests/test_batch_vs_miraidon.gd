class_name TestBatchVsMiraidon
extends TestBase


const BatchVsMiraidonScript = preload("res://scripts/training/batch_vs_miraidon.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_resolves_strategy_id_from_deck_data() -> String:
	var scene = BatchVsMiraidonScript.new()
	var registry = DeckStrategyRegistryScript.new()
	var miraidon_strategy: RefCounted = registry.create_strategy_by_id("miraidon")
	var deck := DeckData.new()
	deck.cards = []
	for signature_name: String in miraidon_strategy.get_signature_names():
		deck.cards.append({
			"name": signature_name,
			"name_en": "",
		})
	var strategy_id: String = scene.call("_detect_strategy_from_deck", deck)
	return run_checks([
		assert_not_null(scene, "batch_vs_miraidon script should instantiate"),
		assert_not_null(miraidon_strategy, "miraidon strategy should be available for the regression fixture"),
		assert_eq(strategy_id, "miraidon", "batch_vs_miraidon should resolve strategy ids from deck data"),
	])
