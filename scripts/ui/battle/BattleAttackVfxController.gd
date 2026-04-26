class_name BattleAttackVfxController
extends RefCounted

const OVERLAY_NAME := "AttackVfxOverlay"
const SEQUENCE_NAME := "AttackVfxSequence"
const CAST_NAME := "AttackVfxCast"
const TRAVEL_PREFIX := "AttackVfxTravel"
const IMPACT_PREFIX := "AttackVfxImpact"
const SHOCKWAVE_PREFIX := "AttackVfxShockwave"
const RESIDUE_PREFIX := "AttackVfxResidue"
const FLASH_NAME := "AttackVfxFlash"
const COUNTER_SOURCE_LABEL_NAME := "CounterTransferSourceLabel"
const COUNTER_TARGET_LABEL_NAME := "CounterTransferTargetLabel"
const COUNTER_CASTER_AURA_NAME := "CounterTransferCasterAura"
const BattleAttackVfxRegistryScript := preload("res://scripts/ui/battle/BattleAttackVfxRegistry.gd")
const PRECOMPUTED_REGION_CACHE_PATH := "res://assets/textures/vfx/visible_region_cache.json"

var _texture_cache: Dictionary = {}
var _base_texture_cache: Dictionary = {}
var _texture_region_cache: Dictionary = {}
var _precomputed_texture_region_cache: Dictionary = {}
var _precomputed_texture_region_cache_loaded: bool = false


func warm_profile(profile: RefCounted) -> void:
	if profile == null:
		return
	var warmed_paths: Dictionary = {}
	var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
	for spec_variant: Variant in asset_specs.values():
		if not (spec_variant is Dictionary):
			continue
		var spec: Dictionary = spec_variant as Dictionary
		var resource_path: String = str(spec.get("path", ""))
		if resource_path == "" or warmed_paths.has(resource_path):
			continue
		warmed_paths[resource_path] = true
		var frames: int = int(spec.get("frames", 1))
		if frames > 1:
			_load_base_texture(resource_path)
		else:
			_load_texture(resource_path)
	var asset_paths: Dictionary = profile.get("asset_paths") if profile != null else {}
	for path_variant: Variant in asset_paths.values():
		var resource_path: String = str(path_variant)
		if resource_path == "" or warmed_paths.has(resource_path):
			continue
		warmed_paths[resource_path] = true
		_load_texture(resource_path)


func warm_profiles(profiles: Array) -> void:
	for profile_variant: Variant in profiles:
		if profile_variant is RefCounted:
			warm_profile(profile_variant as RefCounted)


func ensure_overlay(scene: Object) -> Control:
	var overlay: Control = scene.get("_attack_vfx_overlay") as Control
	if overlay != null and is_instance_valid(overlay):
		return overlay
	overlay = Control.new()
	overlay.name = OVERLAY_NAME
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 200
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var host: Node = _overlay_host(scene)
	if host != null:
		host.add_child(overlay)
	scene.set("_attack_vfx_overlay", overlay)
	return overlay


func resolve_impact_position(scene: Object, action: GameAction) -> Vector2:
	var target_positions: Array[Vector2] = resolve_target_positions(scene, action)
	return target_positions[0] if not target_positions.is_empty() else Vector2.ZERO


func resolve_target_positions(scene: Object, action: GameAction) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for spec_variant: Variant in _resolve_target_specs(scene, action):
		if spec_variant is Dictionary:
			var spec: Dictionary = spec_variant
			positions.append(spec.get("position", Vector2.ZERO))
	return positions


func resolve_source_position(scene: Object, player_index: int) -> Vector2:
	var source_anchor: Control = _source_anchor(scene, player_index)
	if source_anchor != null:
		return source_anchor.global_position + source_anchor.size * 0.5
	var center_field: Control = _center_field(scene)
	if center_field != null:
		var t := 0.32 if player_index == int(scene.get("_view_player")) else 0.68
		var y := 0.74 if player_index == int(scene.get("_view_player")) else 0.26
		return center_field.global_position + center_field.size * Vector2(t, y)
	return Vector2.ZERO


func play_attack_vfx(scene: Object, action: GameAction) -> void:
	if scene == null or action == null:
		return
	var overlay: Control = ensure_overlay(scene)
	if overlay == null:
		return
	overlay.visible = true
	var registry: RefCounted = scene.get("_battle_attack_vfx_registry") as RefCounted
	if registry == null:
		registry = BattleAttackVfxRegistryScript.new()
		scene.set("_battle_attack_vfx_registry", registry)
	var profile: RefCounted = registry.call("resolve_profile", _attacker_card_data(scene, action), str(action.data.get("attack_name", "")))
	var target_specs: Array = _resolve_target_specs(scene, action)
	if target_specs.is_empty():
		target_specs.append({
			"position": resolve_impact_position(scene, action),
			"anchor": null,
			"impact_style": "damage",
		})
	var source_position: Vector2 = _resolve_attack_source_position(scene, action.player_index, profile, target_specs)
	_play_sequence(scene, overlay, profile, source_position, target_specs)


func play_preview_vfx(scene: Object, profile: RefCounted) -> void:
	if scene == null or profile == null:
		return
	var overlay: Control = ensure_overlay(scene)
	if overlay == null:
		return
	overlay.visible = true
	var target_specs := [{
		"position": _preview_target_position(scene),
		"anchor": scene.get("_opp_active") if scene.get("_opp_active") is Control else null,
		"impact_style": "damage",
	}]
	var source_position: Vector2 = _resolve_attack_source_position(scene, int(scene.get("_view_player")), profile, target_specs)
	_play_sequence(scene, overlay, profile, source_position, target_specs)


func play_counter_transfer_vfx(scene: Object, data: Dictionary) -> void:
	if scene == null or data.is_empty():
		return
	var overlay: Control = ensure_overlay(scene)
	if overlay == null:
		return
	overlay.visible = true
	var source_data: Variant = data.get("source", {})
	var target_data: Variant = data.get("target", {})
	if not (source_data is Dictionary) or not (target_data is Dictionary):
		return
	var source_spec: Dictionary = _target_spec_from_dict(scene, source_data as Dictionary)
	var target_spec: Dictionary = _target_spec_from_dict(scene, target_data as Dictionary)
	if source_spec.is_empty() or target_spec.is_empty():
		return
	target_spec["impact_style"] = "counter_transfer"
	var registry: RefCounted = scene.get("_battle_attack_vfx_registry") as RefCounted
	if registry == null:
		registry = BattleAttackVfxRegistryScript.new()
		scene.set("_battle_attack_vfx_registry", registry)
	var profile: RefCounted = registry.call("get_counter_transfer_profile")
	var source_position: Vector2 = source_spec.get("position", Vector2.ZERO)
	_play_sequence(scene, overlay, profile, source_position, [target_spec])
	var sequence: Control = overlay.get_child(overlay.get_child_count() - 1) as Control if overlay.get_child_count() > 0 else null
	if sequence != null:
		_add_counter_transfer_accents(scene, sequence, overlay, source_spec, target_spec, data)


func _play_sequence(
	scene: Object,
	overlay: Control,
	profile: RefCounted,
	source_position: Vector2,
	target_specs: Array
) -> void:
	var sequence := Control.new()
	sequence.name = SEQUENCE_NAME
	sequence.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sequence.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sequence.set_meta("profile_id", str(profile.get("profile_id")) if profile != null else "")
	sequence.set_meta("source_position", source_position)
	sequence.set_meta("target_count", target_specs.size())
	overlay.add_child(sequence)

	var source_local: Vector2 = _overlay_local_position(overlay, source_position)
	var first_target_local := source_local
	if not target_specs.is_empty():
		var first_target: Dictionary = target_specs[0] if target_specs[0] is Dictionary else {}
		first_target_local = _overlay_local_position(overlay, first_target.get("position", source_position))
	var cast_node: Control = _create_cast_node(source_local, first_target_local, profile)
	sequence.add_child(cast_node)

	for index: int in target_specs.size():
		var target_spec: Dictionary = target_specs[index] if target_specs[index] is Dictionary else {}
		var target_position: Vector2 = target_spec.get("position", Vector2.ZERO)
		if profile == null or profile.get("enable_travel") != false:
			sequence.add_child(_create_travel_node(source_position, target_position, overlay, profile, index))
		sequence.add_child(_create_impact_node(_overlay_local_position(overlay, target_position), profile, index, target_spec))
		if profile == null or profile.get("enable_generic_shockwave") != false or _has_asset_spec(profile, "shockwave", ""):
			sequence.add_child(_create_shockwave_node(_overlay_local_position(overlay, target_position), profile, index))
		sequence.add_child(_create_residue_node(_overlay_local_position(overlay, target_position), profile, index))

	var flash: ColorRect = _create_flash_node(profile)
	sequence.add_child(flash)

	if scene is Node and (scene as Node).is_inside_tree():
		_play_sequence_animation(scene as Node, sequence, cast_node, flash, profile, target_specs)


func _preview_source_position(scene: Object) -> Vector2:
	var my_active: Control = scene.get("_my_active") as Control
	if my_active != null:
		return my_active.global_position + my_active.size * 0.5
	var center_field: Control = _center_field(scene)
	if center_field != null:
		return center_field.global_position + center_field.size * Vector2(0.32, 0.74)
	return Vector2(420.0, 520.0)


func _preview_target_position(scene: Object) -> Vector2:
	var opp_active: Control = scene.get("_opp_active") as Control
	if opp_active != null:
		return opp_active.global_position + opp_active.size * 0.5
	var center_field: Control = _center_field(scene)
	if center_field != null:
		return center_field.global_position + center_field.size * Vector2(0.68, 0.26)
	return Vector2(860.0, 220.0)


func _resolve_attack_source_position(scene: Object, player_index: int, profile: RefCounted, target_specs: Array) -> Vector2:
	var base: Vector2 = resolve_source_position(scene, player_index)
	if profile == null:
		return base
	if profile.get("asset_driven_cast") != true:
		return base
	var source_anchor: Control = _source_anchor(scene, player_index)
	if source_anchor == null:
		return base
	var target_position: Vector2 = base
	if not target_specs.is_empty() and target_specs[0] is Dictionary:
		target_position = (target_specs[0] as Dictionary).get("position", base)
	var direction := (target_position - base).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2(1.0, 0.0)
	return base


func _overlay_local_position(overlay: Control, global_position: Vector2) -> Vector2:
	return global_position - overlay.global_position


func _overlay_host(scene: Object) -> Node:
	if scene is Node:
		return scene as Node
	return null


func _center_field(scene: Object) -> Control:
	if scene is Node:
		return (scene as Node).get_node_or_null("MainArea/CenterField") as Control
	return null


func _source_anchor(scene: Object, player_index: int) -> Control:
	var view_player: int = int(scene.get("_view_player"))
	if player_index == view_player:
		return scene.get("_my_active") as Control
	return scene.get("_opp_active") as Control


func _attacker_card_data(scene: Object, action: GameAction) -> CardData:
	var gsm: GameStateMachine = scene.get("_gsm") as GameStateMachine
	if gsm == null or gsm.game_state == null:
		return null
	if action.player_index < 0 or action.player_index >= gsm.game_state.players.size():
		return null
	var player: PlayerState = gsm.game_state.players[action.player_index]
	if player == null or player.active_pokemon == null:
		return null
	return player.active_pokemon.get_card_data()


func _resolve_target_specs(scene: Object, action: GameAction) -> Array:
	var resolved: Array = []
	var targets_variant: Variant = action.data.get("targets", [])
	if targets_variant is Array and not (targets_variant as Array).is_empty():
		for target_variant: Variant in targets_variant:
			if target_variant is Dictionary:
				var spec: Dictionary = _target_spec_from_dict(scene, target_variant as Dictionary)
				if not spec.is_empty():
					resolved.append(spec)
	if not resolved.is_empty():
		return resolved
	var impact_position: Vector2 = _default_target_position(scene, action)
	if impact_position != Vector2.ZERO:
		resolved.append({
			"position": impact_position,
			"anchor": _target_anchor(scene, 1 - clampi(action.player_index, 0, 1)),
			"impact_style": "damage",
		})
	return resolved


func _target_spec_from_dict(scene: Object, target: Dictionary) -> Dictionary:
	var player_index: int = int(target.get("player_index", 1 - int(scene.get("_view_player"))))
	var slot_kind: String = str(target.get("slot_kind", "active"))
	var slot_index: int = int(target.get("slot_index", 0))
	var anchor: Control = _target_slot_anchor(scene, player_index, slot_kind, slot_index)
	if anchor == null:
		return {}
	return {
		"position": anchor.global_position + anchor.size * 0.5,
		"anchor": anchor,
		"impact_style": str(target.get("impact_style", "damage")),
		"slot_kind": slot_kind,
		"slot_index": slot_index,
	}


func _default_target_position(scene: Object, action: GameAction) -> Vector2:
	var target_player_index := 1 - clampi(action.player_index, 0, 1)
	var target_anchor: Control = _target_anchor(scene, target_player_index)
	if target_anchor != null:
		return target_anchor.global_position + target_anchor.size * 0.5
	var center_field: Control = _center_field(scene)
	if center_field != null:
		return center_field.global_position + center_field.size * 0.5
	return Vector2.ZERO


func _target_anchor(scene: Object, target_player_index: int) -> Control:
	var view_player: int = int(scene.get("_view_player"))
	if target_player_index == view_player:
		return scene.get("_my_active") as Control
	return scene.get("_opp_active") as Control


func _target_slot_anchor(scene: Object, player_index: int, slot_kind: String, slot_index: int) -> Control:
	if slot_kind == "active":
		return _target_anchor(scene, player_index)
	if slot_kind == "bench":
		var view_player: int = int(scene.get("_view_player"))
		var key := "%s_bench_%d" % ["my" if player_index == view_player else "opp", slot_index]
		var slot_views: Dictionary = scene.get("_slot_card_views")
		var slot_view: Variant = slot_views.get(key, null)
		if slot_view is Control:
			return slot_view as Control
	return null


func _create_cast_node(source_local: Vector2, first_target_local: Vector2, profile: RefCounted) -> Control:
	var cast := Control.new()
	cast.name = CAST_NAME
	cast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cast.position = source_local
	cast.scale = Vector2(0.42, 0.42)
	cast.modulate.a = 0.0
	var primary: Color = profile.get("primary_color") if profile != null else Color(1.0, 0.9, 0.4, 1.0)
	var secondary: Color = profile.get("secondary_color") if profile != null else Color(1.0, 0.5, 0.2, 1.0)
	var radius: float = float(profile.get("impact_radius")) * 0.4 if profile != null else 48.0
	var asset_driven_cast: bool = profile.get("asset_driven_cast") == true if profile != null else false
	var enable_generic_cast: bool = profile.get("enable_generic_cast") != false if profile != null else true
	if enable_generic_cast and not asset_driven_cast:
		var core := ColorRect.new()
		core.name = "Core"
		core.color = primary
		core.size = Vector2(radius, radius)
		core.position = -core.size * 0.5
		cast.add_child(core)
		var ray_count: int = int(profile.get("cast_ray_count")) if profile != null else 6
		for index: int in ray_count:
			var ray := ColorRect.new()
			ray.name = "CastRay%d" % index
			ray.color = secondary
			ray.size = Vector2(radius * 1.9, 12.0)
			ray.pivot_offset = Vector2(0.0, 6.0)
			ray.position = Vector2.ZERO
			ray.rotation = TAU * float(index) / float(max(1, ray_count))
			cast.add_child(ray)
	var mouth_charge: TextureRect = _make_texture_layer_from_spec("MouthChargeTexture", _get_asset_spec(profile, "cast", "mouth_charge", 1), Vector2(radius * 2.4, radius * 2.4))
	if mouth_charge != null:
		var cast_angle := source_local.angle_to_point(first_target_local)
		mouth_charge.position = Vector2(-mouth_charge.size.x * 0.32, -mouth_charge.size.y * 0.5)
		mouth_charge.rotation = cast_angle
		cast.add_child(mouth_charge)
	return cast


func _create_travel_node(
	source_global: Vector2,
	target_global: Vector2,
	overlay: Control,
	profile: RefCounted,
	index: int
) -> Control:
	var travel := Control.new()
	travel.name = "%s%d" % [TRAVEL_PREFIX, index]
	travel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	travel.set_meta("source_position", source_global)
	travel.set_meta("target_position", target_global)
	var source_local: Vector2 = _overlay_local_position(overlay, source_global)
	var target_local: Vector2 = _overlay_local_position(overlay, target_global)
	travel.position = source_local
	travel.modulate.a = 0.0
	var angle: float = source_local.angle_to_point(target_local)
	var distance: float = source_local.distance_to(target_local)
	var width: float = float(profile.get("travel_width")) if profile != null else 18.0
	var primary: Color = profile.get("primary_color") if profile != null else Color(1.0, 0.9, 0.4, 1.0)
	var asset_driven_travel: bool = profile.get("asset_driven_travel") == true if profile != null else false
	var head: ColorRect = null
	if not asset_driven_travel:
		var beam := ColorRect.new()
		beam.name = "Beam"
		beam.color = primary
		beam.size = Vector2(distance, width)
		beam.position = Vector2(0.0, -width * 0.5)
		beam.rotation = angle
		travel.add_child(beam)
		var trail_segments: int = int(profile.get("trail_segment_count")) if profile != null else 3
		for segment_index: int in trail_segments:
			var trail := ColorRect.new()
			trail.name = "Trail%d" % segment_index
			var trail_color := primary
			trail_color.a = max(0.14, 0.52 - segment_index * 0.08)
			trail.color = trail_color
			trail.size = Vector2(distance * (0.52 + segment_index * 0.1), max(6.0, width - segment_index * 2.0))
			trail.position = Vector2(0.0, -trail.size.y * 0.5)
			trail.rotation = angle
			travel.add_child(trail)
		head = ColorRect.new()
		head.name = "Head"
		head.color = primary.lightened(0.18)
		head.size = Vector2(width * 1.8, width * 1.8)
		head.position = Vector2(-head.size.x * 0.5, -head.size.y * 0.5)
		travel.add_child(head)
	var core_texture: TextureRect = _make_texture_layer_from_spec("FlameStreamCoreTexture", _get_asset_spec(profile, "travel_core", "flame_stream_core", 1), Vector2(distance, width * 2.6))
	if core_texture != null:
		core_texture.position = Vector2(0.0, -core_texture.size.y * 0.5)
		core_texture.rotation = angle
		travel.add_child(core_texture)
	var outer_texture: TextureRect = _make_texture_layer_from_spec("FlameStreamOuterTexture", _get_asset_spec(profile, "travel_outer", "flame_stream_outer", 1), Vector2(distance * 1.05, width * 3.4))
	if outer_texture != null:
		outer_texture.position = Vector2(0.0, -outer_texture.size.y * 0.5)
		outer_texture.rotation = angle
		var mod_color := outer_texture.modulate
		mod_color.a = 0.62
		outer_texture.modulate = mod_color
		travel.add_child(outer_texture)
	return travel


func _create_impact_node(target_local: Vector2, profile: RefCounted, index: int, target_spec: Dictionary) -> Control:
	var impact := Control.new()
	impact.name = "%s%d" % [IMPACT_PREFIX, index]
	impact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	impact.position = target_local
	impact.scale = Vector2(0.36, 0.36)
	impact.modulate.a = 0.0
	impact.set_meta("impact_style", str(target_spec.get("impact_style", "damage")))
	var primary: Color = profile.get("primary_color") if profile != null else Color(1.0, 0.9, 0.4, 1.0)
	var secondary: Color = profile.get("secondary_color") if profile != null else Color(1.0, 0.5, 0.2, 1.0)
	var radius: float = float(profile.get("impact_radius")) if profile != null else 84.0
	var asset_driven_impact: bool = profile.get("asset_driven_impact") == true if profile != null else false
	if not asset_driven_impact:
		var core := ColorRect.new()
		core.name = "ImpactCore"
		core.color = primary
		core.size = Vector2(radius * 0.9, radius * 0.9)
		core.position = -core.size * 0.5
		impact.add_child(core)
		var spark_count: int = max(8, int(profile.get("spark_count")) if profile != null else 8)
		for ray_index: int in spark_count:
			var ray := ColorRect.new()
			ray.name = "ImpactRay%d" % ray_index
			ray.color = secondary
			ray.size = Vector2(radius * 1.5, 13.0)
			ray.pivot_offset = Vector2(0.0, 6.5)
			ray.position = Vector2.ZERO
			ray.rotation = TAU * float(ray_index) / float(spark_count)
			impact.add_child(ray)
	var impact_texture: TextureRect = _make_texture_layer_from_spec("ImpactBloomTexture", _get_asset_spec(profile, "impact", "impact_bloom_flipbook", 4), Vector2(radius * 1.45, radius * 1.45))
	if impact_texture != null:
		impact_texture.position = -impact_texture.size * 0.5
		impact.add_child(impact_texture)
	var impact_support: TextureRect = _make_texture_layer_from_spec("ImpactSupportTexture", _get_asset_spec(profile, "impact_support", "", 1), Vector2(radius * 1.55, radius * 1.55))
	if impact_support != null:
		impact_support.position = -impact_support.size * 0.5
		impact.add_child(impact_support)
	return impact


func _create_shockwave_node(target_local: Vector2, profile: RefCounted, index: int) -> Control:
	var shockwave := Control.new()
	shockwave.name = "%s%d" % [SHOCKWAVE_PREFIX, index]
	shockwave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shockwave.position = target_local
	shockwave.scale = Vector2(0.2, 0.2)
	shockwave.modulate.a = 0.0
	var radius: float = float(profile.get("shockwave_radius")) if profile != null else 128.0
	var shockwave_texture: TextureRect = _make_texture_layer_from_spec("ShockwaveTexture", _get_asset_spec(profile, "shockwave", "", 1), Vector2(radius, radius))
	if shockwave_texture != null:
		shockwave_texture.position = -shockwave_texture.size * 0.5
		shockwave.add_child(shockwave_texture)
	else:
		var secondary: Color = profile.get("secondary_color") if profile != null else Color(1.0, 0.5, 0.2, 1.0)
		var ring := ColorRect.new()
		ring.name = "Ring"
		ring.color = secondary
		ring.size = Vector2(radius, max(16.0, radius * 0.12))
		ring.position = -ring.size * 0.5
		shockwave.add_child(ring)
	return shockwave


func _create_residue_node(target_local: Vector2, profile: RefCounted, index: int) -> Control:
	var residue := Control.new()
	residue.name = "%s%d" % [RESIDUE_PREFIX, index]
	residue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	residue.position = target_local
	residue.modulate.a = 0.0
	var primary: Color = profile.get("primary_color") if profile != null else Color(1.0, 0.9, 0.4, 1.0)
	var asset_driven_residue: bool = profile.get("asset_driven_residue") == true if profile != null else false
	if not asset_driven_residue:
		var count: int = int(profile.get("residue_count")) if profile != null else 5
		for particle_index: int in count:
			var particle := ColorRect.new()
			particle.name = "Residue%d" % particle_index
			var particle_color := primary
			particle_color.a = 0.42
			particle.color = particle_color
			var w := 14.0 + fmod(float(particle_index) * 7.0, 18.0)
			var h := 10.0 + fmod(float(particle_index) * 5.0, 12.0)
			particle.size = Vector2(w, h)
			particle.position = Vector2(-w * 0.5 + (particle_index % 3) * 18.0 - 18.0, -h * 0.5 + int(particle_index / 3) * 14.0 - 14.0)
			residue.add_child(particle)
	var residue_texture: TextureRect = _make_texture_layer_from_spec("EmbersSmokeTexture", _get_asset_spec(profile, "residue", "embers_smoke_flipbook", 4), Vector2(96.0, 96.0))
	if residue_texture != null:
		residue_texture.position = -residue_texture.size * 0.5
		var residue_color := residue_texture.modulate
		residue_color.a = 0.86
		residue_texture.modulate = residue_color
		residue.add_child(residue_texture)
	return residue


func _make_texture_layer(name: String, resource_path: String, size: Vector2) -> TextureRect:
	if resource_path.is_empty():
		return null
	var texture: Texture2D = _load_texture(resource_path)
	if texture == null:
		return null
	var rect := TextureRect.new()
	rect.name = name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size = size
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return rect


func _make_flipbook_texture_layer(name: String, resource_path: String, size: Vector2, frame_count: int) -> TextureRect:
	if resource_path.is_empty():
		return null
	var base_texture: Texture2D = _load_base_texture(resource_path)
	if base_texture == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = base_texture
	atlas.region = Rect2(0.0, 0.0, float(base_texture.get_width()) / float(max(1, frame_count)), float(base_texture.get_height()))
	var rect := TextureRect.new()
	rect.name = name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture = atlas
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size = size
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.set_meta("flipbook_frame_count", frame_count)
	return rect


func _make_texture_layer_from_spec(name: String, spec: Dictionary, size: Vector2) -> TextureRect:
	if spec.is_empty():
		return null
	var resource_path: String = str(spec.get("path", ""))
	if resource_path.is_empty():
		return null
	var frames: int = int(spec.get("frames", 1))
	if frames > 1:
		return _make_flipbook_texture_layer(name, resource_path, size, frames)
	return _make_texture_layer(name, resource_path, size)


func _get_asset_spec(profile: RefCounted, spec_key: String, legacy_key: String, default_frames: int) -> Dictionary:
	if profile == null:
		return {}
	var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
	if asset_specs.has(spec_key):
		var spec_variant: Variant = asset_specs.get(spec_key, {})
		if spec_variant is Dictionary:
			return (spec_variant as Dictionary).duplicate(true)
	var asset_paths: Dictionary = profile.get("asset_paths") if profile != null else {}
	if legacy_key != "" and asset_paths.has(legacy_key):
		return {
			"path": str(asset_paths.get(legacy_key, "")),
			"frames": default_frames,
		}
	return {}


func _has_asset_spec(profile: RefCounted, spec_key: String, legacy_key: String) -> bool:
	return not _get_asset_spec(profile, spec_key, legacy_key, 1).is_empty()


func _load_texture(resource_path: String) -> Texture2D:
	if _texture_cache.has(resource_path):
		var cached: Variant = _texture_cache[resource_path]
		if cached is Texture2D:
			return cached as Texture2D
	var base_texture: Texture2D = _load_base_texture(resource_path)
	if base_texture == null:
		return null
	var texture: Texture2D = _make_runtime_texture(resource_path, base_texture)
	_texture_cache[resource_path] = texture
	return texture


func _load_base_texture(resource_path: String) -> Texture2D:
	if _base_texture_cache.has(resource_path):
		var cached: Variant = _base_texture_cache[resource_path]
		if cached is Texture2D:
			return cached as Texture2D
	var base_texture: Texture2D = load(resource_path) as Texture2D
	if base_texture == null:
		return null
	_base_texture_cache[resource_path] = base_texture
	return base_texture


func _make_runtime_texture(resource_path: String, base_texture: Texture2D) -> Texture2D:
	var region: Rect2 = _compute_visible_region(resource_path, base_texture)
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		return base_texture
	if is_equal_approx(region.position.x, 0.0) \
		and is_equal_approx(region.position.y, 0.0) \
		and is_equal_approx(region.size.x, float(base_texture.get_width())) \
		and is_equal_approx(region.size.y, float(base_texture.get_height())):
		return base_texture
	var atlas := AtlasTexture.new()
	atlas.atlas = base_texture
	atlas.region = region
	return atlas


func _compute_visible_region(resource_path: String, texture: Texture2D) -> Rect2:
	if _texture_region_cache.has(resource_path):
		var cached: Variant = _texture_region_cache[resource_path]
		if cached is Rect2:
			return cached as Rect2
	var precomputed_region: Rect2 = _get_precomputed_visible_region(resource_path, texture)
	if precomputed_region.size.x > 0.0 and precomputed_region.size.y > 0.0:
		_texture_region_cache[resource_path] = precomputed_region
		return precomputed_region
	var image: Image = texture.get_image()
	if image == null:
		return Rect2(Vector2.ZERO, Vector2(texture.get_width(), texture.get_height()))
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0:
		return Rect2(Vector2.ZERO, Vector2(texture.get_width(), texture.get_height()))
	var edge_samples: Array[Color] = []
	for x: int in width:
		edge_samples.append(image.get_pixel(x, 0))
		edge_samples.append(image.get_pixel(x, height - 1))
	for y: int in height:
		edge_samples.append(image.get_pixel(0, y))
		edge_samples.append(image.get_pixel(width - 1, y))
	var row_counts: Array[int] = []
	row_counts.resize(height)
	row_counts.fill(0)
	var col_counts: Array[int] = []
	col_counts.resize(width)
	col_counts.fill(0)
	var left := width
	var upper := height
	var right := -1
	var lower := -1
	for y: int in height:
		for x: int in width:
			var color := image.get_pixel(x, y)
			if color.a < 0.12:
				continue
			if _looks_like_generated_background(color, edge_samples):
				continue
			left = mini(left, x)
			upper = mini(upper, y)
			right = maxi(right, x)
			lower = maxi(lower, y)
			row_counts[y] += 1
			col_counts[x] += 1
	var region := Rect2(Vector2.ZERO, Vector2(texture.get_width(), texture.get_height()))
	if right >= left and lower >= upper:
		var row_threshold := maxi(4, int(round(float(width) * 0.015)))
		var col_threshold := maxi(4, int(round(float(height) * 0.02)))
		var dense_top := upper
		var dense_bottom := lower
		var dense_left := left
		var dense_right := right
		for y: int in height:
			if row_counts[y] >= row_threshold:
				dense_top = y
				break
		for y: int in range(height - 1, -1, -1):
			if row_counts[y] >= row_threshold:
				dense_bottom = y
				break
		for x: int in width:
			if col_counts[x] >= col_threshold:
				dense_left = x
				break
		for x: int in range(width - 1, -1, -1):
			if col_counts[x] >= col_threshold:
				dense_right = x
				break
		region = Rect2(
			Vector2(maxi(0, dense_left - 8), maxi(0, dense_top - 8)),
			Vector2(
				mini(width, dense_right + 9) - maxi(0, dense_left - 8),
				mini(height, dense_bottom + 9) - maxi(0, dense_top - 8)
			)
		)
	_texture_region_cache[resource_path] = region
	return region


func _get_precomputed_visible_region(resource_path: String, texture: Texture2D) -> Rect2:
	if not _precomputed_texture_region_cache_loaded:
		_load_precomputed_texture_region_cache()
	if not _precomputed_texture_region_cache.has(resource_path):
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var region_variant: Variant = _precomputed_texture_region_cache[resource_path]
	if region_variant is Rect2:
		return region_variant as Rect2
	if region_variant is Array:
		var rect := _rect2_from_array(region_variant as Array, texture)
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			_precomputed_texture_region_cache[resource_path] = rect
			return rect
	return Rect2(Vector2.ZERO, Vector2.ZERO)


func _load_precomputed_texture_region_cache() -> void:
	_precomputed_texture_region_cache_loaded = true
	_precomputed_texture_region_cache.clear()
	if not FileAccess.file_exists(PRECOMPUTED_REGION_CACHE_PATH):
		return
	var file := FileAccess.open(PRECOMPUTED_REGION_CACHE_PATH, FileAccess.READ)
	if file == null:
		return
	var raw_text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(raw_text)
	if not (parsed is Dictionary):
		return
	var root: Dictionary = parsed as Dictionary
	var regions_variant: Variant = root.get("regions", {})
	if not (regions_variant is Dictionary):
		return
	var regions: Dictionary = regions_variant as Dictionary
	for key_variant: Variant in regions.keys():
		var key := str(key_variant)
		var rect_variant: Variant = regions[key_variant]
		if rect_variant is Array:
			_precomputed_texture_region_cache[key] = rect_variant


func _rect2_from_array(values: Array, texture: Texture2D) -> Rect2:
	if values.size() < 4:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var x := maxf(0.0, float(values[0]))
	var y := maxf(0.0, float(values[1]))
	var w := maxf(0.0, float(values[2]))
	var h := maxf(0.0, float(values[3]))
	if texture != null:
		var max_w := maxf(0.0, float(texture.get_width()))
		var max_h := maxf(0.0, float(texture.get_height()))
		x = minf(x, max_w)
		y = minf(y, max_h)
		w = minf(w, maxf(0.0, max_w - x))
		h = minf(h, maxf(0.0, max_h - y))
	return Rect2(x, y, w, h)


func _looks_like_generated_background(color: Color, edge_samples: Array[Color]) -> bool:
	var delta := maxf(absf(color.r - color.g), maxf(absf(color.g - color.b), absf(color.r - color.b)))
	var luminance := (color.r + color.g + color.b) / 3.0
	if delta > 0.08:
		return false
	if luminance < 0.16 or luminance > 0.82:
		return false
	if delta <= 0.02 and luminance >= 0.22 and luminance <= 0.66:
		return true
	for sample_variant: Variant in edge_samples:
		if sample_variant is Color:
			var sample: Color = sample_variant
			var distance := absf(color.r - sample.r) + absf(color.g - sample.g) + absf(color.b - sample.b)
			if distance <= 0.16:
				return true
	return false


func _create_flash_node(profile: RefCounted) -> ColorRect:
	var flash := ColorRect.new()
	flash.name = FLASH_NAME
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var color: Color = profile.get("secondary_color") if profile != null else Color(1.0, 0.5, 0.2, 1.0)
	color.a = float(profile.get("target_flash_strength")) if profile != null else 0.28
	flash.color = color
	flash.visible = true
	flash.modulate.a = 0.0
	return flash


func _add_counter_transfer_accents(
	scene: Object,
	sequence: Control,
	overlay: Control,
	source_spec: Dictionary,
	target_spec: Dictionary,
	data: Dictionary
) -> void:
	var counter_count: int = int(data.get("counter_count", 0))
	if counter_count <= 0:
		counter_count = maxi(1, int(data.get("damage_amount", 10)) / 10)
	var damage_text := str(counter_count * 10)
	var source_local: Vector2 = _overlay_local_position(overlay, source_spec.get("position", Vector2.ZERO))
	var target_local: Vector2 = _overlay_local_position(overlay, target_spec.get("position", Vector2.ZERO))
	var source_label := _make_counter_transfer_label(COUNTER_SOURCE_LABEL_NAME, "-%s" % damage_text, Color(0.55, 0.98, 1.0, 1.0), source_local + Vector2(-54.0, -66.0))
	var target_label := _make_counter_transfer_label(COUNTER_TARGET_LABEL_NAME, "+%s" % damage_text, Color(1.0, 0.32, 0.78, 1.0), target_local + Vector2(22.0, -70.0))
	sequence.add_child(source_label)
	sequence.add_child(target_label)

	var caster_data: Variant = data.get("caster", {})
	if caster_data is Dictionary:
		var caster_spec: Dictionary = _target_spec_from_dict(scene, caster_data as Dictionary)
		if not caster_spec.is_empty():
			var caster_local: Vector2 = _overlay_local_position(overlay, caster_spec.get("position", Vector2.ZERO))
			var aura := _make_counter_transfer_aura(caster_local)
			sequence.add_child(aura)

	if scene is Node and (scene as Node).is_inside_tree():
		_play_counter_transfer_accent_animation(scene as Node, sequence)


func _make_counter_transfer_label(name: String, text: String, color: Color, position: Vector2) -> Label:
	var label := Label.new()
	label.name = name
	label.text = text
	label.position = position
	label.custom_minimum_size = Vector2(96.0, 34.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	label.add_theme_font_size_override("font_size", 25)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _make_counter_transfer_aura(position: Vector2) -> Control:
	var aura := Control.new()
	aura.name = COUNTER_CASTER_AURA_NAME
	aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aura.position = position
	aura.scale = Vector2(0.34, 0.34)
	aura.modulate.a = 0.0
	for index: int in 8:
		var ray := ColorRect.new()
		ray.name = "AuraRay%d" % index
		ray.color = Color(0.6, 0.18, 1.0, 0.72)
		ray.size = Vector2(104.0, 8.0)
		ray.pivot_offset = Vector2(0.0, 4.0)
		ray.position = Vector2.ZERO
		ray.rotation = TAU * float(index) / 8.0
		ray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		aura.add_child(ray)
	return aura


func _play_counter_transfer_accent_animation(scene: Node, sequence: Control) -> void:
	var source_label: Label = sequence.get_node_or_null(COUNTER_SOURCE_LABEL_NAME) as Label
	if source_label != null:
		var source_tween := scene.create_tween()
		source_tween.tween_interval(0.12)
		source_tween.tween_property(source_label, "modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		source_tween.parallel().tween_property(source_label, "position:y", source_label.position.y - 18.0, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		source_tween.tween_property(source_label, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var target_label: Label = sequence.get_node_or_null(COUNTER_TARGET_LABEL_NAME) as Label
	if target_label != null:
		var target_tween := scene.create_tween()
		target_tween.tween_interval(0.4)
		target_tween.tween_property(target_label, "modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		target_tween.parallel().tween_property(target_label, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		target_tween.parallel().tween_property(target_label, "position:y", target_label.position.y - 14.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		target_tween.tween_property(target_label, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var aura: Control = sequence.get_node_or_null(COUNTER_CASTER_AURA_NAME) as Control
	if aura != null:
		var aura_tween := scene.create_tween()
		aura_tween.tween_property(aura, "modulate:a", 0.85, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		aura_tween.parallel().tween_property(aura, "scale", Vector2(1.2, 1.2), 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		aura_tween.tween_property(aura, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _play_sequence_animation(
	scene: Node,
	sequence: Control,
	cast_node: Control,
	flash: ColorRect,
	profile: RefCounted,
	target_specs: Array
) -> void:
	var cast_duration: float = float(profile.get("cast_duration")) if profile != null else 0.15
	var travel_duration: float = float(profile.get("travel_duration")) if profile != null else 0.2
	var impact_duration: float = float(profile.get("impact_duration")) if profile != null else 0.42
	var residue_duration: float = float(profile.get("residue_duration")) if profile != null else 0.22
	var cast_tween := scene.create_tween()
	cast_tween.tween_property(cast_node, "modulate:a", 1.0, cast_duration * 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	cast_tween.parallel().tween_property(cast_node, "scale", Vector2(1.65, 1.65), cast_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	cast_tween.tween_property(cast_node, "modulate:a", 0.0, cast_duration * 0.58).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	for index: int in target_specs.size():
		var travel: Control = sequence.get_node_or_null("%s%d" % [TRAVEL_PREFIX, index]) as Control
		var impact: Control = sequence.get_node_or_null("%s%d" % [IMPACT_PREFIX, index]) as Control
		var shockwave: Control = sequence.get_node_or_null("%s%d" % [SHOCKWAVE_PREFIX, index]) as Control
		var residue: Control = sequence.get_node_or_null("%s%d" % [RESIDUE_PREFIX, index]) as Control
		if travel != null:
			var travel_tween := scene.create_tween()
			travel_tween.tween_interval(cast_duration * 0.28 + index * 0.04)
			travel_tween.tween_property(travel, "modulate:a", 1.0, travel_duration * 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			var head: ColorRect = travel.get_node_or_null("Head") as ColorRect
			if head != null:
				var overlay: Control = sequence.get_parent() as Control
				var target_pos: Vector2 = _overlay_local_position(overlay, travel.get_meta("target_position", Vector2.ZERO))
				var travel_vector: Vector2 = target_pos - travel.position
				travel_tween.parallel().tween_property(head, "position", travel_vector - head.size * 0.5, travel_duration * 0.86).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			travel_tween.parallel().tween_property(travel, "scale", Vector2(1.18, 1.18), travel_duration * 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			travel_tween.tween_property(travel, "modulate:a", 0.0, travel_duration * 0.56).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		if impact != null:
			var impact_tween := scene.create_tween()
			impact_tween.tween_interval(cast_duration + travel_duration * 0.62 + index * 0.04)
			var impact_flipbook: TextureRect = impact.get_node_or_null("ImpactBloomTexture") as TextureRect
			if impact_flipbook != null:
				_animate_flipbook(scene, impact_flipbook, max(1, int(impact_flipbook.get_meta("flipbook_frame_count", 1))), impact_duration * 0.52)
			impact_tween.tween_property(impact, "modulate:a", 1.0, impact_duration * 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			impact_tween.parallel().tween_property(impact, "scale", Vector2(1.6, 1.6), impact_duration * 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			impact_tween.parallel().tween_property(flash, "modulate:a", float(profile.get("target_flash_strength")) if profile != null else 0.28, impact_duration * 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			impact_tween.tween_property(flash, "modulate:a", 0.0, impact_duration * 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			impact_tween.tween_property(impact, "modulate:a", 0.0, impact_duration * 0.44).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			impact_tween.parallel().tween_property(impact, "scale", Vector2(2.35, 2.35), impact_duration * 0.44).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if shockwave != null:
			var shockwave_tween := scene.create_tween()
			shockwave_tween.tween_interval(cast_duration + travel_duration * 0.62 + index * 0.04)
			shockwave_tween.tween_property(shockwave, "modulate:a", 0.95, impact_duration * 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			shockwave_tween.parallel().tween_property(shockwave, "scale", Vector2(1.9, 1.9), impact_duration * 0.34).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			shockwave_tween.tween_property(shockwave, "modulate:a", 0.0, impact_duration * 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		if residue != null:
			var residue_tween := scene.create_tween()
			residue_tween.tween_interval(cast_duration + travel_duration * 0.8 + index * 0.04)
			var residue_flipbook: TextureRect = residue.get_node_or_null("EmbersSmokeTexture") as TextureRect
			if residue_flipbook != null:
				_animate_flipbook(scene, residue_flipbook, max(1, int(residue_flipbook.get_meta("flipbook_frame_count", 1))), residue_duration * 0.9)
			residue_tween.tween_property(residue, "modulate:a", 0.72, residue_duration * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			residue_tween.parallel().tween_property(residue, "scale", Vector2(1.22, 1.22), residue_duration * 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			residue_tween.tween_property(residue, "modulate:a", 0.0, residue_duration * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

		var anchor: Control = (target_specs[index] as Dictionary).get("anchor", null) as Control
		if anchor != null:
			var anchor_origin := anchor.position
			var shake_strength: float = float(profile.get("screen_shake_strength")) if profile != null else 12.0
			var shake_tween := scene.create_tween()
			shake_tween.tween_interval(cast_duration + travel_duration * 0.66 + index * 0.04)
			shake_tween.tween_property(anchor, "position", anchor_origin + Vector2(shake_strength * 0.7, -shake_strength * 0.45), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			shake_tween.tween_property(anchor, "position", anchor_origin + Vector2(-shake_strength * 0.55, shake_strength * 0.38), 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			shake_tween.tween_property(anchor, "position", anchor_origin + Vector2(shake_strength * 0.32, -shake_strength * 0.12), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			shake_tween.tween_property(anchor, "position", anchor_origin, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	var cleanup_delay: float = cast_duration + travel_duration + impact_duration + residue_duration + target_specs.size() * 0.05 + 0.12
	var cleanup_tween := scene.create_tween()
	cleanup_tween.tween_interval(cleanup_delay)
	cleanup_tween.finished.connect(func() -> void:
		if is_instance_valid(sequence):
			sequence.queue_free()
	)


func _animate_flipbook(scene: Node, texture_rect: TextureRect, frame_count: int, duration: float) -> void:
	if texture_rect == null or frame_count <= 1:
		return
	var atlas: AtlasTexture = texture_rect.texture as AtlasTexture
	if atlas == null or atlas.atlas == null:
		return
	var frame_width := float(atlas.atlas.get_width()) / float(frame_count)
	var tween := scene.create_tween()
	for frame_index: int in frame_count:
		tween.tween_callback(func() -> void:
			if is_instance_valid(texture_rect):
				var current: AtlasTexture = texture_rect.texture as AtlasTexture
				if current != null:
					current.region = Rect2(frame_width * frame_index, 0.0, frame_width, float(current.atlas.get_height()))
		)
		if frame_index < frame_count - 1:
			tween.tween_interval(duration / float(frame_count))
