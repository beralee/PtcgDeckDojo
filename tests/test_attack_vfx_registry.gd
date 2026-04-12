class_name TestAttackVfxRegistry
extends TestBase

const BattleAttackVfxRegistryScript = preload("res://scripts/ui/battle/BattleAttackVfxRegistry.gd")
const BattleAttackVfxProfileScript = preload("res://scripts/ui/battle/BattleAttackVfxProfile.gd")


func _make_pokemon_card(name: String, energy_type: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 220
	card.energy_type = energy_type
	card.attacks = [{
		"name": "Test Attack",
		"cost": energy_type,
		"damage": "120",
		"text": "",
		"is_vstar_power": false,
	}]
	return card


func _make_pokemon_card_with_name_en(name: String, name_en: String, energy_type: String) -> CardData:
	var card := _make_pokemon_card(name, energy_type)
	card.name_en = name_en
	return card


func _make_pokemon_card_with_attack_cost(name: String, energy_type: String, attack_cost: String) -> CardData:
	var card := _make_pokemon_card(name, energy_type)
	card.attacks = [{
		"name": "Cost Test",
		"cost": attack_cost,
		"damage": "120",
		"text": "",
		"is_vstar_power": false,
	}]
	return card


func test_resolve_profile_prefers_named_hero_override() -> String:
	var registry = BattleAttackVfxRegistryScript.new()
	var dragapult := _make_pokemon_card("Dragapult ex", "P")
	var charizard := _make_pokemon_card("Charizard ex", "R")

	var dragapult_profile = registry.call("resolve_profile", dragapult, "Phantom Dive")
	var charizard_profile = registry.call("resolve_profile", charizard, "Burning Darkness")

	return run_checks([
		assert_true(dragapult_profile is BattleAttackVfxProfileScript, "Hero override lookup should return a BattleAttackVfxProfile"),
		assert_true(charizard_profile is BattleAttackVfxProfileScript, "Second hero override lookup should also return a BattleAttackVfxProfile"),
		assert_eq(str(dragapult_profile.profile_id), "hero_dragapult_ex", "Dragapult ex should resolve to its dedicated hero profile"),
		assert_eq(str(charizard_profile.profile_id), "hero_charizard_ex", "Charizard ex should resolve to its dedicated hero profile"),
	])


func test_resolve_profile_prefers_name_en_for_localized_charizard_hero_override() -> String:
	var registry = BattleAttackVfxRegistryScript.new()
	var localized_charizard := _make_pokemon_card_with_name_en("喷火龙ex", "Charizard ex", "R")

	var profile = registry.call("resolve_profile", localized_charizard, "Burning Darkness")

	return run_checks([
		assert_true(profile is BattleAttackVfxProfileScript, "Localized Charizard lookup should still return a BattleAttackVfxProfile"),
		assert_eq(str(profile.profile_id), "hero_charizard_ex", "Localized Charizard should resolve through name_en to the dedicated hero profile"),
	])


func test_resolve_profile_falls_back_to_energy_type_template() -> String:
	var registry = BattleAttackVfxRegistryScript.new()
	var water_attacker := _make_pokemon_card("Water Test", "W")
	var fire_attacker := _make_pokemon_card("Fire Test", "R")

	var profile = registry.call("resolve_profile", water_attacker, "Wave Test")
	var fire_profile = registry.call("resolve_profile", fire_attacker, "Flare Test")

	return run_checks([
		assert_true(profile is BattleAttackVfxProfileScript, "Fallback lookup should still return a BattleAttackVfxProfile"),
		assert_eq(str(profile.profile_id), "fallback_water", "Water attackers should fall back to the water profile"),
		assert_eq(str(profile.template_id), "water_arc", "Water fallback should use the water template"),
		assert_true(fire_profile is BattleAttackVfxProfileScript, "Fire fallback should still return a BattleAttackVfxProfile"),
		assert_eq(str(fire_profile.profile_id), "fallback_fire", "Fire attackers should fall back to the fire profile"),
		assert_true(fire_profile.get("enable_travel") == false, "Fire fallback should disable the launch/travel segment"),
		assert_true(fire_profile.get("enable_generic_cast") == false, "Fire fallback should disable generic cast visuals"),
		assert_true(fire_profile.get("enable_generic_shockwave") == false, "Fire fallback should disable the generic shockwave bar"),
	])


func test_resolve_profile_supports_all_attribute_fallbacks() -> String:
	var registry = BattleAttackVfxRegistryScript.new()
	var expected := {
		"W": "fallback_water",
		"R": "fallback_fire",
		"L": "fallback_lightning",
		"P": "fallback_psychic",
		"D": "fallback_darkness",
		"G": "fallback_grass",
		"F": "fallback_fighting",
		"M": "fallback_metal",
		"N": "fallback_dragon",
		"C": "fallback_colorless",
	}
	var checks: Array[String] = []
	for energy_type: String in expected.keys():
		var profile = registry.call("resolve_profile", _make_pokemon_card("%s Test" % energy_type, energy_type), "Shared Attack")
		checks.append(assert_true(profile is BattleAttackVfxProfileScript, "%s fallback should resolve to a profile" % energy_type))
		checks.append(assert_eq(str(profile.profile_id), str(expected[energy_type]), "%s fallback should resolve to the expected profile id" % energy_type))
	return run_checks(checks)


func test_resolve_profile_uses_attacker_energy_type_for_fire_cards() -> String:
	var registry = BattleAttackVfxRegistryScript.new()
	var gouging_fire_like := _make_pokemon_card_with_attack_cost("Gouging Fire ex", "R", "CCC")

	var fire_profile = registry.call("resolve_profile", gouging_fire_like, "Burning Charge")

	return run_checks([
		assert_true(fire_profile is BattleAttackVfxProfileScript, "Fire lookup should still return a BattleAttackVfxProfile"),
		assert_eq(str(fire_profile.profile_id), "fallback_fire", "Fire attackers should resolve from their own attribute rather than attack cost"),
		assert_true(fire_profile.get("enable_travel") == false, "Fire profile should still use impact-only presentation"),
	])


func test_resolve_profile_without_attacker_data_returns_generic_safe_profile() -> String:
	var registry = BattleAttackVfxRegistryScript.new()

	var profile = registry.call("resolve_profile", null, "Unknown Attack")

	return run_checks([
		assert_true(profile is BattleAttackVfxProfileScript, "Missing attacker data should still produce a valid profile"),
		assert_eq(str(profile.profile_id), "fallback_generic", "Missing attacker data should fall back to a generic profile"),
		assert_eq(int(profile.spark_count), 8, "Generic profile should keep a safe default spark count"),
	])


func test_hero_profiles_push_stronger_scale_flash_and_shake_than_generic() -> String:
	var registry = BattleAttackVfxRegistryScript.new()
	var hero_profile = registry.call("resolve_profile", _make_pokemon_card("Charizard ex", "R"), "Burning Darkness")
	var generic_profile = registry.call("resolve_profile", null, "Unknown Attack")

	return run_checks([
		assert_true(float(hero_profile.impact_radius) > float(generic_profile.impact_radius), "Hero profile should have a larger impact radius than generic"),
		assert_true(float(hero_profile.travel_width) > float(generic_profile.travel_width), "Hero profile should have a thicker travel stroke than generic"),
		assert_true(float(hero_profile.screen_shake_strength) > float(generic_profile.screen_shake_strength), "Hero profile should shake harder than generic"),
		assert_true(float(hero_profile.target_flash_strength) > float(generic_profile.target_flash_strength), "Hero profile should flash harder than generic"),
	])


func test_charizard_hero_profile_exposes_generated_flame_asset_paths() -> String:
	var registry = BattleAttackVfxRegistryScript.new()
	var hero_profile = registry.call("resolve_profile", _make_pokemon_card("Charizard ex", "R"), "Burning Darkness")
	var asset_paths: Dictionary = hero_profile.asset_paths if hero_profile != null else {}

	return run_checks([
		assert_true(asset_paths.has("flame_stream_core"), "Charizard profile should include a flame stream core asset"),
		assert_false(asset_paths.has("mouth_charge"), "Charizard should not expose the current mouth charge asset until it is visually correct"),
		assert_false(asset_paths.has("flame_stream_outer"), "Charizard should not expose the current outer stream asset while it still contains the fake guide bar"),
		assert_true(asset_paths.has("impact_bloom_flipbook"), "Charizard profile should include an impact bloom asset"),
		assert_true(asset_paths.has("embers_smoke_flipbook"), "Charizard profile should include an embers/smoke asset"),
	])


func test_charizard_hero_profile_prefers_asset_driven_cast_and_travel() -> String:
	var registry = BattleAttackVfxRegistryScript.new()
	var hero_profile = registry.call("resolve_profile", _make_pokemon_card("Charizard ex", "R"), "Burning Darkness")
	var asset_driven_cast = hero_profile.get("asset_driven_cast")
	var asset_driven_travel = hero_profile.get("asset_driven_travel")
	var asset_driven_impact = hero_profile.get("asset_driven_impact")
	var asset_driven_residue = hero_profile.get("asset_driven_residue")
	var enable_generic_cast = hero_profile.get("enable_generic_cast")
	var enable_travel = hero_profile.get("enable_travel")

	return run_checks([
		assert_true(asset_driven_cast == false, "Charizard should keep cast disabled until a real mouth-aligned cast asset exists"),
		assert_true(asset_driven_travel == true, "Charizard should keep its travel asset available for later reuse"),
		assert_true(asset_driven_impact == true, "Charizard should prefer asset-driven impact instead of generic radial spark clutter"),
		assert_true(asset_driven_residue == true, "Charizard should prefer asset-driven residue instead of generic square particles"),
		assert_true(enable_generic_cast == false, "Charizard should not fall back to generic cast rays when its dedicated cast asset is disabled"),
		assert_true(enable_travel == false, "Charizard should currently disable the launch/travel segment until the source alignment is solved"),
	])


func test_dragapult_hero_profile_uses_authored_asset_layers_instead_of_generic_shapes() -> String:
	var registry = BattleAttackVfxRegistryScript.new()
	var hero_profile = registry.call("resolve_profile", _make_pokemon_card("Dragapult ex", "P"), "Phantom Dive")

	return run_checks([
		assert_true(hero_profile.get("asset_driven_cast") == true, "Dragapult hero profile should use an authored cast asset"),
		assert_true(hero_profile.get("asset_driven_travel") == true, "Dragapult hero profile should use authored travel assets"),
		assert_true(hero_profile.get("asset_driven_impact") == true, "Dragapult hero profile should use an authored impact asset"),
		assert_true(hero_profile.get("asset_driven_residue") == true, "Dragapult hero profile should use an authored residue asset"),
		assert_true(hero_profile.get("enable_generic_cast") == false, "Dragapult hero profile should not fall back to generic cast rays"),
		assert_true(hero_profile.get("enable_generic_shockwave") == false, "Dragapult hero profile should suppress the generic shockwave bar"),
	])


func test_palkia_hero_profile_uses_space_water_layers_without_travel() -> String:
	var registry = BattleAttackVfxRegistryScript.new()
	var hero_profile = registry.call("resolve_profile", _make_pokemon_card("Origin Forme Palkia VSTAR", "W"), "Subspace Swell")

	return run_checks([
		assert_eq(str(hero_profile.profile_id), "hero_palkia_vstar", "Palkia VSTAR should resolve to its dedicated hero profile"),
		assert_true(hero_profile.get("asset_driven_cast") == true, "Palkia hero profile should use an authored cast asset"),
		assert_true(hero_profile.get("asset_driven_impact") == true, "Palkia hero profile should use an authored impact asset"),
		assert_true(hero_profile.get("enable_travel") == false, "Palkia hero profile should avoid travel until a clean water-space travel subject exists"),
		assert_true(hero_profile.get("enable_generic_shockwave") == false, "Palkia hero profile should suppress the generic shockwave bar"),
	])


func test_palkia_hero_profile_resolves_via_name_en_for_localized_card() -> String:
	var registry = BattleAttackVfxRegistryScript.new()
	var localized_palkia := _make_pokemon_card_with_name_en("起源帕路奇亚VSTAR", "Origin Forme Palkia VSTAR", "W")

	var profile = registry.call("resolve_profile", localized_palkia, "Subspace Swell")

	return run_checks([
		assert_true(profile is BattleAttackVfxProfileScript, "Localized Palkia should still resolve to a VFX profile"),
		assert_eq(str(profile.profile_id), "hero_palkia_vstar", "Localized Palkia should resolve through name_en to the dedicated hero profile"),
	])


func test_gholdengo_hero_profile_uses_coin_burst_impact_layers() -> String:
	var registry = BattleAttackVfxRegistryScript.new()
	var hero_profile = registry.call("resolve_profile", _make_pokemon_card("Gholdengo ex", "M"), "Make It Rain")

	return run_checks([
		assert_eq(str(hero_profile.profile_id), "hero_gholdengo_ex", "Gholdengo ex should resolve to its dedicated hero profile"),
		assert_true(hero_profile.get("asset_driven_cast") == true, "Gholdengo hero profile should use an authored cast asset"),
		assert_true(hero_profile.get("asset_driven_impact") == true, "Gholdengo hero profile should use an authored impact asset"),
		assert_true(hero_profile.get("enable_travel") == false, "Gholdengo hero profile should now read as an impact-side coin explosion instead of a stream"),
		assert_true(hero_profile.asset_specs.has("shockwave"), "Gholdengo hero profile should expose an authored burst ring support layer"),
		assert_true(hero_profile.get("enable_generic_shockwave") == false, "Gholdengo hero profile should suppress the generic shockwave bar"),
	])


func test_attribute_rollout_covers_target_ace_attackers_via_shared_profiles() -> String:
	var registry = BattleAttackVfxRegistryScript.new()
	var cases := [
		{"name": "Miraidon ex", "energy_type": "L", "expected_profile": "hero_miraidon_ex"},
		{"name": "Origin Forme Palkia VSTAR", "energy_type": "W", "expected_profile": "hero_palkia_vstar"},
		{"name": "Gholdengo ex", "energy_type": "M", "expected_profile": "hero_gholdengo_ex"},
		{"name": "Regidrago VSTAR", "energy_type": "N", "expected_profile": "hero_regidrago_vstar"},
		{"name": "Raging Bolt ex", "energy_type": "N", "expected_profile": "hero_raging_bolt_ex"},
		{"name": "Lugia VSTAR", "energy_type": "C", "expected_profile": "hero_lugia_vstar"},
		{"name": "Arceus VSTAR", "energy_type": "C", "expected_profile": "hero_arceus_vstar"},
		{"name": "Giratina VSTAR", "energy_type": "N", "expected_profile": "hero_giratina_vstar"},
		{"name": "Origin Forme Dialga VSTAR", "energy_type": "M", "expected_profile": "hero_dialga_vstar"},
		{"name": "Iron Hands ex", "energy_type": "L", "expected_profile": "hero_iron_hands_ex"},
	]
	var checks: Array[String] = []
	for case_variant: Variant in cases:
		var case_data: Dictionary = case_variant
		var profile = registry.call("resolve_profile", _make_pokemon_card(str(case_data.name), str(case_data.energy_type)), "Shared Ace Attack")
		checks.append(assert_true(profile is BattleAttackVfxProfileScript, "%s should resolve to a battle VFX profile" % str(case_data.name)))
		checks.append(assert_eq(str(profile.profile_id), str(case_data.expected_profile), "%s should resolve through its attribute-wide profile" % str(case_data.name)))
	return run_checks(checks)


func test_lightning_fallback_uses_asset_driven_travel_without_generic_shockwave() -> String:
	var registry = BattleAttackVfxRegistryScript.new()
	var profile = registry.call("resolve_profile", _make_pokemon_card("Lightning Test", "L"), "Photon Blaster")

	return run_checks([
		assert_eq(str(profile.profile_id), "fallback_lightning", "Generic lightning attackers should use the shared lightning profile"),
		assert_true(profile.get("asset_driven_cast") == true, "Lightning rollout should keep the cast subject asset-driven"),
		assert_true(profile.get("asset_driven_travel") == true, "Lightning rollout should keep a readable asset-driven travel path"),
		assert_true(profile.get("enable_generic_shockwave") == false, "Lightning rollout should suppress the generic shockwave bar"),
	])


func test_new_hero_profiles_cover_remaining_priority_ace_attackers() -> String:
	var registry = BattleAttackVfxRegistryScript.new()
	var cases := [
		{"name": "Miraidon ex", "energy_type": "L", "expected_profile": "hero_miraidon_ex"},
		{"name": "Iron Hands ex", "energy_type": "L", "expected_profile": "hero_iron_hands_ex"},
		{"name": "Regidrago VSTAR", "energy_type": "N", "expected_profile": "hero_regidrago_vstar"},
		{"name": "Raging Bolt ex", "energy_type": "N", "expected_profile": "hero_raging_bolt_ex"},
		{"name": "Lugia VSTAR", "energy_type": "C", "expected_profile": "hero_lugia_vstar"},
		{"name": "Arceus VSTAR", "energy_type": "C", "expected_profile": "hero_arceus_vstar"},
		{"name": "Giratina VSTAR", "energy_type": "N", "expected_profile": "hero_giratina_vstar"},
		{"name": "Origin Forme Dialga VSTAR", "energy_type": "M", "expected_profile": "hero_dialga_vstar"},
	]
	var checks: Array[String] = []
	for case_variant: Variant in cases:
		var case_data: Dictionary = case_variant
		var profile = registry.call("resolve_profile", _make_pokemon_card(str(case_data.name), str(case_data.energy_type)), "Hero Attack")
		checks.append(assert_eq(str(profile.profile_id), str(case_data.expected_profile), "%s should resolve to its new dedicated hero profile" % str(case_data.name)))
	return run_checks(checks)


func test_dragon_fallback_uses_cast_plus_impact_without_generic_travel() -> String:
	var registry = BattleAttackVfxRegistryScript.new()
	var profile = registry.call("resolve_profile", _make_pokemon_card("Dragon Test", "N"), "Apex Dragon")

	return run_checks([
		assert_eq(str(profile.profile_id), "fallback_dragon", "Generic dragon attackers should use the shared dragon profile"),
		assert_true(profile.get("asset_driven_cast") == true, "Dragon rollout should keep the cast subject asset-driven"),
		assert_true(profile.get("asset_driven_impact") == true, "Dragon rollout should keep the impact subject asset-driven"),
		assert_true(profile.get("enable_travel") == false, "Dragon rollout should avoid generic travel geometry when no clean travel asset exists"),
		assert_true(profile.get("enable_generic_shockwave") == false, "Dragon rollout should suppress the generic shockwave bar"),
	])


func test_colorless_fallback_keeps_asset_driven_travel_and_suppresses_generic_shockwave() -> String:
	var registry = BattleAttackVfxRegistryScript.new()
	var profile = registry.call("resolve_profile", _make_pokemon_card("Colorless Test", "C"), "Trinity Nova")

	return run_checks([
		assert_eq(str(profile.profile_id), "fallback_colorless", "Generic colorless attackers should use the shared colorless profile"),
		assert_true(profile.get("asset_driven_travel") == true, "Colorless rollout should keep the shared travel sheen as the main subject"),
		assert_true(profile.get("enable_generic_shockwave") == false, "Colorless rollout should suppress the generic shockwave bar"),
	])


func test_preview_entries_expose_clean_chinese_labels() -> String:
	var registry = BattleAttackVfxRegistryScript.new()
	var entries: Array = registry.call("get_preview_entries")
	var labels: Array[String] = []
	for entry_variant: Variant in entries:
		if entry_variant is Dictionary:
			labels.append(str((entry_variant as Dictionary).get("label", "")))

	return run_checks([
		assert_true(labels.has("Dragapult ex | Phantom Burst"), "Preview labels should include the Dragapult hero entry"),
		assert_true(labels.has("Charizard ex | Flame Burst"), "Preview labels should include the Charizard hero entry"),
		assert_true(labels.has("Palkia VSTAR | Spatial Tide"), "Preview labels should include the Palkia hero entry"),
		assert_true(labels.has("Gholdengo ex | Golden Burst"), "Preview labels should include the Gholdengo hero entry"),
		assert_true(labels.has("Miraidon ex | Thunder Rail"), "Preview labels should include the Miraidon hero entry"),
		assert_true(labels.has("Iron Hands ex | Heavy Voltage"), "Preview labels should include the Iron Hands hero entry"),
		assert_true(labels.has("Regidrago VSTAR | Dragon Crest"), "Preview labels should include the Regidrago hero entry"),
		assert_true(labels.has("Raging Bolt ex | Storm Fang"), "Preview labels should include the Raging Bolt hero entry"),
		assert_true(labels.has("Lugia VSTAR | Tempest Arc"), "Preview labels should include the Lugia hero entry"),
		assert_true(labels.has("Arceus VSTAR | Celestial Lance"), "Preview labels should include the Arceus hero entry"),
		assert_true(labels.has("Giratina VSTAR | Rift Howl"), "Preview labels should include the Giratina hero entry"),
		assert_true(labels.has("Dialga VSTAR | Chrono Forge"), "Preview labels should include the Dialga hero entry"),
		assert_true(labels.has("Fallback Fire | Flame Burst"), "Preview labels should expose the shared fire entry"),
		assert_true(labels.has("Fallback Water | Water Arc"), "Preview labels should expose the shared water entry"),
		assert_true(labels.has("Fallback Lightning | Thunder Crack"), "Preview labels should expose the shared lightning entry"),
		assert_true(labels.has("Fallback Psychic | Psychic Wave"), "Preview labels should expose the shared psychic entry"),
		assert_true(labels.has("Fallback Darkness | Shadow Burst"), "Preview labels should expose the shared darkness entry"),
		assert_true(labels.has("Fallback Grass | Verdant Burst"), "Preview labels should expose the shared grass entry"),
		assert_true(labels.has("Fallback Fighting | Body Blow"), "Preview labels should expose the shared fighting entry"),
		assert_true(labels.has("Fallback Metal | Forged Impact"), "Preview labels should expose the shared metal entry"),
		assert_true(labels.has("Fallback Dragon | Draconic Surge"), "Preview labels should expose the shared dragon entry"),
		assert_true(labels.has("Fallback Colorless | Pearlescent Burst"), "Preview labels should expose the shared colorless entry"),
	])
