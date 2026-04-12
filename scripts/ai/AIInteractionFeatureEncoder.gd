class_name AIInteractionFeatureEncoder
extends RefCounted

const FEATURE_SCHEMA: Array[String] = [
	"step_search_item",
	"step_search_tool",
	"step_search_pokemon",
	"step_search_cards",
	"step_discard_cards",
	"step_discard_energy",
	"step_embrace_target",
	"step_assignment_target",
	"step_field_slot",
	"step_counter_distribution",
	"item_is_card",
	"item_is_slot",
	"card_is_pokemon",
	"card_is_item",
	"card_is_tool",
	"card_is_supporter",
	"card_is_stadium",
	"card_is_energy",
	"pokemon_basic",
	"pokemon_stage1",
	"pokemon_stage2",
	"slot_is_active",
	"slot_is_bench",
	"remaining_hp",
	"damage_counters",
	"attached_energy_count",
	"search_priority_hint",
	"discard_priority_hint",
	"strategy_score_hint",
]


func get_schema() -> Array[String]:
	return FEATURE_SCHEMA.duplicate()


func build_features(item: Variant, step: Dictionary, context: Dictionary = {}) -> Dictionary:
	var features := {
		"step_search_item": false,
		"step_search_tool": false,
		"step_search_pokemon": false,
		"step_search_cards": false,
		"step_discard_cards": false,
		"step_discard_energy": false,
		"step_embrace_target": false,
		"step_assignment_target": false,
		"step_field_slot": false,
		"step_counter_distribution": false,
		"item_is_card": false,
		"item_is_slot": false,
		"card_is_pokemon": false,
		"card_is_item": false,
		"card_is_tool": false,
		"card_is_supporter": false,
		"card_is_stadium": false,
		"card_is_energy": false,
		"pokemon_basic": false,
		"pokemon_stage1": false,
		"pokemon_stage2": false,
		"slot_is_active": false,
		"slot_is_bench": false,
		"remaining_hp": 0.0,
		"damage_counters": 0.0,
		"attached_energy_count": 0.0,
		"search_priority_hint": 0.0,
		"discard_priority_hint": 0.0,
		"strategy_score_hint": float(context.get("strategy_score", 0.0)),
	}

	var step_id: String = str(step.get("id", "")).strip_edges()
	match step_id:
		"search_item":
			features["step_search_item"] = true
		"search_tool":
			features["step_search_tool"] = true
		"search_pokemon", "basic_pokemon", "buddy_poffin_pokemon", "bench_pokemon":
			features["step_search_pokemon"] = true
		"search_cards":
			features["step_search_cards"] = true
		"discard_cards", "discard_card":
			features["step_discard_cards"] = true
		"discard_energy":
			features["step_discard_energy"] = true
		"embrace_target":
			features["step_embrace_target"] = true
		"assignment_target":
			features["step_assignment_target"] = true

	if bool(step.get("use_slot_selection_ui", false)):
		features["step_field_slot"] = true
	if bool(step.get("use_counter_distribution_ui", false)):
		features["step_counter_distribution"] = true

	if item is CardInstance:
		var card: CardInstance = item
		features["item_is_card"] = true
		if card.card_data != null:
			var card_type: String = str(card.card_data.card_type)
			features["card_is_pokemon"] = card_type == "Pokemon"
			features["card_is_item"] = card_type == "Item"
			features["card_is_tool"] = card_type == "Tool"
			features["card_is_supporter"] = card_type == "Supporter"
			features["card_is_stadium"] = card_type == "Stadium"
			features["card_is_energy"] = card.card_data.is_energy()
			var stage: String = str(card.card_data.stage)
			features["pokemon_basic"] = stage == "Basic"
			features["pokemon_stage1"] = stage == "Stage 1"
			features["pokemon_stage2"] = stage == "Stage 2"
			features["search_priority_hint"] = _normalize_score(float(context.get("search_priority_hint", 0.0)), 400.0)
			features["discard_priority_hint"] = _normalize_score(float(context.get("discard_priority_hint", 0.0)), 400.0)
	elif item is PokemonSlot:
		var slot: PokemonSlot = item
		features["item_is_slot"] = true
		var game_state: GameState = context.get("game_state", null)
		var player_index: int = int(context.get("player_index", -1))
		var owner_player: PlayerState = null
		if game_state != null and player_index >= 0 and player_index < game_state.players.size():
			owner_player = game_state.players[player_index]
		features["slot_is_active"] = owner_player != null and owner_player.active_pokemon == slot
		features["slot_is_bench"] = owner_player != null and owner_player.bench.has(slot)
		features["remaining_hp"] = _normalize_score(float(slot.get_remaining_hp()), 330.0)
		features["damage_counters"] = _normalize_score(float(slot.damage_counters), 33.0)
		features["attached_energy_count"] = _normalize_score(float(slot.attached_energy.size()), 8.0)

	return features


func build_vector(item: Variant, step: Dictionary, context: Dictionary = {}) -> Array[float]:
	var features: Dictionary = build_features(item, step, context)
	var vector: Array[float] = []
	for key: String in FEATURE_SCHEMA:
		var value: Variant = features.get(key, 0.0)
		if value is bool:
			vector.append(1.0 if bool(value) else 0.0)
		else:
			vector.append(float(value))
	return vector


func _normalize_score(value: float, max_value: float) -> float:
	if max_value <= 0.0:
		return 0.0
	return clampf(value / max_value, 0.0, 1.0)
