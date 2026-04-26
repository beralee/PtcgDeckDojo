class_name TestDeckDiscussionContextBuilder
extends TestBase

const BuilderScript := preload("res://scripts/engine/DeckDiscussionContextBuilder.gd")


func test_context_builder_reports_exact_opening_basics_probability() -> String:
	var deck := DeckData.new()
	deck.id = 700001
	deck.deck_name = "probability test"
	deck.total_cards = 60
	deck.cards = [
		{"set_code": "SV1", "card_index": "001", "count": 4, "card_type": "Pokemon", "name": "Pikachu", "name_en": "Pikachu"},
		{"set_code": "SV1", "card_index": "050", "count": 8, "card_type": "Basic Energy", "name": "Lightning Energy", "name_en": "Lightning Energy"},
	]

	var builder = BuilderScript.new()
	var context: Dictionary = builder.build_context(deck)
	var opening: Dictionary = context.get("opening_reference", {})
	var p_basic := float(opening.get("p_open_at_least_one_basic", 0.0))
	var mulligan := float(opening.get("p_mulligan", 0.0))

	return run_checks([
		assert_true(absf(p_basic - 0.3995) < 0.0002, "4 basics should open a basic about 39.95%"),
		assert_true(absf(mulligan - 0.6005) < 0.0002, "4 basics should mulligan about 60.05%"),
	])


func test_context_builder_exposes_quick_summary() -> String:
	var deck := DeckData.new()
	deck.id = 700002
	deck.deck_name = "summary test"
	deck.total_cards = 60
	deck.cards = [
		{"set_code": "SV1", "card_index": "001", "count": 8, "card_type": "Pokemon", "name": "Basic Pokemon", "name_en": "Basic Pokemon"},
		{"set_code": "SV1", "card_index": "050", "count": 10, "card_type": "Basic Energy", "name": "Energy", "name_en": "Energy"},
	]

	var builder = BuilderScript.new()
	var summary := builder.build_quick_summary(builder.build_context(deck))

	return run_checks([
		assert_str_contains(summary, "60", "summary should include total count"),
		assert_str_contains(summary, "8", "summary should include basic count"),
		assert_str_contains(summary, "10", "summary should include energy count"),
	])


func test_light_context_uses_readable_names_and_omits_card_details() -> String:
	var deck := DeckData.new()
	deck.id = 700003
	deck.deck_name = "light context test"
	deck.total_cards = 60
	deck.cards = [
		{"set_code": "SVP", "card_index": "067", "count": 3, "card_type": "Pokemon", "name": "bad-name", "name_en": "Charmander"},
	]

	var builder = BuilderScript.new()
	var context: Dictionary = builder.build_light_context(deck)
	var cards: Array = context.get("cards", [])
	var first: Dictionary = cards[0] if not cards.is_empty() else {}

	return run_checks([
		assert_eq(str(context.get("context_level", "")), "light", "first-pass context should be light"),
		assert_false(str(first.get("name", "")).contains("bad-name"), "display name should not expose broken raw names"),
		assert_false(first.has("set_code"), "light context should omit set_code details"),
		assert_true(context.has("available_tools"), "light context should declare get_deck_detail"),
	])


func test_play_guide_context_is_first_class() -> String:
	var deck := DeckData.new()
	deck.id = 700004
	deck.deck_name = "Snorlax test"
	deck.total_cards = 60
	deck.cards = [
		{"set_code": "CS5aC", "card_index": "093", "count": 4, "card_type": "Pokemon", "name": "Snorlax", "name_en": "Snorlax"},
		{"set_code": "CSVH1C", "card_index": "043", "count": 4, "card_type": "Item", "name": "Nest Ball", "name_en": "Nest Ball"},
	]

	var builder = BuilderScript.new()
	var context: Dictionary = builder.build_play_guide_context(deck)

	return run_checks([
		assert_eq(str(context.get("context_level", "")), "play_guide", "play questions should have a dedicated compact context"),
		assert_true(context.has("core_cards"), "play guide context should expose core cards"),
		assert_true(context.has("engine_cards"), "play guide context should expose engine cards"),
		assert_true(context.has("plan_hints"), "play guide context should expose plan hints"),
	])


func test_detailed_context_includes_card_text_for_tool_answers() -> String:
	var deck := DeckData.new()
	deck.id = 700005
	deck.deck_name = "compact test"
	deck.total_cards = 60
	deck.cards = [
		{"set_code": "CS5aC", "card_index": "093", "count": 4, "card_type": "Pokemon", "name": "Snorlax", "name_en": "Snorlax"},
	]

	var builder = BuilderScript.new()
	var context: Dictionary = builder.build_detailed_context(deck)
	var cards: Array = context.get("cards", [])
	var first: Dictionary = cards[0] if not cards.is_empty() else {}

	return run_checks([
		assert_eq(str(context.get("context_level", "")), "detailed", "detail context should be marked detailed"),
		assert_true(first.has("set_code"), "detail context should keep card identity"),
		assert_true(first.has("attacks"), "detail context should include attacks for get_deck_detail answers"),
		assert_true(first.has("abilities"), "detail context should include abilities for get_deck_detail answers"),
		assert_true(first.has("description"), "detail context should include card text/description"),
		assert_true(first.has("retreat_cost"), "detail context should include retreat cost"),
	])
