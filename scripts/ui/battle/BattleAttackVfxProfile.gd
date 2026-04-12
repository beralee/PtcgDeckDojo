class_name BattleAttackVfxProfile
extends RefCounted

var profile_id: String = "fallback_generic"
var template_id: String = "generic_burst"
var cast_template: String = "generic_cast"
var travel_template: String = "generic_travel"
var impact_template: String = "generic_impact"
var primary_color: Color = Color(1.0, 0.9, 0.4, 1.0)
var secondary_color: Color = Color(1.0, 0.5, 0.2, 1.0)
var spark_count: int = 8
var smoke_count: int = 3
var burst_scale: float = 1.0
var cast_duration: float = 0.17
var travel_duration: float = 0.18
var impact_duration: float = 0.48
var residue_duration: float = 0.24
var travel_width: float = 22.0
var impact_radius: float = 112.0
var shockwave_radius: float = 168.0
var screen_shake_strength: float = 18.0
var target_flash_strength: float = 0.34
var cast_ray_count: int = 8
var trail_segment_count: int = 4
var residue_count: int = 6
var asset_paths: Dictionary = {}
var asset_specs: Dictionary = {}
var asset_driven_cast: bool = false
var asset_driven_travel: bool = false
var asset_driven_impact: bool = false
var asset_driven_residue: bool = false
var enable_generic_cast: bool = true
var enable_travel: bool = true
var enable_generic_shockwave: bool = true
