class_name StateEncoder
extends RefCounted

const FEATURE_DIM: int = 52
const MIRAIDON_FEATURE_OFFSET: int = 44
const RESOURCE_COUNT_CLAMP: float = 4.0


static func encode(game_state: GameState, perspective_player: int) -> Array[float]:
	var features: Array[float] = []
	features.resize(FEATURE_DIM)
	features.fill(0.0)

	if game_state == null or perspective_player < 0 or perspective_player >= game_state.players.size():
		return features

	var my_player: PlayerState = game_state.players[perspective_player]
	var opp_player: PlayerState = game_state.players[1 - perspective_player]
	var my_is_current: bool = game_state.current_player_index == perspective_player

	_encode_player(my_player, features, 0, my_is_current, game_state)
	_encode_player(opp_player, features, 20, not my_is_current, game_state)

	features[40] = clampf(float(game_state.turn_number) / 30.0, 0.0, 1.0)
	features[41] = 1.0 if game_state.first_player_index == perspective_player else 0.0
	features[42] = 1.0 if game_state.stadium_card != null else 0.0
	features[43] = 1.0 if game_state.phase == GameState.GamePhase.MAIN else 0.0

	_encode_miraidon_resources(my_player, features, MIRAIDON_FEATURE_OFFSET)

	return features


static func _encode_player(player: PlayerState, features: Array[float], offset: int, is_current_player: bool, game_state: GameState) -> void:
	if player == null:
		return

	var slot: PokemonSlot = player.active_pokemon
	if slot != null:
		var card_data: CardData = slot.get_card_data()
		if card_data != null and card_data.hp > 0:
			var remaining_hp: float = float(card_data.hp - slot.damage_counters)
			features[offset + 0] = clampf(remaining_hp / float(card_data.hp), 0.0, 1.0)
			features[offset + 1] = clampf(float(slot.damage_counters) / float(card_data.hp), 0.0, 1.0)
		features[offset + 2] = float(slot.attached_energy.size()) / 5.0
		if card_data != null and not card_data.attacks.is_empty() and slot.attached_energy.size() > 0:
			features[offset + 3] = 1.0
		features[offset + 4] = 1.0 if _is_ex(slot) else 0.0
		features[offset + 5] = _stage_to_float(slot)

	features[offset + 6] = float(player.bench.size()) / 5.0
	var bench_hp: float = 0.0
	var bench_energy: float = 0.0
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot == null:
			continue
		var bench_card_data: CardData = bench_slot.get_card_data()
		if bench_card_data != null:
			bench_hp += float(bench_card_data.hp - bench_slot.damage_counters)
		bench_energy += float(bench_slot.attached_energy.size())
	features[offset + 7] = bench_hp / 500.0
	features[offset + 8] = bench_energy / 10.0

	features[offset + 9] = float(player.hand.size()) / 20.0
	features[offset + 10] = float(player.deck.size()) / 40.0
	features[offset + 11] = float(player.prizes.size()) / 6.0

	if is_current_player:
		features[offset + 12] = 0.0 if game_state.supporter_used_this_turn else 1.0
		features[offset + 13] = 0.0 if game_state.energy_attached_this_turn else 1.0
	else:
		features[offset + 12] = 1.0
		features[offset + 13] = 1.0

	if slot != null:
		var status_conditions: Dictionary = slot.status_conditions
		features[offset + 14] = 1.0 if (bool(status_conditions.get("poisoned", false)) or bool(status_conditions.get("burned", false))) else 0.0
		features[offset + 15] = 1.0 if (bool(status_conditions.get("asleep", false)) or bool(status_conditions.get("paralyzed", false)) or bool(status_conditions.get("confused", false))) else 0.0
		var active_card_data: CardData = slot.get_card_data()
		features[offset + 16] = float(active_card_data.retreat_cost) / 4.0 if active_card_data != null else 0.0
		features[offset + 17] = 1.0 if slot.attached_tool != null else 0.0

	var evolved_count: int = 0
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot == null:
			continue
		var bench_card_data: CardData = bench_slot.get_card_data()
		if bench_card_data != null and bench_card_data.stage != "Basic":
			evolved_count += 1
	features[offset + 18] = float(evolved_count) / 5.0
	features[offset + 19] = float(player.discard_pile.size()) / 40.0


static func _encode_miraidon_resources(player: PlayerState, features: Array[float], offset: int) -> void:
	if player == null:
		return

	features[offset + 0] = 1.0 if _count_named_cards(player.hand, "Arven") > 0 else 0.0
	features[offset + 1] = 1.0 if _count_named_cards(player.hand, "Electric Generator") > 0 else 0.0
	features[offset + 2] = _normalize_resource_count(_count_lightning_basic_pokemon(player.hand))
	features[offset + 3] = _normalize_resource_count(_count_basic_lightning_energy(player.hand))
	features[offset + 4] = _normalize_resource_count(_count_basic_lightning_energy(player.deck))
	features[offset + 5] = _normalize_resource_count(_count_named_cards(player.deck, "Electric Generator"))
	features[offset + 6] = _normalize_resource_count(_count_basic_lightning_energy(player.discard_pile))
	features[offset + 7] = _normalize_resource_count(_count_named_cards(player.discard_pile, "Electric Generator"))


static func _normalize_resource_count(count: int) -> float:
	return clampf(float(count) / RESOURCE_COUNT_CLAMP, 0.0, 1.0)


static func _count_named_cards(cards: Array, target_name: String) -> int:
	var count := 0
	for card_variant: Variant in cards:
		var card: CardInstance = card_variant if card_variant is CardInstance else null
		if card == null or card.card_data == null:
			continue
		if str(card.card_data.name) == target_name:
			count += 1
	return count


static func _count_basic_lightning_energy(cards: Array) -> int:
	var count := 0
	for card_variant: Variant in cards:
		var card: CardInstance = card_variant if card_variant is CardInstance else null
		if card == null or card.card_data == null:
			continue
		if str(card.card_data.card_type) == "Basic Energy" and str(card.card_data.energy_type) == "L":
			count += 1
	return count


static func _count_lightning_basic_pokemon(cards: Array) -> int:
	var count := 0
	for card_variant: Variant in cards:
		var card: CardInstance = card_variant if card_variant is CardInstance else null
		if card == null or card.card_data == null:
			continue
		if str(card.card_data.card_type) != "Pokemon":
			continue
		if str(card.card_data.stage) != "Basic":
			continue
		if str(card.card_data.energy_type) != "L":
			continue
		count += 1
	return count


static func _is_ex(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	var card_data: CardData = slot.get_card_data()
	if card_data == null:
		return false
	return card_data.mechanic == "ex" or card_data.mechanic == "V" or card_data.mechanic == "VSTAR" or card_data.mechanic == "VMAX"


static func _stage_to_float(slot: PokemonSlot) -> float:
	if slot == null:
		return 0.0
	var card_data: CardData = slot.get_card_data()
	if card_data == null:
		return 0.0
	match card_data.stage:
		"Basic":
			return 0.0
		"Stage 1":
			return 0.5
		"Stage 2":
			return 1.0
		_:
			return 0.0
