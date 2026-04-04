class_name AIActionFeatureEncoder
extends RefCounted

const NEST_BALL_EFFECT_ID: String = "1af63a7e2cb7a79215474ad8db8fd8fd"
const FEATURE_SCHEMA: Array[String] = [
	"kind_play_trainer",
	"kind_use_ability",
	"kind_attach_tool",
	"kind_attach_energy",
	"kind_attack",
	"is_active_target",
	"is_bench_target",
	"requires_interaction",
	"improves_bench_development",
	"bench_development_delta",
	"improves_attack_readiness",
	"productive",
	"remaining_basic_targets",
	"projected_damage",
	"projected_knockout",
	"consumes_hand_card",
]


func get_schema() -> Array[String]:
	return FEATURE_SCHEMA.duplicate()


func build_features(gsm: GameStateMachine, player_index: int, action: Dictionary) -> Dictionary:
	var features := {
		"is_active_target": false,
		"is_bench_target": false,
		"requires_interaction": bool(action.get("requires_interaction", false)),
		"improves_bench_development": false,
		"bench_development_delta": 0.0,
		"improves_attack_readiness": false,
		"productive": true,
		"remaining_basic_targets": 0.0,
		"projected_damage": 0.0,
		"projected_knockout": false,
		"consumes_hand_card": _action_consumes_hand_card(action),
	}

	if gsm == null or gsm.game_state == null:
		return features
	if player_index < 0 or player_index >= gsm.game_state.players.size():
		return features

	var player: PlayerState = gsm.game_state.players[player_index]
	match str(action.get("kind", "")):
		"attach_energy":
			var target_slot: PokemonSlot = action.get("target_slot")
			var active_slot: PokemonSlot = player.active_pokemon
			var is_active_target: bool = target_slot != null and target_slot == active_slot
			features["is_active_target"] = is_active_target
			features["is_bench_target"] = target_slot != null and not is_active_target
			features["improves_bench_development"] = bool(features["is_bench_target"])
			if is_active_target:
				features["improves_attack_readiness"] = _attach_enables_attack(gsm, active_slot, action)
		"attach_tool":
			var tool_target_slot: PokemonSlot = action.get("target_slot")
			var active_tool_slot: PokemonSlot = player.active_pokemon
			var is_active_tool_target: bool = tool_target_slot != null and tool_target_slot == active_tool_slot
			features["is_active_target"] = is_active_tool_target
			features["is_bench_target"] = tool_target_slot != null and not is_active_tool_target
		"play_basic_to_bench":
			features["improves_bench_development"] = true
			features["bench_development_delta"] = 1.0
		"play_trainer":
			var card: CardInstance = action.get("card")
			if _is_nest_ball(card):
				var remaining_basic_targets: int = _count_basic_targets(player.deck)
				features["remaining_basic_targets"] = float(remaining_basic_targets)
				features["productive"] = remaining_basic_targets > 0
		"attack":
			var attack_index: int = int(action.get("attack_index", -1))
			var damage: int = gsm.get_attack_preview_damage(player_index, attack_index)
			features["projected_damage"] = float(damage)
			var opponent_index: int = 1 - player_index
			if opponent_index >= 0 and opponent_index < gsm.game_state.players.size():
				var defender: PokemonSlot = gsm.game_state.players[opponent_index].active_pokemon
				if defender != null:
					features["projected_knockout"] = damage >= defender.get_remaining_hp()

	return features


func build_vector(gsm: GameStateMachine, player_index: int, action: Dictionary) -> Array[float]:
	var features: Dictionary = build_features(gsm, player_index, action)
	var kind: String = str(action.get("kind", ""))
	var vector: Array[float] = []
	vector.append(1.0 if kind == "play_trainer" else 0.0)
	vector.append(1.0 if kind == "use_ability" else 0.0)
	vector.append(1.0 if kind == "attach_tool" else 0.0)
	vector.append(1.0 if kind == "attach_energy" else 0.0)
	vector.append(1.0 if kind == "attack" else 0.0)
	vector.append(1.0 if bool(features.get("is_active_target", false)) else 0.0)
	vector.append(1.0 if bool(features.get("is_bench_target", false)) else 0.0)
	vector.append(1.0 if bool(features.get("requires_interaction", false)) else 0.0)
	vector.append(1.0 if bool(features.get("improves_bench_development", false)) else 0.0)
	vector.append(_normalized_delta(float(features.get("bench_development_delta", 0.0)), 3.0))
	vector.append(1.0 if bool(features.get("improves_attack_readiness", false)) else 0.0)
	vector.append(1.0 if bool(features.get("productive", true)) else 0.0)
	vector.append(_normalized_delta(float(features.get("remaining_basic_targets", 0.0)), 6.0))
	vector.append(_normalized_delta(float(features.get("projected_damage", 0.0)), 330.0))
	vector.append(1.0 if bool(features.get("projected_knockout", false)) else 0.0)
	vector.append(1.0 if bool(features.get("consumes_hand_card", false)) else 0.0)
	return vector


func _action_consumes_hand_card(action: Dictionary) -> bool:
	return action.get("card") is CardInstance


func _attach_enables_attack(gsm: GameStateMachine, active_slot: PokemonSlot, action: Dictionary) -> bool:
	if gsm == null or gsm.rule_validator == null or active_slot == null:
		return false
	var card_data: CardData = active_slot.get_card_data()
	var energy_card: CardInstance = action.get("card")
	if card_data == null or energy_card == null or card_data.attacks.is_empty():
		return false
	var simulated_slot := PokemonSlot.new()
	simulated_slot.pokemon_stack = active_slot.pokemon_stack.duplicate()
	simulated_slot.attached_energy = active_slot.attached_energy.duplicate()
	simulated_slot.attached_energy.append(energy_card)

	for attack: Dictionary in card_data.attacks:
		var cost: String = CardData.normalize_attack_cost(attack.get("cost", ""))
		if cost == "":
			continue
		var has_attack_before_attach: bool = gsm.rule_validator.has_enough_energy(active_slot, cost, gsm.effect_processor, gsm.game_state)
		if has_attack_before_attach:
			continue
		if gsm.rule_validator.has_enough_energy(simulated_slot, cost, gsm.effect_processor, gsm.game_state):
			return true
	return false


func _count_basic_targets(deck: Array[CardInstance]) -> int:
	var count: int = 0
	for card: CardInstance in deck:
		if card != null and card.is_basic_pokemon():
			count += 1
	return count


func _is_nest_ball(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	return card.card_data.effect_id == NEST_BALL_EFFECT_ID


func _normalized_delta(value: float, max_value: float) -> float:
	if max_value <= 0.0:
		return 0.0
	return clamp(value / max_value, 0.0, 1.0)
