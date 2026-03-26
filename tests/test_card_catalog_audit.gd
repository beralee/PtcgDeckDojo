class_name TestCardCatalogAudit
extends TestBase

const CardCatalogAuditRunner = preload("res://tests/CardCatalogAudit.gd")

var _cached_report: Dictionary = {}


func test_cached_cards_have_registry_and_smoke_coverage() -> String:
	if _cached_report.is_empty():
		_cached_report = CardCatalogAuditRunner.new().run()
		print(_cached_report.get("report_text", ""))

	var registry_failures: Array = _cached_report.get("registry_failures", [])
	var smoke_failures: Array = _cached_report.get("smoke_failures", [])
	var status_matrix_text: String = str(_cached_report.get("status_matrix_text", ""))
	var failure_parts: Array[String] = []

	if not registry_failures.is_empty():
		failure_parts.append("registry=%d" % registry_failures.size())
	if not smoke_failures.is_empty():
		failure_parts.append("smoke=%d" % smoke_failures.size())

	return run_checks([
		assert_gt(int(_cached_report.get("cached_cards", 0)), 0, "Should discover cached cards"),
		assert_true(status_matrix_text.contains("Card Status Matrix"), "Should generate status matrix report"),
		assert_true(failure_parts.is_empty(), "Card catalog audit failed: %s" % ", ".join(failure_parts)),
	])


func test_attack_only_pokemon_interaction_status_uses_attack_steps() -> String:
	var audit := CardCatalogAuditRunner.new()
	var dragapult_ex := _make_pokemon_card(
		"Dragapult ex",
		"Stage 2",
		"52a205820de799a53a689f23cbeb8622",
		[
			{"name": "Jet Headbutt", "cost": "C", "damage": "70", "text": "", "is_vstar_power": false},
			{"name": "Phantom Dive", "cost": "RP", "damage": "200", "text": "Put 6 damage counters on your opponent's Benched Pokemon in any way you like.", "is_vstar_power": false},
		]
	)
	var haxorus := _make_pokemon_card(
		"Haxorus",
		"Stage 2",
		"e45788bd7d9ffec5b3da3730d2dc806f",
		[
			{"name": "Axe Down", "cost": "F", "damage": "", "text": "If your opponent's Active Pokemon has any Special Energy attached, it is Knocked Out.", "is_vstar_power": false},
			{"name": "Dragon Pulse", "cost": "FM", "damage": "230", "text": "Discard the top 3 cards of your deck.", "is_vstar_power": false},
		]
	)

	return run_checks([
		assert_eq(audit.call("_inspect_interaction_status", dragapult_ex), "present", "Attack-only cards with target selection should report present interaction"),
		assert_eq(audit.call("_inspect_interaction_status", haxorus), "none", "Attack-only cards without player choice should report none"),
	])


func _make_pokemon_card(
	name: String,
	stage: String,
	effect_id: String,
	attacks: Array
) -> CardData:
	var card_data := CardData.new()
	var attack_list: Array[Dictionary] = []
	for attack: Variant in attacks:
		if attack is Dictionary:
			attack_list.append(attack)
	card_data.name = name
	card_data.name_en = name
	card_data.card_type = "Pokemon"
	card_data.energy_type = "N"
	card_data.hp = 200
	card_data.stage = stage
	card_data.effect_id = effect_id
	card_data.attacks = attack_list
	return card_data
