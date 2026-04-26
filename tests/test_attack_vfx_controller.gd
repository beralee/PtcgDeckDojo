class_name TestAttackVfxController
extends TestBase


const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")
const BattleCardViewScript = preload("res://scenes/battle/BattleCardView.gd")


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


func _make_scene_stub() -> Control:
	var battle_scene = BattleSceneScript.new()
	var main_area := Control.new()
	main_area.name = "MainArea"
	main_area.position = Vector2(40, 24)
	main_area.size = Vector2(1280, 720)
	battle_scene.add_child(main_area)

	var center_field := Control.new()
	center_field.name = "CenterField"
	center_field.position = Vector2(80, 20)
	center_field.size = Vector2(1200, 760)
	main_area.add_child(center_field)

	var my_active := BattleCardViewScript.new()
	my_active.custom_minimum_size = Vector2(130, 182)
	my_active.size = my_active.custom_minimum_size
	my_active.position = Vector2(180, 460)
	center_field.add_child(my_active)
	var opp_active := BattleCardViewScript.new()
	opp_active.custom_minimum_size = Vector2(130, 182)
	opp_active.size = opp_active.custom_minimum_size
	opp_active.position = Vector2(780, 120)
	center_field.add_child(opp_active)

	var opp_bench_0 := BattleCardViewScript.new()
	opp_bench_0.custom_minimum_size = Vector2(120, 168)
	opp_bench_0.size = opp_bench_0.custom_minimum_size
	opp_bench_0.position = Vector2(560, 210)
	center_field.add_child(opp_bench_0)
	var opp_bench_1 := BattleCardViewScript.new()
	opp_bench_1.custom_minimum_size = Vector2(120, 168)
	opp_bench_1.size = opp_bench_1.custom_minimum_size
	opp_bench_1.position = Vector2(710, 210)
	center_field.add_child(opp_bench_1)

	battle_scene.set("_my_active", my_active)
	battle_scene.set("_opp_active", opp_active)
	battle_scene.set("_view_player", 0)
	battle_scene.set("_slot_card_views", {
		"opp_bench_0": opp_bench_0,
		"opp_bench_1": opp_bench_1,
	})

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_card("Dragapult ex", "P"), 0))
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_card("Charizard ex", "R"), 1))
	gsm.game_state.players[1].active_pokemon = defender_slot

	return battle_scene


func test_play_preview_vfx_creates_cast_travel_and_impact_nodes() -> String:
	var battle_scene := _make_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	var registry: RefCounted = battle_scene.get("_battle_attack_vfx_registry")
	var entries: Array = registry.call("get_preview_entries")
	var first_profile: RefCounted = (entries[0] as Dictionary).get("profile", null)

	controller.call("play_preview_vfx", battle_scene, first_profile)

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var cast_node: Node = sequence.get_node_or_null("AttackVfxCast") if sequence != null else null
	var travel_node: Node = sequence.get_node_or_null("AttackVfxTravel0") if sequence != null else null
	var impact_node: Node = sequence.get_node_or_null("AttackVfxImpact0") if sequence != null else null

	return run_checks([
		assert_not_null(overlay, "Preview should create an attack VFX overlay"),
		assert_not_null(sequence, "Preview should create a VFX sequence root"),
		assert_eq(str(sequence.get_meta("profile_id", "")), "hero_dragapult_ex", "Preview should tag the sequence with the selected profile"),
		assert_not_null(cast_node, "Preview should create an attacker-side cast node"),
		assert_not_null(travel_node, "Preview should create a travel node between source and target"),
		assert_not_null(impact_node, "Preview should create a target-side impact node"),
	])


func test_dragapult_preview_vfx_prefers_authored_layers_over_generic_geometry() -> String:
	var battle_scene := _make_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	var registry: RefCounted = battle_scene.get("_battle_attack_vfx_registry")
	var profile: RefCounted = registry.call("resolve_profile", _make_pokemon_card("Dragapult ex", "P"), "Phantom Dive")

	controller.call("play_preview_vfx", battle_scene, profile)

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var cast_node: Control = sequence.get_node_or_null("AttackVfxCast") as Control if sequence != null else null
	var travel_node: Control = sequence.get_node_or_null("AttackVfxTravel0") as Control if sequence != null else null
	var impact_node: Control = sequence.get_node_or_null("AttackVfxImpact0") as Control if sequence != null else null
	var residue_node: Control = sequence.get_node_or_null("AttackVfxResidue0") as Control if sequence != null else null
	var shockwave_node: Node = sequence.get_node_or_null("AttackVfxShockwave0") if sequence != null else null

	return run_checks([
		assert_not_null(sequence, "Dragapult preview should still create a sequence root"),
		assert_not_null(cast_node.get_node_or_null("MouthChargeTexture") if cast_node != null else null, "Dragapult preview should render the authored cast texture"),
		assert_null(cast_node.get_node_or_null("Core") if cast_node != null else null, "Dragapult preview should not render the old generic cast core"),
		assert_not_null(travel_node.get_node_or_null("FlameStreamCoreTexture") if travel_node != null else null, "Dragapult preview should render an authored travel core"),
		assert_null(travel_node.get_node_or_null("Beam") if travel_node != null else null, "Dragapult preview should not render the old generic beam"),
		assert_not_null(impact_node.get_node_or_null("ImpactBloomTexture") if impact_node != null else null, "Dragapult preview should render an authored impact bloom"),
		assert_null(impact_node.get_node_or_null("ImpactCore") if impact_node != null else null, "Dragapult preview should not render the old generic impact burst"),
		assert_not_null(residue_node.get_node_or_null("EmbersSmokeTexture") if residue_node != null else null, "Dragapult preview should render an authored residue layer"),
		assert_null(shockwave_node, "Dragapult preview should suppress the generic shockwave bar"),
	])


func test_counter_transfer_ability_vfx_uses_siphon_profile_and_damage_labels() -> String:
	var battle_scene := _make_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	controller.call("play_counter_transfer_vfx", battle_scene, {
		"ability_vfx": "counter_transfer",
		"counter_count": 3,
		"damage_amount": 30,
		"source": {"player_index": 0, "slot_kind": "active", "slot_index": 0},
		"target": {"player_index": 1, "slot_kind": "bench", "slot_index": 0},
		"caster": {"player_index": 0, "slot_kind": "active", "slot_index": 0},
	})

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var cast_node: Control = sequence.get_node_or_null("AttackVfxCast") as Control if sequence != null else null
	var travel_node: Control = sequence.get_node_or_null("AttackVfxTravel0") as Control if sequence != null else null
	var impact_node: Control = sequence.get_node_or_null("AttackVfxImpact0") as Control if sequence != null else null
	var source_label: Label = sequence.get_node_or_null("CounterTransferSourceLabel") as Label if sequence != null else null
	var target_label: Label = sequence.get_node_or_null("CounterTransferTargetLabel") as Label if sequence != null else null
	var caster_aura: Control = sequence.get_node_or_null("CounterTransferCasterAura") as Control if sequence != null else null

	return run_checks([
		assert_not_null(sequence, "Counter-transfer ability should create a VFX sequence root"),
		assert_eq(str(sequence.get_meta("profile_id", "")), "ability_counter_transfer", "Counter-transfer ability should use its dedicated siphon profile"),
		assert_not_null(cast_node, "Counter-transfer ability should create a source-side cast node"),
		assert_not_null(travel_node, "Counter-transfer ability should animate counters traveling to the target"),
		assert_not_null(impact_node, "Counter-transfer ability should create a target impact node"),
		assert_eq(source_label.text if source_label != null else "", "-30", "Source label should show removed damage counters"),
		assert_eq(target_label.text if target_label != null else "", "+30", "Target label should show added damage counters"),
		assert_not_null(caster_aura, "Counter-transfer ability should flash the ability user"),
	])


func test_warm_profile_populates_runtime_texture_caches_before_first_play() -> String:
	var battle_scene := _make_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	var registry: RefCounted = battle_scene.get("_battle_attack_vfx_registry")
	var profile: RefCounted = registry.call("resolve_profile", _make_pokemon_card("Dragapult ex", "P"), "Phantom Dive")

	controller.call("warm_profile", profile)

	var texture_cache: Dictionary = controller.get("_texture_cache")
	var base_texture_cache: Dictionary = controller.get("_base_texture_cache")
	var texture_region_cache: Dictionary = controller.get("_texture_region_cache")

	return run_checks([
		assert_true(texture_cache.size() >= 4, "Prewarming should populate the runtime texture cache for Dragapult's authored layers"),
		assert_true(base_texture_cache.size() >= texture_cache.size(), "Prewarming should keep the base texture cache populated for reused assets"),
		assert_true(texture_region_cache.size() >= 4, "Prewarming should precompute visible texture regions before the first live play"),
	])


func test_precomputed_region_cache_supplies_visible_bounds_without_runtime_scan() -> String:
	var battle_scene := _make_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	var resource_path := "res://assets/textures/vfx/attribute_lightning/impact/impact_bloom.png"
	var texture: Texture2D = load(resource_path)

	var region: Rect2 = controller.call("_get_precomputed_visible_region", resource_path, texture)

	return run_checks([
		assert_true(region.size.x > 0.0 and region.size.y > 0.0, "Precomputed region cache should provide a non-empty visible region for known VFX assets"),
		assert_true(region.size.x <= float(texture.get_width()) and region.size.y <= float(texture.get_height()), "Precomputed region should stay within the source texture bounds"),
	])


func test_charizard_attack_vfx_omits_launch_travel_segment() -> String:
	var battle_scene := _make_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	var gsm: GameStateMachine = battle_scene.get("_gsm") as GameStateMachine
	var charizard_slot := PokemonSlot.new()
	charizard_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_card("Charizard ex", "R"), 0))
	gsm.game_state.players[0].active_pokemon = charizard_slot
	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{"attack_name": "Burning Darkness", "target_pokemon_name": "Charizard ex", "damage": 180},
		3,
		"attack"
	)

	controller.call("play_attack_vfx", battle_scene, action)

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var travel_node: Node = sequence.get_node_or_null("AttackVfxTravel0") if sequence != null else null

	return run_checks([
		assert_not_null(sequence, "Charizard attack should still create a sequence root"),
		assert_null(travel_node, "Charizard attack should currently omit the launch/travel segment entirely"),
	])


func test_localized_charizard_attack_vfx_uses_hero_profile_via_name_en() -> String:
	var battle_scene := _make_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	var gsm: GameStateMachine = battle_scene.get("_gsm") as GameStateMachine
	var localized_charizard_slot := PokemonSlot.new()
	localized_charizard_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_card_with_name_en("喷火龙ex", "Charizard ex", "R"), 0))
	gsm.game_state.players[0].active_pokemon = localized_charizard_slot
	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{"attack_name": "烈焰黑暗", "target_pokemon_name": "Charizard ex", "damage": 180},
		3,
		"attack"
	)

	controller.call("play_attack_vfx", battle_scene, action)

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var impact_node: Control = sequence.get_node_or_null("AttackVfxImpact0") as Control if sequence != null else null
	var residue_node: Control = sequence.get_node_or_null("AttackVfxResidue0") as Control if sequence != null else null
	var impact_texture_rect: Node = impact_node.get_node_or_null("ImpactBloomTexture") if impact_node != null else null
	var residue_texture_rect: Node = residue_node.get_node_or_null("EmbersSmokeTexture") if residue_node != null else null

	return run_checks([
		assert_not_null(sequence, "Localized Charizard attack should still create a sequence root"),
		assert_eq(str(sequence.get_meta("profile_id", "")), "hero_charizard_ex", "Localized Charizard attack should resolve to the dedicated hero profile"),
		assert_not_null(impact_texture_rect, "Localized Charizard hero profile should attach the authored impact bloom texture"),
		assert_not_null(residue_texture_rect, "Localized Charizard hero profile should attach the authored embers texture"),
	])


func test_palkia_hero_attack_vfx_uses_cast_plus_impact_without_travel() -> String:
	var battle_scene := _make_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	var gsm: GameStateMachine = battle_scene.get("_gsm") as GameStateMachine
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_card("Origin Forme Palkia VSTAR", "W"), 0))
	gsm.game_state.players[0].active_pokemon = attacker_slot
	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{"attack_name": "Subspace Swell", "target_pokemon_name": "Charizard ex", "damage": 260},
		3,
		"attack"
	)

	controller.call("play_attack_vfx", battle_scene, action)

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var cast_node: Node = sequence.get_node_or_null("AttackVfxCast") if sequence != null else null
	var travel_node: Node = sequence.get_node_or_null("AttackVfxTravel0") if sequence != null else null
	var impact_node: Node = sequence.get_node_or_null("AttackVfxImpact0") if sequence != null else null
	var shockwave_node: Node = sequence.get_node_or_null("AttackVfxShockwave0") if sequence != null else null

	return run_checks([
		assert_not_null(sequence, "Palkia hero attack should still create a sequence root"),
		assert_eq(str(sequence.get_meta("profile_id", "")), "hero_palkia_vstar", "Palkia hero attack should resolve to the dedicated hero profile"),
		assert_not_null(cast_node, "Palkia hero attack should keep a cast node"),
		assert_null(travel_node, "Palkia hero attack should omit travel until a clean travel subject exists"),
		assert_not_null(impact_node, "Palkia hero attack should still create an impact node"),
		assert_not_null(shockwave_node, "Palkia hero attack should still create the authored water ripple shockwave"),
	])


func test_gholdengo_hero_attack_vfx_uses_coin_burst_without_travel() -> String:
	var battle_scene := _make_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	var gsm: GameStateMachine = battle_scene.get("_gsm") as GameStateMachine
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_card("Gholdengo ex", "M"), 0))
	gsm.game_state.players[0].active_pokemon = attacker_slot
	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{"attack_name": "Make It Rain", "target_pokemon_name": "Charizard ex", "damage": 200},
		3,
		"attack"
	)

	controller.call("play_attack_vfx", battle_scene, action)

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var cast_node: Control = sequence.get_node_or_null("AttackVfxCast") as Control if sequence != null else null
	var travel_node: Control = sequence.get_node_or_null("AttackVfxTravel0") as Control if sequence != null else null
	var impact_node: Control = sequence.get_node_or_null("AttackVfxImpact0") as Control if sequence != null else null
	var shockwave_node: Node = sequence.get_node_or_null("AttackVfxShockwave0") if sequence != null else null

	return run_checks([
		assert_not_null(sequence, "Gholdengo hero attack should still create a sequence root"),
		assert_eq(str(sequence.get_meta("profile_id", "")), "hero_gholdengo_ex", "Gholdengo hero attack should resolve to the dedicated hero profile"),
		assert_not_null(cast_node, "Gholdengo hero attack should keep a cast glint before the burst"),
		assert_null(travel_node, "Gholdengo hero attack should no longer render a stream; it should read as a coin burst"),
		assert_not_null(impact_node, "Gholdengo hero attack should still create an impact node"),
		assert_not_null(shockwave_node, "Gholdengo hero attack should create an authored burst ring support layer"),
	])


func test_fire_fallback_attack_vfx_uses_impact_only_sequence() -> String:
	var battle_scene := _make_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	var gsm: GameStateMachine = battle_scene.get("_gsm") as GameStateMachine
	var fire_slot := PokemonSlot.new()
	fire_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_card("Fire Test", "R"), 0))
	gsm.game_state.players[0].active_pokemon = fire_slot
	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{"attack_name": "Flare Test", "target_pokemon_name": "Charizard ex", "damage": 120},
		3,
		"attack"
	)

	controller.call("play_attack_vfx", battle_scene, action)

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var cast_node: Node = sequence.get_node_or_null("AttackVfxCast") if sequence != null else null
	var travel_node: Node = sequence.get_node_or_null("AttackVfxTravel0") if sequence != null else null
	var impact_node: Node = sequence.get_node_or_null("AttackVfxImpact0") if sequence != null else null
	var residue_node: Node = sequence.get_node_or_null("AttackVfxResidue0") if sequence != null else null
	var shockwave_node: Node = sequence.get_node_or_null("AttackVfxShockwave0") if sequence != null else null

	return run_checks([
		assert_not_null(sequence, "Fire fallback attack should still create a sequence root"),
		assert_not_null(cast_node, "Fire fallback attack should still create an empty cast node for sequence timing"),
		assert_eq(cast_node.get_child_count(), 0, "Fire fallback attack should not render a visible cast layer"),
		assert_null(travel_node, "Fire fallback attack should not create a travel node"),
		assert_null(shockwave_node, "Fire fallback attack should not create the generic shockwave bar"),
		assert_not_null(impact_node, "Fire fallback attack should still create an impact node"),
		assert_not_null(residue_node, "Fire fallback attack should still create a residue node"),
	])


func test_fire_attribute_attack_vfx_uses_impact_only_sequence() -> String:
	var battle_scene := _make_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	var gsm: GameStateMachine = battle_scene.get("_gsm") as GameStateMachine
	var fire_slot := PokemonSlot.new()
	fire_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_card_with_attack_cost("Gouging Fire ex", "R", "CCC"), 0))
	gsm.game_state.players[0].active_pokemon = fire_slot
	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{"attack_name": "Burning Charge", "target_pokemon_name": "Charizard ex", "damage": 260},
		3,
		"attack"
	)

	controller.call("play_attack_vfx", battle_scene, action)

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var travel_node: Node = sequence.get_node_or_null("AttackVfxTravel0") if sequence != null else null
	var impact_node: Node = sequence.get_node_or_null("AttackVfxImpact0") if sequence != null else null
	var residue_node: Node = sequence.get_node_or_null("AttackVfxResidue0") if sequence != null else null

	return run_checks([
		assert_not_null(sequence, "Fire-attribute attack should still create a sequence root"),
		assert_null(travel_node, "Fire-attribute attack should not create a travel node"),
		assert_not_null(impact_node, "Fire-attribute attack should still create an impact node"),
		assert_not_null(residue_node, "Fire-attribute attack should still create a residue node"),
	])


func test_lightning_attribute_rollout_uses_cast_travel_impact_without_generic_shockwave() -> String:
	var battle_scene := _make_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	var gsm: GameStateMachine = battle_scene.get("_gsm") as GameStateMachine
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_card("Miraidon ex", "L"), 0))
	gsm.game_state.players[0].active_pokemon = attacker_slot
	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{"attack_name": "Photon Blaster", "target_pokemon_name": "Charizard ex", "damage": 220},
		3,
		"attack"
	)

	controller.call("play_attack_vfx", battle_scene, action)

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var cast_node: Node = sequence.get_node_or_null("AttackVfxCast") if sequence != null else null
	var travel_node: Node = sequence.get_node_or_null("AttackVfxTravel0") if sequence != null else null
	var impact_node: Node = sequence.get_node_or_null("AttackVfxImpact0") if sequence != null else null
	var shockwave_node: Node = sequence.get_node_or_null("AttackVfxShockwave0") if sequence != null else null

	return run_checks([
		assert_not_null(sequence, "Lightning rollout should still create a sequence root"),
		assert_not_null(cast_node, "Lightning rollout should keep a cast node"),
		assert_not_null(travel_node, "Lightning rollout should keep a travel node"),
		assert_not_null(impact_node, "Lightning rollout should still create an impact node"),
		assert_null(shockwave_node, "Lightning rollout should suppress the generic shockwave bar"),
	])


func test_dragon_attribute_rollout_uses_cast_plus_impact_without_travel_or_shockwave() -> String:
	var battle_scene := _make_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	var gsm: GameStateMachine = battle_scene.get("_gsm") as GameStateMachine
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_card("Regidrago VSTAR", "N"), 0))
	gsm.game_state.players[0].active_pokemon = attacker_slot
	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{"attack_name": "Apex Dragon", "target_pokemon_name": "Charizard ex", "damage": 200},
		3,
		"attack"
	)

	controller.call("play_attack_vfx", battle_scene, action)

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var cast_node: Node = sequence.get_node_or_null("AttackVfxCast") if sequence != null else null
	var travel_node: Node = sequence.get_node_or_null("AttackVfxTravel0") if sequence != null else null
	var impact_node: Node = sequence.get_node_or_null("AttackVfxImpact0") if sequence != null else null
	var shockwave_node: Node = sequence.get_node_or_null("AttackVfxShockwave0") if sequence != null else null

	return run_checks([
		assert_not_null(sequence, "Dragon rollout should still create a sequence root"),
		assert_not_null(cast_node, "Dragon rollout should keep a cast node"),
		assert_null(travel_node, "Dragon rollout should omit travel when no clean shared travel asset exists"),
		assert_not_null(impact_node, "Dragon rollout should still create an impact node"),
		assert_null(shockwave_node, "Dragon rollout should suppress the generic shockwave bar"),
	])


func test_water_fallback_attack_vfx_uses_impact_only_sequence() -> String:
	var battle_scene := _make_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	var gsm: GameStateMachine = battle_scene.get("_gsm") as GameStateMachine
	var water_slot := PokemonSlot.new()
	water_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_card("Water Test", "W"), 0))
	gsm.game_state.players[0].active_pokemon = water_slot
	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{"attack_name": "Wave Test", "target_pokemon_name": "Charizard ex", "damage": 120},
		3,
		"attack"
	)

	controller.call("play_attack_vfx", battle_scene, action)

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var travel_node: Node = sequence.get_node_or_null("AttackVfxTravel0") if sequence != null else null
	var impact_node: Node = sequence.get_node_or_null("AttackVfxImpact0") if sequence != null else null
	var residue_node: Node = sequence.get_node_or_null("AttackVfxResidue0") if sequence != null else null

	return run_checks([
		assert_not_null(sequence, "Water fallback attack should still create a sequence root"),
		assert_null(travel_node, "Water fallback attack should not create a travel node"),
		assert_not_null(impact_node, "Water fallback attack should create an impact node"),
		assert_not_null(residue_node, "Water fallback attack should create a residue node"),
	])


func test_psychic_fallback_attack_vfx_keeps_travel_sequence() -> String:
	var battle_scene := _make_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	var gsm: GameStateMachine = battle_scene.get("_gsm") as GameStateMachine
	var psychic_slot := PokemonSlot.new()
	psychic_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_card("Psychic Test", "P"), 0))
	gsm.game_state.players[0].active_pokemon = psychic_slot
	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{"attack_name": "Mind Pulse", "target_pokemon_name": "Charizard ex", "damage": 120},
		3,
		"attack"
	)

	controller.call("play_attack_vfx", battle_scene, action)

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var cast_node: Node = sequence.get_node_or_null("AttackVfxCast") if sequence != null else null
	var travel_node: Node = sequence.get_node_or_null("AttackVfxTravel0") if sequence != null else null
	var impact_node: Node = sequence.get_node_or_null("AttackVfxImpact0") if sequence != null else null

	return run_checks([
		assert_not_null(sequence, "Psychic fallback attack should create a sequence root"),
		assert_not_null(cast_node, "Psychic fallback attack should create a cast node"),
		assert_not_null(travel_node, "Psychic fallback attack should keep a travel node"),
		assert_not_null(impact_node, "Psychic fallback attack should create an impact node"),
	])


func test_play_attack_vfx_supports_multiple_targets() -> String:
	var battle_scene := _make_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{
			"attack_name": "Phantom Dive",
			"damage": 200,
			"targets": [
				{"player_index": 1, "slot_kind": "bench", "slot_index": 0},
				{"player_index": 1, "slot_kind": "bench", "slot_index": 1},
			],
		},
		3,
		"attack"
	)

	controller.call("play_attack_vfx", battle_scene, action)

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var impact_a: Node = sequence.get_node_or_null("AttackVfxImpact0") if sequence != null else null
	var impact_b: Node = sequence.get_node_or_null("AttackVfxImpact1") if sequence != null else null
	var travel_a: Node = sequence.get_node_or_null("AttackVfxTravel0") if sequence != null else null
	var travel_b: Node = sequence.get_node_or_null("AttackVfxTravel1") if sequence != null else null

	return run_checks([
		assert_not_null(sequence, "Multi-target attack should still create a sequence root"),
		assert_not_null(travel_a, "Multi-target attack should create the first travel segment"),
		assert_not_null(travel_b, "Multi-target attack should create the second travel segment"),
		assert_not_null(impact_a, "Multi-target attack should create the first impact"),
		assert_not_null(impact_b, "Multi-target attack should create the second impact"),
	])


func test_fallback_preview_vfx_creates_shockwave_and_residue_layers() -> String:
	var battle_scene := _make_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	var registry: RefCounted = battle_scene.get("_battle_attack_vfx_registry")
	var fallback_profile: RefCounted = registry.call("resolve_profile", null, "Unknown Attack")

	controller.call("play_preview_vfx", battle_scene, fallback_profile)

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var shockwave: Node = sequence.get_node_or_null("AttackVfxShockwave0") if sequence != null else null
	var residue: Node = sequence.get_node_or_null("AttackVfxResidue0") if sequence != null else null

	return run_checks([
		assert_not_null(sequence, "Fallback preview should still create a sequence root"),
		assert_not_null(shockwave, "Fallback preview should create a dedicated shockwave layer"),
		assert_not_null(residue, "Fallback preview should create a lingering residue layer"),
	])


func test_charizard_preview_omits_generic_shockwave_bar() -> String:
	var battle_scene := _make_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	var registry: RefCounted = battle_scene.get("_battle_attack_vfx_registry")
	var entries: Array = registry.call("get_preview_entries")
	var charizard_profile: RefCounted = (entries[1] as Dictionary).get("profile", null)

	controller.call("play_preview_vfx", battle_scene, charizard_profile)

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var shockwave: Node = sequence.get_node_or_null("AttackVfxShockwave0") if sequence != null else null

	return run_checks([
		assert_not_null(sequence, "Charizard preview should still create a sequence root"),
		assert_null(shockwave, "Asset-driven Charizard preview should not mix in the generic horizontal shockwave bar"),
	])


func test_charizard_preview_uses_generated_flame_texture_layers() -> String:
	var battle_scene := _make_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	var registry: RefCounted = battle_scene.get("_battle_attack_vfx_registry")
	var entries: Array = registry.call("get_preview_entries")
	var charizard_profile: RefCounted = (entries[1] as Dictionary).get("profile", null)

	controller.call("play_preview_vfx", battle_scene, charizard_profile)

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var cast_node: Node = sequence.get_node_or_null("AttackVfxCast") if sequence != null else null
	var travel_node: Node = sequence.get_node_or_null("AttackVfxTravel0") if sequence != null else null
	var impact_node: Node = sequence.get_node_or_null("AttackVfxImpact0") if sequence != null else null
	var residue_node: Node = sequence.get_node_or_null("AttackVfxResidue0") if sequence != null else null
	var mouth_charge: TextureRect = cast_node.get_node_or_null("MouthChargeTexture") as TextureRect if cast_node != null else null
	var flame_core: TextureRect = travel_node.get_node_or_null("FlameStreamCoreTexture") as TextureRect if travel_node != null else null
	var flame_outer: TextureRect = travel_node.get_node_or_null("FlameStreamOuterTexture") as TextureRect if travel_node != null else null
	var impact_texture_rect: TextureRect = impact_node.get_node_or_null("ImpactBloomTexture") as TextureRect if impact_node != null else null
	var residue_texture_rect: TextureRect = residue_node.get_node_or_null("EmbersSmokeTexture") as TextureRect if residue_node != null else null
	var mouth_charge_atlas: AtlasTexture = mouth_charge.texture as AtlasTexture if mouth_charge != null else null
	var flame_core_atlas: AtlasTexture = flame_core.texture as AtlasTexture if flame_core != null else null
	var flame_outer_atlas: AtlasTexture = flame_outer.texture as AtlasTexture if flame_outer != null else null
	var mouth_charge_is_tight := mouth_charge_atlas != null and mouth_charge_atlas.region.size.x < mouth_charge_atlas.atlas.get_width()
	var mouth_charge_is_pretrimmed := mouth_charge != null and mouth_charge_atlas == null and mouth_charge.texture.get_width() < 1200
	var impact_atlas: AtlasTexture = impact_texture_rect.texture as AtlasTexture if impact_texture_rect != null else null
	var residue_atlas: AtlasTexture = residue_texture_rect.texture as AtlasTexture if residue_texture_rect != null else null

	return run_checks([
		assert_null(mouth_charge, "Charizard should not use the current mouth-charge art until a real mouth-aligned asset exists"),
		assert_null(travel_node, "Charizard should currently omit the launch/travel segment entirely"),
		assert_null(flame_core, "Charizard should not render the current travel core while launch visuals are disabled"),
		assert_null(flame_outer, "Charizard should not use the current outer flame art while it still contains the fake yellow guide bar"),
		assert_not_null(impact_texture_rect, "Charizard impact should attach the generated impact bloom texture"),
		assert_not_null(residue_texture_rect, "Charizard residue should attach the generated embers texture"),
		assert_eq(cast_node.get_child_count(), 0, "Asset-driven Charizard cast should stay empty until a proper cast asset exists"),
		assert_eq(impact_node.get_child_count(), 1, "Asset-driven Charizard impact should only keep the authored bloom layer"),
		assert_eq(residue_node.get_child_count(), 1, "Asset-driven Charizard residue should only keep the authored embers layer"),
		assert_true(impact_atlas != null and impact_atlas.region.size.x < impact_atlas.atlas.get_width(), "Impact bloom should use a single flipbook frame instead of rendering the whole sprite sheet"),
		assert_true(residue_atlas != null and residue_atlas.region.size.x < residue_atlas.atlas.get_width(), "Residue should use a single flipbook frame instead of rendering the whole sprite sheet"),
	])
