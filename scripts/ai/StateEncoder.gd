class_name StateEncoder
extends RefCounted

## 局面编码为固定长度特征向量。
## 对称编码：以 perspective_player 为视角。

const FEATURE_DIM: int = 44


static func encode(game_state: GameState, perspective_player: int) -> Array[float]:
	var features: Array[float] = []
	features.resize(FEATURE_DIM)
	features.fill(0.0)

	if game_state == null or perspective_player < 0 or perspective_player >= game_state.players.size():
		return features

	var my_player: PlayerState = game_state.players[perspective_player]
	var opp_player: PlayerState = game_state.players[1 - perspective_player]

	var my_is_current: bool = game_state.current_player_index == perspective_player
	## 索引 0-19: 自己的特征
	_encode_player(my_player, features, 0, my_is_current, game_state)
	## 索引 20-39: 对手的特征
	_encode_player(opp_player, features, 20, not my_is_current, game_state)
	## 索引 40-43: 全局特征
	features[40] = clampf(float(game_state.turn_number) / 30.0, 0.0, 1.0)
	features[41] = 1.0 if game_state.first_player_index == perspective_player else 0.0
	features[42] = 1.0 if game_state.stadium_card != null else 0.0
	features[43] = 1.0 if game_state.phase == GameState.GamePhase.MAIN else 0.0

	return features


static func _encode_player(player: PlayerState, features: Array[float], offset: int, is_current_player: bool, game_state: GameState) -> void:
	if player == null:
		return

	var slot: PokemonSlot = player.active_pokemon
	if slot != null:
		var cd: CardData = slot.get_card_data()
		if cd != null and cd.hp > 0:
			var remaining_hp: float = float(cd.hp - slot.damage_counters)
			features[offset + 0] = clampf(remaining_hp / float(cd.hp), 0.0, 1.0)
			features[offset + 1] = clampf(float(slot.damage_counters) / float(cd.hp), 0.0, 1.0)
		features[offset + 2] = float(slot.attached_energy.size()) / 5.0
		if slot.get_card_data() != null and not slot.get_card_data().attacks.is_empty() and slot.attached_energy.size() > 0:
			features[offset + 3] = 1.0
		features[offset + 4] = 1.0 if _is_ex(slot) else 0.0
		features[offset + 5] = _stage_to_float(slot)

	features[offset + 6] = float(player.bench.size()) / 5.0
	var bench_hp: float = 0.0
	var bench_energy: float = 0.0
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot == null:
			continue
		var bcd: CardData = bench_slot.get_card_data()
		if bcd != null:
			bench_hp += float(bcd.hp - bench_slot.damage_counters)
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

	## 状态异常
	if slot != null:
		var sc: Dictionary = slot.status_conditions
		features[offset + 14] = 1.0 if (bool(sc.get("poisoned", false)) or bool(sc.get("burned", false))) else 0.0
		features[offset + 15] = 1.0 if (bool(sc.get("asleep", false)) or bool(sc.get("paralyzed", false)) or bool(sc.get("confused", false))) else 0.0
		var cd2: CardData = slot.get_card_data()
		features[offset + 16] = float(cd2.retreat_cost) / 4.0 if cd2 != null else 0.0
		features[offset + 17] = 1.0 if slot.attached_tool != null else 0.0

	## 后备区进化数
	var evolved_count: int = 0
	for bs: PokemonSlot in player.bench:
		if bs == null:
			continue
		var bcd2: CardData = bs.get_card_data()
		if bcd2 != null and bcd2.stage != "Basic":
			evolved_count += 1
	features[offset + 18] = float(evolved_count) / 5.0

	## 弃牌区大小
	features[offset + 19] = float(player.discard_pile.size()) / 40.0


static func _is_ex(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return false
	return cd.mechanic == "ex" or cd.mechanic == "V" or cd.mechanic == "VSTAR" or cd.mechanic == "VMAX"


static func _stage_to_float(slot: PokemonSlot) -> float:
	if slot == null:
		return 0.0
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return 0.0
	match cd.stage:
		"Basic":
			return 0.0
		"Stage 1":
			return 0.5
		"Stage 2":
			return 1.0
		_:
			return 0.0
