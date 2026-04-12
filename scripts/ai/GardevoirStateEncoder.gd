class_name GardevoirStateEncoder
extends RefCounted

## 沙奈朵卡组专用 124 维特征编码器。
## 接口与 StateEncoder 相同：static func encode(game_state, perspective_player) -> Array[float]

const FEATURE_DIM: int = 124

# 卡牌名称常量（与 DeckStrategyGardevoir 一致）
const GARDEVOIR_EX := "沙奈朵ex"
const KIRLIA := "奇鲁莉安"
const RALTS := "拉鲁拉丝"
const MUNKIDORI := "愿增猿"
const DRIFLOON := "飘飘球"
const DRIFBLIM := "附和气球"
const SCREAM_TAIL := "吼叫尾"
const MANAPHY := "玛纳霏"
const KLEFKI := "钥圈儿"
const FLUTTER_MANE := "振翼发"
const RADIANT_GRENINJA := "光辉甲贺忍蛙"

const ATTACKER_NAMES: Array[String] = ["飘飘球", "附和气球", "吼叫尾"]

const ULTRA_BALL := "高级球"
const BOSSS_ORDERS := "老大的指令"
const RARE_CANDY := "Rare Candy"
const BUDDY_BUDDY_POFFIN := "友好宝芬"
const NEST_BALL := "巢穴球"
const SECRET_BOX := "秘密箱"
const EARTHEN_VESSEL := "大地容器"
const NIGHT_STRETCHER := "夜间担架"
const RESCUE_STRETCHER := "救援担架"
const COUNTER_CATCHER := "反击捕捉器"


static func encode(game_state: GameState, perspective_player: int) -> Array[float]:
	var features: Array[float] = []
	features.resize(FEATURE_DIM)
	features.fill(0.0)

	if game_state == null or perspective_player < 0 or perspective_player >= game_state.players.size():
		return features

	var my_player: PlayerState = game_state.players[perspective_player]
	var opp_player: PlayerState = game_state.players[1 - perspective_player]

	# 通用板面 (×2): 0-19 己方, 20-39 对手
	_encode_board(my_player, game_state, perspective_player, features, 0)
	_encode_board(opp_player, game_state, 1 - perspective_player, features, 20)

	# 卡牌身份 (×2): 40-51 己方, 52-63 对手
	_encode_identity(my_player, features, 40)
	_encode_identity(opp_player, features, 52)

	# 沙奈朵资源 (己方): 64-83
	_encode_gardevoir_resources(my_player, game_state, perspective_player, features, 64)

	# 全局: 84-91
	_encode_global(game_state, perspective_player, my_player, opp_player, features, 84)

	# 攻击手细节: 92-99
	_encode_attacker_detail(my_player, opp_player, features, 92)

	# 保留 100-123 填零（将来可扩展）
	return features


static func _encode_board(player: PlayerState, game_state: GameState, player_index: int, features: Array[float], offset: int) -> void:
	if player == null:
		return
	var active: PokemonSlot = player.active_pokemon

	# [0] 前场 HP 分数
	if active != null:
		var cd: CardData = active.get_card_data()
		if cd != null and cd.hp > 0:
			features[offset + 0] = clampf(float(cd.hp - active.damage_counters) / float(cd.hp), 0.0, 1.0)

	# [1] 前场能量数
	if active != null:
		features[offset + 1] = clampf(float(active.attached_energy.size()) / 5.0, 0.0, 1.0)

	# [2] 后备数
	features[offset + 2] = clampf(float(player.bench.size()) / 5.0, 0.0, 1.0)

	# [3] 手牌数
	features[offset + 3] = clampf(float(player.hand.size()) / 20.0, 0.0, 1.0)

	# [4] 牌库数
	features[offset + 4] = clampf(float(player.deck.size()) / 40.0, 0.0, 1.0)

	# [5] 奖赏数
	features[offset + 5] = clampf(float(player.prizes.size()) / 6.0, 0.0, 1.0)

	# [6] 弃牌堆数
	features[offset + 6] = clampf(float(player.discard_pile.size()) / 40.0, 0.0, 1.0)

	# [7] 前场状态异常
	if active != null:
		var sc: Dictionary = active.status_conditions
		if bool(sc.get("poisoned", false)) or bool(sc.get("burned", false)) \
			or bool(sc.get("asleep", false)) or bool(sc.get("paralyzed", false)) \
			or bool(sc.get("confused", false)):
			features[offset + 7] = 1.0

	# [8] 前场可攻击（有招式且有能量）
	if active != null:
		var cd: CardData = active.get_card_data()
		if cd != null and not cd.attacks.is_empty():
			var attached: int = active.attached_energy.size()
			var can_attack: bool = false
			for attack: Dictionary in cd.attacks:
				var cost: String = str(attack.get("cost", ""))
				if attached >= cost.length():
					can_attack = true
					break
			if can_attack:
				features[offset + 8] = 1.0

	# [9] 撤退差（前场撤退费 - 已有能量）
	if active != null:
		var cd: CardData = active.get_card_data()
		if cd != null:
			var gap: int = maxi(0, int(cd.retreat_cost) - active.attached_energy.size())
			features[offset + 9] = clampf(float(gap) / 4.0, 0.0, 1.0)

	# [10] 后备总 HP 分数
	var bench_hp_frac: float = 0.0
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot == null:
			continue
		var bcd: CardData = bench_slot.get_card_data()
		if bcd != null and bcd.hp > 0:
			bench_hp_frac += float(bcd.hp - bench_slot.damage_counters) / float(bcd.hp)
	features[offset + 10] = clampf(bench_hp_frac / 5.0, 0.0, 1.0)

	# [11] 后备总能量
	var bench_energy: int = 0
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot != null:
			bench_energy += bench_slot.attached_energy.size()
	features[offset + 11] = clampf(float(bench_energy) / 10.0, 0.0, 1.0)

	# [12] 前场是 ex/V
	if active != null:
		var cd: CardData = active.get_card_data()
		if cd != null and (cd.mechanic == "ex" or cd.mechanic == "V"):
			features[offset + 12] = 1.0

	# [13] 前场进化阶段
	if active != null:
		var cd: CardData = active.get_card_data()
		if cd != null:
			match cd.stage:
				"Stage 1": features[offset + 13] = 0.5
				"Stage 2": features[offset + 13] = 1.0

	# [14] 是否已用支援者
	var is_current: bool = game_state.current_player_index == player_index
	if is_current:
		features[offset + 14] = 1.0 if game_state.supporter_used_this_turn else 0.0
	# [15] 是否已贴能量
	if is_current:
		features[offset + 15] = 1.0 if game_state.energy_attached_this_turn else 0.0

	# [16] 前场有道具
	if active != null and active.attached_tool != null:
		features[offset + 16] = 1.0

	# [17] 进化宝可梦数
	var evolved: int = 0
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot == null:
			continue
		var bcd: CardData = bench_slot.get_card_data()
		if bcd != null and bcd.stage != "Basic":
			evolved += 1
	features[offset + 17] = clampf(float(evolved) / 5.0, 0.0, 1.0)

	# [18] 前场伤害指示物比例
	if active != null:
		var cd: CardData = active.get_card_data()
		if cd != null and cd.hp > 0:
			features[offset + 18] = clampf(float(active.damage_counters) / float(cd.hp), 0.0, 1.0)

	# [19] 前场撤退费
	if active != null:
		var cd: CardData = active.get_card_data()
		if cd != null:
			features[offset + 19] = clampf(float(cd.retreat_cost) / 4.0, 0.0, 1.0)


static func _encode_identity(player: PlayerState, features: Array[float], offset: int) -> void:
	## 卡牌身份 12 维 — 场上各角色存在/数量
	if player == null:
		return

	var all_slots: Array[PokemonSlot] = _get_all_slots(player)

	# [0] 拉鲁拉丝数
	features[offset + 0] = clampf(float(_count_name(all_slots, RALTS)) / 3.0, 0.0, 1.0)
	# [1] 奇鲁莉安数
	features[offset + 1] = clampf(float(_count_name(all_slots, KIRLIA)) / 3.0, 0.0, 1.0)
	# [2] 沙奈朵ex数
	features[offset + 2] = clampf(float(_count_name(all_slots, GARDEVOIR_EX)) / 2.0, 0.0, 1.0)
	# [3] 愿增猿在场
	features[offset + 3] = 1.0 if _count_name(all_slots, MUNKIDORI) > 0 else 0.0
	# [4] 攻击手在场数
	var attacker_count: int = 0
	for slot: PokemonSlot in all_slots:
		if slot.get_pokemon_name() in ATTACKER_NAMES or slot.get_pokemon_name() == SCREAM_TAIL:
			attacker_count += 1
	features[offset + 4] = clampf(float(attacker_count) / 3.0, 0.0, 1.0)
	# [5] 引擎已启动（沙奈朵ex >= 1）
	features[offset + 5] = 1.0 if _count_name(all_slots, GARDEVOIR_EX) >= 1 else 0.0
	# [6] 精炼可用（奇鲁莉安 >= 1）
	features[offset + 6] = 1.0 if _count_name(all_slots, KIRLIA) >= 1 else 0.0
	# [7] 玛纳霏在场
	features[offset + 7] = 1.0 if _count_name(all_slots, MANAPHY) > 0 else 0.0
	# [8] 钥圈儿在场
	features[offset + 8] = 1.0 if _count_name(all_slots, KLEFKI) > 0 else 0.0
	# [9] 振翼发在场
	features[offset + 9] = 1.0 if _count_name(all_slots, FLUTTER_MANE) > 0 else 0.0
	# [10] 最佳攻击手伤害（归一化）
	var best_dmg: int = 0
	for slot: PokemonSlot in all_slots:
		var dmg: int = _predict_damage(slot)
		if dmg > best_dmg:
			best_dmg = dmg
	features[offset + 10] = clampf(float(best_dmg) / 300.0, 0.0, 1.0)
	# [11] 进化线总数
	var line_total: int = _count_name(all_slots, RALTS) + _count_name(all_slots, KIRLIA) + _count_name(all_slots, GARDEVOIR_EX)
	features[offset + 11] = clampf(float(line_total) / 5.0, 0.0, 1.0)


static func _encode_gardevoir_resources(player: PlayerState, game_state: GameState, player_index: int, features: Array[float], offset: int) -> void:
	## 沙奈朵资源 20 维 — 弃牌堆能量、手牌关键道具、进化缺口等
	if player == null:
		return

	# [0] 弃牌堆超能量数
	var discard_psychic: int = _count_psychic_in_discard(game_state, player_index)
	features[offset + 0] = clampf(float(discard_psychic) / 8.0, 0.0, 1.0)

	# [1] 弃牌堆超能量 >= 3（Embrace 引擎充裕）
	features[offset + 1] = 1.0 if discard_psychic >= 3 else 0.0

	# [2-11] 手牌关键道具
	features[offset + 2] = 1.0 if _hand_has(player, ULTRA_BALL) else 0.0
	features[offset + 3] = 1.0 if _hand_has(player, BOSSS_ORDERS) else 0.0
	features[offset + 4] = 1.0 if _hand_has(player, RARE_CANDY) else 0.0
	features[offset + 5] = 1.0 if _hand_has(player, BUDDY_BUDDY_POFFIN) else 0.0
	features[offset + 6] = 1.0 if _hand_has(player, NEST_BALL) else 0.0
	features[offset + 7] = 1.0 if _hand_has(player, SECRET_BOX) else 0.0
	features[offset + 8] = 1.0 if _hand_has(player, EARTHEN_VESSEL) else 0.0
	features[offset + 9] = 1.0 if _hand_has(player, NIGHT_STRETCHER) or _hand_has(player, RESCUE_STRETCHER) else 0.0
	features[offset + 10] = 1.0 if _hand_has(player, COUNTER_CATCHER) else 0.0
	features[offset + 11] = 1.0 if _hand_has(player, GARDEVOIR_EX) else 0.0

	# [12] 手牌超能量数
	var hand_psychic: int = _count_energy_in_hand(player, "P")
	features[offset + 12] = clampf(float(hand_psychic) / 4.0, 0.0, 1.0)

	# [13] 手牌恶能量数
	var hand_dark: int = _count_energy_in_hand(player, "D")
	features[offset + 13] = clampf(float(hand_dark) / 2.0, 0.0, 1.0)

	# [14] 进化缺口（场上拉鲁拉丝线 < 2）
	var all_slots: Array[PokemonSlot] = _get_all_slots(player)
	var line: int = _count_name(all_slots, RALTS) + _count_name(all_slots, KIRLIA) + _count_name(all_slots, GARDEVOIR_EX)
	features[offset + 14] = clampf(float(maxi(0, 2 - line)) / 2.0, 0.0, 1.0)

	# [15] 空板位数
	features[offset + 15] = clampf(float(maxi(0, 5 - player.bench.size())) / 5.0, 0.0, 1.0)

	# [16] 弃牌堆有核心宝可梦
	features[offset + 16] = 1.0 if _has_in_discard_names(game_state, player_index, [GARDEVOIR_EX, KIRLIA, RALTS]) else 0.0

	# [17] 弃牌堆有攻击手
	features[offset + 17] = 1.0 if _has_in_discard_names(game_state, player_index, [DRIFLOON, DRIFBLIM, SCREAM_TAIL]) else 0.0

	# [18] 愿增猿已贴恶能
	var has_munkidori_dark: bool = false
	for slot: PokemonSlot in all_slots:
		if slot.get_pokemon_name() == MUNKIDORI:
			for e: CardInstance in slot.attached_energy:
				if e != null and e.card_data != null and str(e.card_data.energy_provides) == "D":
					has_munkidori_dark = true
					break
	features[offset + 18] = 1.0 if has_munkidori_dark else 0.0

	# [19] 手牌奇鲁莉安（用于进化）
	features[offset + 19] = 1.0 if _hand_has(player, KIRLIA) else 0.0


static func _encode_global(game_state: GameState, perspective_player: int, my_player: PlayerState, opp_player: PlayerState, features: Array[float], offset: int) -> void:
	## 全局 8 维
	# [0] 回合
	features[offset + 0] = clampf(float(game_state.turn_number) / 30.0, 0.0, 1.0)
	# [1] 先手
	features[offset + 1] = 1.0 if game_state.first_player_index == perspective_player else 0.0
	# [2] 阶段
	features[offset + 2] = 1.0 if game_state.phase == GameState.GamePhase.MAIN else 0.0
	# [3] 奖赏差（对手奖赏 - 己方奖赏，正 = 己方领先）
	var prize_diff: float = float(opp_player.prizes.size()) - float(my_player.prizes.size())
	features[offset + 3] = clampf((prize_diff + 6.0) / 12.0, 0.0, 1.0)
	# [4] 对手最弱后备 HP（归一化）
	var weakest_hp: int = 999
	for slot: PokemonSlot in opp_player.bench:
		if slot == null:
			continue
		var hp: int = slot.get_remaining_hp()
		if hp < weakest_hp:
			weakest_hp = hp
	if weakest_hp < 999:
		features[offset + 4] = clampf(float(weakest_hp) / 300.0, 0.0, 1.0)
	# [5] 场地卡存在
	features[offset + 5] = 1.0 if game_state.stadium_card != null else 0.0
	# [6] 对手前场 HP 分数
	var opp_active: PokemonSlot = opp_player.active_pokemon
	if opp_active != null:
		var ocd: CardData = opp_active.get_card_data()
		if ocd != null and ocd.hp > 0:
			features[offset + 6] = clampf(float(ocd.hp - opp_active.damage_counters) / float(ocd.hp), 0.0, 1.0)
	# [7] 对手前场是 ex/V
	if opp_active != null:
		var ocd: CardData = opp_active.get_card_data()
		if ocd != null and (ocd.mechanic == "ex" or ocd.mechanic == "V"):
			features[offset + 7] = 1.0


static func _encode_attacker_detail(my_player: PlayerState, opp_player: PlayerState, features: Array[float], offset: int) -> void:
	## 攻击手细节 8 维
	var all_slots: Array[PokemonSlot] = _get_all_slots(my_player)
	var opp_active: PokemonSlot = opp_player.active_pokemon
	var opp_active_hp: int = 999
	if opp_active != null:
		opp_active_hp = opp_active.get_remaining_hp()

	var active_best_dmg: int = 0
	var bench_best_dmg: int = 0
	var active_can_ko: bool = false
	var bench_can_ko: bool = false
	var embrace_unlocks_attack: bool = false
	var embrace_unlocks_ko: bool = false

	for slot: PokemonSlot in all_slots:
		var sname: String = slot.get_pokemon_name()
		if sname not in ATTACKER_NAMES and sname != SCREAM_TAIL:
			continue
		var dmg: int = _predict_damage(slot)
		var dmg_after: int = _predict_damage_with_extra(slot, 1)
		var can_atk: bool = _can_attack(slot)
		var can_atk_after: bool = _can_attack_with_extra(slot, 1)

		if slot == my_player.active_pokemon:
			active_best_dmg = maxi(active_best_dmg, dmg)
			if dmg >= opp_active_hp:
				active_can_ko = true
		else:
			bench_best_dmg = maxi(bench_best_dmg, dmg)
			if dmg >= opp_active_hp:
				bench_can_ko = true

		if not can_atk and can_atk_after:
			embrace_unlocks_attack = true
		if can_atk and dmg < opp_active_hp and dmg_after >= opp_active_hp:
			embrace_unlocks_ko = true

	# [0] 前场最优攻击手伤害
	features[offset + 0] = clampf(float(active_best_dmg) / 300.0, 0.0, 1.0)
	# [1] 后备最优攻击手伤害
	features[offset + 1] = clampf(float(bench_best_dmg) / 300.0, 0.0, 1.0)
	# [2] 前场能 KO
	features[offset + 2] = 1.0 if active_can_ko else 0.0
	# [3] 后备能 KO
	features[offset + 3] = 1.0 if bench_can_ko else 0.0
	# [4] Embrace 能解锁攻击
	features[offset + 4] = 1.0 if embrace_unlocks_attack else 0.0
	# [5] Embrace 能解锁 KO
	features[offset + 5] = 1.0 if embrace_unlocks_ko else 0.0
	# [6-7] 保留
	features[offset + 6] = 0.0
	features[offset + 7] = 0.0


# ============================================================
#  辅助函数
# ============================================================

static func _get_all_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


static func _count_name(slots: Array[PokemonSlot], pname: String) -> int:
	var count: int = 0
	for slot: PokemonSlot in slots:
		if slot.get_pokemon_name() == pname:
			count += 1
	return count


static func _hand_has(player: PlayerState, card_name: String) -> bool:
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and str(card.card_data.name) == card_name:
			return true
	return false


static func _count_energy_in_hand(player: PlayerState, etype: String) -> int:
	var count: int = 0
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.is_energy() and str(card.card_data.energy_provides) == etype:
			count += 1
	return count


static func _count_psychic_in_discard(game_state: GameState, player_index: int) -> int:
	if player_index < 0 or player_index >= game_state.players.size():
		return 0
	var count: int = 0
	for card: CardInstance in game_state.players[player_index].discard_pile:
		if card != null and card.card_data != null and card.card_data.is_energy() and str(card.card_data.energy_provides) == "P":
			count += 1
	return count


static func _has_in_discard_names(game_state: GameState, player_index: int, names: Array) -> bool:
	if player_index < 0 or player_index >= game_state.players.size():
		return false
	for card: CardInstance in game_state.players[player_index].discard_pile:
		if card != null and card.card_data != null and str(card.card_data.name) in names:
			return true
	return false


static func _predict_damage(slot: PokemonSlot) -> int:
	return _predict_damage_with_extra(slot, 0)


static func _predict_damage_with_extra(slot: PokemonSlot, extra_embrace: int) -> int:
	if slot == null or slot.get_top_card() == null:
		return 0
	var sname: String = slot.get_pokemon_name()
	var dc: int = slot.damage_counters + extra_embrace * 20
	var counter_count: int = dc / 10
	if sname == DRIFLOON or sname == DRIFBLIM:
		return counter_count * 30
	if sname == SCREAM_TAIL:
		return counter_count * 20
	return 0


static func _can_attack(slot: PokemonSlot) -> bool:
	return _can_attack_with_extra(slot, 0)


static func _can_attack_with_extra(slot: PokemonSlot, extra_embrace: int) -> bool:
	if slot == null or slot.get_top_card() == null:
		return false
	var cd: CardData = slot.get_card_data()
	if cd == null or cd.attacks.is_empty():
		return false
	var attached: int = slot.attached_energy.size() + extra_embrace
	for attack: Dictionary in cd.attacks:
		var cost: String = str(attack.get("cost", ""))
		if attached >= cost.length():
			return true
	return false
