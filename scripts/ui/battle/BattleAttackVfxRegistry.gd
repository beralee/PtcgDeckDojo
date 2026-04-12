class_name BattleAttackVfxRegistry
extends RefCounted

const BattleAttackVfxProfileScript := preload("res://scripts/ui/battle/BattleAttackVfxProfile.gd")

const CHARIZARD_MID_STREAM_ASSETS := {
	"flame_stream_core": "res://assets/textures/vfx/charizard_ex/mid_stream/flame_stream_core.png",
	"impact_bloom_flipbook": "res://assets/textures/vfx/charizard_ex/mid_stream/impact_bloom_flipbook.png",
	"embers_smoke_flipbook": "res://assets/textures/vfx/charizard_ex/mid_stream/embers_smoke_flipbook.png",
}
const DRAGAPULT_EX_ASSET_SPECS := {
	"cast": {"path": "res://assets/textures/vfx/attribute_psychic/source/psychic_charge_orb.png", "frames": 1},
	"travel_core": {"path": "res://assets/textures/vfx/attribute_psychic/source/psychic_travel_core.png", "frames": 1},
	"travel_outer": {"path": "res://assets/textures/vfx/attribute_psychic/source/psychic_travel_outer.png", "frames": 1},
	"impact": {"path": "res://assets/textures/vfx/attribute_psychic/source/psychic_impact_bloom.png", "frames": 1},
	"impact_support": {"path": "res://assets/textures/vfx/attribute_dragon/source/scale_slash.png", "frames": 1},
	"residue": {"path": "res://assets/textures/vfx/attribute_psychic/source/psychic_residue_motes.png", "frames": 1},
}

const PALKIA_VSTAR_ASSET_SPECS := {
	"cast": {"path": "res://assets/textures/vfx/attribute_colorless/source/charge_glint.png", "frames": 1},
	"impact": {"path": "res://assets/textures/vfx/attribute_water/impact_only/water_impact_flipbook.png", "frames": 4},
	"impact_support": {"path": "res://assets/textures/vfx/attribute_water/impact_only/water_spray_droplets.png", "frames": 1},
	"shockwave": {"path": "res://assets/textures/vfx/attribute_water/impact_only/water_ripple_ring.png", "frames": 1},
	"residue": {"path": "res://assets/textures/vfx/attribute_water/impact_only/water_residue_mist.png", "frames": 1},
}

const GHOLDENGO_EX_ASSET_SPECS := {
	"cast": {"path": "res://assets/textures/vfx/attribute_colorless/source/charge_glint.png", "frames": 1},
	"impact": {"path": "res://assets/textures/vfx/attribute_metal/impact_only/impact_bloom_flipbook.png", "frames": 4},
	"impact_support": {"path": "res://assets/textures/vfx/attribute_metal/impact_only/plate_shard_cluster.png", "frames": 1},
	"shockwave": {"path": "res://assets/textures/vfx/attribute_metal/impact_only/steel_dust_mist.png", "frames": 1},
	"residue": {"path": "res://assets/textures/vfx/attribute_metal/impact_only/spark_residue.png", "frames": 1},
}

const DIALGA_VSTAR_ASSET_SPECS := {
	"cast": {"path": "res://assets/textures/vfx/attribute_colorless/source/charge_glint.png", "frames": 1},
	"impact": {"path": "res://assets/textures/vfx/attribute_metal/impact_only/impact_bloom_flipbook.png", "frames": 4},
	"impact_support": {"path": "res://assets/textures/vfx/attribute_metal/impact_only/plate_shard_cluster.png", "frames": 1},
	"shockwave": {"path": "res://assets/textures/vfx/attribute_metal/impact_only/steel_dust_mist.png", "frames": 1},
	"residue": {"path": "res://assets/textures/vfx/attribute_metal/impact_only/spark_residue.png", "frames": 1},
}

const FIRE_ASSET_SPECS := {
	"impact": {"path": "res://assets/textures/vfx/attribute_fire/source/impact_bloom.png", "frames": 1},
	"residue": {"path": "res://assets/textures/vfx/attribute_fire/source/residue_embers.png", "frames": 1},
}

const WATER_ASSET_SPECS := {
	"impact": {"path": "res://assets/textures/vfx/attribute_water/impact_only/water_impact_flipbook.png", "frames": 4},
	"impact_support": {"path": "res://assets/textures/vfx/attribute_water/impact_only/water_spray_droplets.png", "frames": 1},
	"shockwave": {"path": "res://assets/textures/vfx/attribute_water/impact_only/water_ripple_ring.png", "frames": 1},
	"residue": {"path": "res://assets/textures/vfx/attribute_water/impact_only/water_residue_mist.png", "frames": 1},
}

const LIGHTNING_ASSET_SPECS := {
	"cast": {"path": "res://assets/textures/vfx/attribute_lightning/charge/charge_orb.png", "frames": 1},
	"travel_core": {"path": "res://assets/textures/vfx/attribute_lightning/travel/travel_core.png", "frames": 1},
	"impact": {"path": "res://assets/textures/vfx/attribute_lightning/impact/impact_bloom.png", "frames": 1},
	"residue": {"path": "res://assets/textures/vfx/attribute_lightning/residue/residue_sparks.png", "frames": 1},
}

const PSYCHIC_ASSET_SPECS := {
	"cast": {"path": "res://assets/textures/vfx/attribute_psychic/source/psychic_charge_orb.png", "frames": 1},
	"travel_core": {"path": "res://assets/textures/vfx/attribute_psychic/source/psychic_travel_core.png", "frames": 1},
	"travel_outer": {"path": "res://assets/textures/vfx/attribute_psychic/source/psychic_travel_outer.png", "frames": 1},
	"impact": {"path": "res://assets/textures/vfx/attribute_psychic/source/psychic_impact_bloom.png", "frames": 1},
	"residue": {"path": "res://assets/textures/vfx/attribute_psychic/source/psychic_residue_motes.png", "frames": 1},
}

const DARKNESS_ASSET_SPECS := {
	"cast": {"path": "res://assets/textures/vfx/attribute_darkness/source/charge_core.png", "frames": 1},
	"impact": {"path": "res://assets/textures/vfx/attribute_darkness/source/impact_bloom.png", "frames": 1},
	"residue": {"path": "res://assets/textures/vfx/attribute_darkness/source/residue_smoke.png", "frames": 1},
}

const GRASS_ASSET_SPECS := {
	"impact": {"path": "res://assets/textures/vfx/attribute_grass/verdant_burst/impact_bloom_flipbook.png", "frames": 4},
	"impact_support": {"path": "res://assets/textures/vfx/attribute_grass/verdant_burst/leaf_shard_cluster.png", "frames": 1},
	"shockwave": {"path": "res://assets/textures/vfx/attribute_grass/verdant_burst/vine_fracture_accents.png", "frames": 1},
	"residue": {"path": "res://assets/textures/vfx/attribute_grass/verdant_burst/pollen_haze.png", "frames": 1},
}

const FIGHTING_ASSET_SPECS := {
	"impact": {"path": "res://assets/textures/vfx/attribute_fighting/impact_only/impact_bloom_flipbook.png", "frames": 4},
	"cast": {"path": "res://assets/textures/vfx/attribute_fighting/impact_only/knuckle_flash.png", "frames": 1},
	"impact_support": {"path": "res://assets/textures/vfx/attribute_fighting/impact_only/dust_shatter.png", "frames": 1},
	"residue": {"path": "res://assets/textures/vfx/attribute_fighting/impact_only/residue_grit.png", "frames": 1},
}

const METAL_ASSET_SPECS := {
	"impact": {"path": "res://assets/textures/vfx/attribute_metal/impact_only/impact_bloom_flipbook.png", "frames": 4},
	"impact_support": {"path": "res://assets/textures/vfx/attribute_metal/impact_only/plate_shard_cluster.png", "frames": 1},
	"residue": {"path": "res://assets/textures/vfx/attribute_metal/impact_only/spark_residue.png", "frames": 1},
	"shockwave": {"path": "res://assets/textures/vfx/attribute_metal/impact_only/steel_dust_mist.png", "frames": 1},
}

const DRAGON_ASSET_SPECS := {
	"cast": {"path": "res://assets/textures/vfx/attribute_dragon/source/charge_core.png", "frames": 1},
	"impact": {"path": "res://assets/textures/vfx/attribute_dragon/source/impact_bloom.png", "frames": 1},
	"impact_support": {"path": "res://assets/textures/vfx/attribute_dragon/source/scale_slash.png", "frames": 1},
	"residue": {"path": "res://assets/textures/vfx/attribute_dragon/source/residue_embers.png", "frames": 1},
}

const COLORLESS_ASSET_SPECS := {
	"cast": {"path": "res://assets/textures/vfx/attribute_colorless/source/charge_glint.png", "frames": 1},
	"travel_core": {"path": "res://assets/textures/vfx/attribute_colorless/source/travel_sheen.png", "frames": 1},
	"impact": {"path": "res://assets/textures/vfx/attribute_colorless/source/impact_bloom.png", "frames": 1},
	"residue": {"path": "res://assets/textures/vfx/attribute_colorless/source/residue_motes.png", "frames": 1},
}

var _hero_profiles: Dictionary = {
	"dragapult ex": _make_profile(
		"hero_dragapult_ex",
		"phantom_burst",
		Color(0.55, 0.84, 1.0, 1.0),
		Color(0.74, 0.43, 1.0, 1.0),
		14,
		3,
		1.18,
		{
			"asset_specs": DRAGAPULT_EX_ASSET_SPECS,
			"disable_generic_shockwave": true,
		}
	),
	"charizard ex": _make_profile(
		"hero_charizard_ex",
		"flame_burst",
		Color(1.0, 0.48, 0.12, 1.0),
		Color(1.0, 0.86, 0.24, 1.0),
		16,
		5,
		1.3,
		{
			"asset_paths": CHARIZARD_MID_STREAM_ASSETS,
			"impact_only": true,
		}
	),
	"origin forme palkia vstar": _make_profile(
		"hero_palkia_vstar",
		"spatial_tide",
		Color(0.42, 0.82, 1.0, 1.0),
		Color(0.86, 0.91, 1.0, 1.0),
		14,
		3,
		1.2,
		{
			"asset_specs": PALKIA_VSTAR_ASSET_SPECS,
			"disable_travel": true,
			"disable_generic_shockwave": true,
		}
	),
	"起源帕路奇亚vstar": _make_profile(
		"hero_palkia_vstar",
		"spatial_tide",
		Color(0.42, 0.82, 1.0, 1.0),
		Color(0.86, 0.91, 1.0, 1.0),
		14,
		3,
		1.2,
		{
			"asset_specs": PALKIA_VSTAR_ASSET_SPECS,
			"disable_travel": true,
			"disable_generic_shockwave": true,
		}
	),
	"gholdengo ex": _make_profile(
		"hero_gholdengo_ex",
		"golden_burst",
		Color(1.0, 0.84, 0.18, 1.0),
		Color(1.0, 0.97, 0.78, 1.0),
		16,
		2,
		1.26,
		{
			"asset_specs": GHOLDENGO_EX_ASSET_SPECS,
			"disable_travel": true,
			"disable_generic_shockwave": true,
		}
	),
	"赛富豪ex": _make_profile(
		"hero_gholdengo_ex",
		"golden_burst",
		Color(1.0, 0.84, 0.18, 1.0),
		Color(1.0, 0.97, 0.78, 1.0),
		16,
		2,
		1.26,
		{
			"asset_specs": GHOLDENGO_EX_ASSET_SPECS,
			"disable_travel": true,
			"disable_generic_shockwave": true,
		}
	),
	"miraidon ex": _make_profile(
		"hero_miraidon_ex",
		"thunder_rail",
		Color(0.86, 0.36, 1.0, 1.0),
		Color(0.98, 0.98, 0.74, 1.0),
		16,
		2,
		1.22,
		{
			"asset_specs": LIGHTNING_ASSET_SPECS,
			"disable_generic_shockwave": true,
		}
	),
	"iron hands ex": _make_profile(
		"hero_iron_hands_ex",
		"heavy_voltage",
		Color(1.0, 0.88, 0.24, 1.0),
		Color(0.62, 0.92, 1.0, 1.0),
		15,
		2,
		1.18,
		{
			"asset_specs": LIGHTNING_ASSET_SPECS,
			"disable_generic_shockwave": true,
		}
	),
	"regidrago vstar": _make_profile(
		"hero_regidrago_vstar",
		"dragon_crest",
		Color(0.4, 0.48, 1.0, 1.0),
		Color(1.0, 0.66, 0.24, 1.0),
		15,
		3,
		1.22,
		{
			"asset_specs": DRAGON_ASSET_SPECS,
			"disable_travel": true,
			"disable_generic_shockwave": true,
		}
	),
	"raging bolt ex": _make_profile(
		"hero_raging_bolt_ex",
		"storm_fang",
		Color(1.0, 0.52, 0.18, 1.0),
		Color(1.0, 0.88, 0.22, 1.0),
		16,
		3,
		1.24,
		{
			"asset_specs": DRAGON_ASSET_SPECS,
			"disable_travel": true,
			"disable_generic_shockwave": true,
		}
	),
	"lugia vstar": _make_profile(
		"hero_lugia_vstar",
		"tempest_arc",
		Color(0.92, 0.94, 1.0, 1.0),
		Color(0.7, 0.82, 1.0, 1.0),
		13,
		2,
		1.2,
		{
			"asset_specs": COLORLESS_ASSET_SPECS,
			"disable_generic_shockwave": true,
		}
	),
	"arceus vstar": _make_profile(
		"hero_arceus_vstar",
		"celestial_lance",
		Color(1.0, 0.95, 0.74, 1.0),
		Color(0.98, 0.84, 0.36, 1.0),
		14,
		2,
		1.22,
		{
			"asset_specs": COLORLESS_ASSET_SPECS,
			"disable_generic_shockwave": true,
		}
	),
	"giratina vstar": _make_profile(
		"hero_giratina_vstar",
		"rift_howl",
		Color(0.34, 0.22, 0.54, 1.0),
		Color(1.0, 0.78, 0.24, 1.0),
		15,
		4,
		1.24,
		{
			"asset_specs": DRAGON_ASSET_SPECS,
			"disable_travel": true,
			"disable_generic_shockwave": true,
		}
	),
	"origin forme dialga vstar": _make_profile(
		"hero_dialga_vstar",
		"chrono_forge",
		Color(0.82, 0.93, 1.0, 1.0),
		Color(0.52, 0.68, 0.92, 1.0),
		14,
		2,
		1.22,
		{
			"asset_specs": DIALGA_VSTAR_ASSET_SPECS,
			"disable_travel": true,
			"disable_generic_shockwave": true,
		}
	),
}

var _energy_fallback_profiles: Dictionary = {
	"W": _make_profile("fallback_water", "water_arc", Color(0.35, 0.79, 1.0, 1.0), Color(0.82, 0.95, 1.0, 1.0), 10, 2, 1.02, {
		"asset_specs": WATER_ASSET_SPECS,
		"impact_only": true,
	}),
	"R": _make_profile("fallback_fire", "flame_burst", Color(1.0, 0.46, 0.08, 1.0), Color(1.0, 0.86, 0.2, 1.0), 11, 3, 1.08, {
		"asset_specs": FIRE_ASSET_SPECS,
		"impact_only": true,
	}),
	"L": _make_profile("fallback_lightning", "thunder_crack", Color(1.0, 0.92, 0.2, 1.0), Color(0.98, 0.98, 0.8, 1.0), 13, 2, 1.12, {
		"asset_specs": LIGHTNING_ASSET_SPECS,
		"disable_generic_shockwave": true,
	}),
	"P": _make_profile("fallback_psychic", "psychic_wave", Color(0.94, 0.46, 1.0, 1.0), Color(0.56, 0.74, 1.0, 1.0), 10, 2, 1.04, {
		"asset_specs": PSYCHIC_ASSET_SPECS,
	}),
	"D": _make_profile("fallback_darkness", "shadow_burst", Color(0.47, 0.35, 0.68, 1.0), Color(0.18, 0.18, 0.27, 1.0), 10, 4, 1.05, {
		"asset_specs": DARKNESS_ASSET_SPECS,
		"impact_only": true,
	}),
	"G": _make_profile("fallback_grass", "verdant_burst", Color(0.36, 0.87, 0.38, 1.0), Color(0.85, 1.0, 0.58, 1.0), 9, 3, 1.03, {
		"asset_specs": GRASS_ASSET_SPECS,
		"impact_only": true,
	}),
	"F": _make_profile("fallback_fighting", "body_blow", Color(0.95, 0.9, 0.82, 1.0), Color(0.74, 0.34, 0.24, 1.0), 9, 3, 1.05, {
		"asset_specs": FIGHTING_ASSET_SPECS,
		"impact_only": true,
	}),
	"M": _make_profile("fallback_metal", "forged_impact", Color(0.96, 0.98, 1.0, 1.0), Color(0.52, 0.58, 0.64, 1.0), 10, 2, 1.12, {
		"asset_specs": METAL_ASSET_SPECS,
		"impact_only": true,
	}),
	"N": _make_profile("fallback_dragon", "draconic_surge", Color(0.37, 0.42, 1.0, 1.0), Color(1.0, 0.74, 0.33, 1.0), 12, 3, 1.16, {
		"asset_specs": DRAGON_ASSET_SPECS,
		"disable_travel": true,
		"disable_generic_shockwave": true,
	}),
	"C": _make_profile("fallback_colorless", "pearlescent_burst", Color(0.97, 0.95, 0.9, 1.0), Color(0.84, 0.74, 0.54, 1.0), 9, 2, 1.08, {
		"asset_specs": COLORLESS_ASSET_SPECS,
		"disable_generic_shockwave": true,
	}),
}

var _generic_profile := _make_profile(
	"fallback_generic",
	"generic_burst",
	Color(1.0, 0.92, 0.4, 1.0),
	Color(1.0, 0.58, 0.24, 1.0),
	8,
	3,
	1.0
)


static func _make_profile(
	id: String,
	template: String,
	primary: Color,
	secondary: Color,
	sparks: int,
	smoke: int,
	scale: float,
	options: Dictionary = {}
) -> RefCounted:
	var profile = BattleAttackVfxProfileScript.new()
	profile.profile_id = id
	profile.template_id = template
	profile.primary_color = primary
	profile.secondary_color = secondary
	profile.spark_count = sparks
	profile.smoke_count = smoke
	profile.burst_scale = scale
	profile.asset_paths = (options.get("asset_paths", {}) as Dictionary).duplicate(true)
	profile.asset_specs = (options.get("asset_specs", {}) as Dictionary).duplicate(true)
	profile.cast_template = "%s_cast" % template
	profile.travel_template = "%s_travel" % template
	profile.impact_template = "%s_impact" % template
	profile.cast_duration = 0.17
	profile.travel_duration = 0.18
	profile.impact_duration = 0.48
	profile.residue_duration = 0.24
	profile.travel_width = 22.0 * scale
	profile.impact_radius = 112.0 * scale
	profile.shockwave_radius = 168.0 * scale
	profile.screen_shake_strength = 18.0 * scale
	profile.target_flash_strength = 0.34
	profile.cast_ray_count = 8
	profile.trail_segment_count = 4
	profile.residue_count = 6
	if id.begins_with("hero_"):
		profile.cast_duration = 0.2
		profile.travel_duration = 0.2
		profile.impact_duration = 0.56
		profile.residue_duration = 0.3
		profile.travel_width = 28.0 * scale
		profile.impact_radius = 144.0 * scale
		profile.shockwave_radius = 220.0 * scale
		profile.screen_shake_strength = 26.0 * scale
		profile.target_flash_strength = 0.48
		profile.cast_ray_count = 10
		profile.trail_segment_count = 6
		profile.residue_count = 9
	profile.asset_driven_cast = profile.asset_specs.has("cast") or profile.asset_paths.has("mouth_charge")
	profile.asset_driven_travel = profile.asset_specs.has("travel_core") or profile.asset_specs.has("travel_outer") or profile.asset_paths.has("flame_stream_core") or profile.asset_paths.has("flame_stream_outer")
	profile.asset_driven_impact = profile.asset_specs.has("impact") or profile.asset_paths.has("impact_bloom_flipbook")
	profile.asset_driven_residue = profile.asset_specs.has("residue") or profile.asset_paths.has("embers_smoke_flipbook")
	profile.enable_generic_cast = not profile.asset_driven_cast
	if profile.asset_driven_impact:
		profile.enable_generic_shockwave = false
	if bool(options.get("impact_only", false)):
		profile.enable_travel = false
		profile.enable_generic_cast = false
	if bool(options.get("disable_generic_cast", false)):
		profile.enable_generic_cast = false
	if bool(options.get("disable_travel", false)):
		profile.enable_travel = false
	if bool(options.get("disable_generic_shockwave", false)):
		profile.enable_generic_shockwave = false
	return profile


func resolve_profile(attacker_card_data: CardData, _attack_name: String = "") -> RefCounted:
	if attacker_card_data != null:
		for candidate: String in _hero_profile_candidates(attacker_card_data):
			if _hero_profiles.has(candidate):
				return _hero_profiles[candidate] as RefCounted
		var energy_type: String = String(attacker_card_data.energy_type).strip_edges().to_upper()
		if _energy_fallback_profiles.has(energy_type):
			return _energy_fallback_profiles[energy_type] as RefCounted
	return _generic_profile


func _hero_profile_candidates(card_data: CardData) -> Array[String]:
	var candidates: Array[String] = []
	var localized_name: String = String(card_data.name).strip_edges().to_lower()
	var english_name: String = String(card_data.name_en).strip_edges().to_lower()
	if english_name != "":
		candidates.append(english_name)
	if localized_name != "" and localized_name != english_name:
		candidates.append(localized_name)
	return candidates


func get_preview_entries() -> Array[Dictionary]:
	return [
		{"label": "Dragapult ex | Phantom Burst", "profile": _hero_profiles.get("dragapult ex")},
		{"label": "Charizard ex | Flame Burst", "profile": _hero_profiles.get("charizard ex")},
		{"label": "Palkia VSTAR | Spatial Tide", "profile": _hero_profiles.get("origin forme palkia vstar")},
		{"label": "Gholdengo ex | Golden Burst", "profile": _hero_profiles.get("gholdengo ex")},
		{"label": "Miraidon ex | Thunder Rail", "profile": _hero_profiles.get("miraidon ex")},
		{"label": "Iron Hands ex | Heavy Voltage", "profile": _hero_profiles.get("iron hands ex")},
		{"label": "Regidrago VSTAR | Dragon Crest", "profile": _hero_profiles.get("regidrago vstar")},
		{"label": "Raging Bolt ex | Storm Fang", "profile": _hero_profiles.get("raging bolt ex")},
		{"label": "Lugia VSTAR | Tempest Arc", "profile": _hero_profiles.get("lugia vstar")},
		{"label": "Arceus VSTAR | Celestial Lance", "profile": _hero_profiles.get("arceus vstar")},
		{"label": "Giratina VSTAR | Rift Howl", "profile": _hero_profiles.get("giratina vstar")},
		{"label": "Dialga VSTAR | Chrono Forge", "profile": _hero_profiles.get("origin forme dialga vstar")},
		{"label": "Fallback Fire | Flame Burst", "profile": _energy_fallback_profiles.get("R")},
		{"label": "Fallback Water | Water Arc", "profile": _energy_fallback_profiles.get("W")},
		{"label": "Fallback Lightning | Thunder Crack", "profile": _energy_fallback_profiles.get("L")},
		{"label": "Fallback Psychic | Psychic Wave", "profile": _energy_fallback_profiles.get("P")},
		{"label": "Fallback Darkness | Shadow Burst", "profile": _energy_fallback_profiles.get("D")},
		{"label": "Fallback Grass | Verdant Burst", "profile": _energy_fallback_profiles.get("G")},
		{"label": "Fallback Fighting | Body Blow", "profile": _energy_fallback_profiles.get("F")},
		{"label": "Fallback Metal | Forged Impact", "profile": _energy_fallback_profiles.get("M")},
		{"label": "Fallback Dragon | Draconic Surge", "profile": _energy_fallback_profiles.get("N")},
		{"label": "Fallback Colorless | Pearlescent Burst", "profile": _energy_fallback_profiles.get("C")},
		{"label": "Fallback Generic | Generic Burst", "profile": _generic_profile},
	]
	return [
		{"label": "多龙巴鲁托ex | 幻影爆裂", "profile": _hero_profiles.get("dragapult ex")},
		{"label": "喷火龙ex | 烈焰爆裂", "profile": _hero_profiles.get("charizard ex")},
		{"label": "通用火系 | 烈焰爆裂", "profile": _energy_fallback_profiles.get("R")},
		{"label": "通用水系 | 浪花冲击", "profile": _energy_fallback_profiles.get("W")},
		{"label": "通用雷系 | 雷霆炸裂", "profile": _energy_fallback_profiles.get("L")},
		{"label": "通用超能 | 念压脉冲", "profile": _energy_fallback_profiles.get("P")},
		{"label": "通用恶系 | 暗蚀冲击", "profile": _energy_fallback_profiles.get("D")},
		{"label": "通用草系 | 翠叶爆绽", "profile": _energy_fallback_profiles.get("G")},
		{"label": "通用斗系 | 重拳冲击", "profile": _energy_fallback_profiles.get("F")},
		{"label": "通用钢系 | 锻钢碰撞", "profile": _energy_fallback_profiles.get("M")},
		{"label": "通用龙系 | 龙威冲击", "profile": _energy_fallback_profiles.get("N")},
		{"label": "通用无色 | 珠辉命中", "profile": _energy_fallback_profiles.get("C")},
		{"label": "通用兜底 | 基础爆裂", "profile": _generic_profile},
	]
