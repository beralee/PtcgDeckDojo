class_name MiraidonStateEncoder
extends RefCounted

## 密勒顿卡组专用 100 维特征编码器。
## 接口与 GardevoirStateEncoder 相同：static func encode(game_state, perspective_player) -> Array[float]

const FEATURE_DIM: int = 100

# 卡牌名称常量
const MIRAIDON_EX := "密勒顿ex"
const IRON_HANDS_EX := "铁臂膀ex"
const ZAPDOS := "闪电鸟"
const RAIKOU_V := "雷公V"
const RAICHU_V := "雷丘V"
const URSALUNA_EX := "月月熊·赫月ex"
const MEW_EX := "梦幻ex"
const LUMINEON_V := "霓虹鱼V"
const RADIANT_GRENINJA := "光辉甲贺忍蛙"
const SQUAWKABILLY_EX := "怒鹦哥ex"
const KILOWATTREL_EX := "吉雉鸡ex"

const ELECTRIC_GENERATOR := "电气发生器"
const NEST_BALL := "巢穴球"
const SWITCH_CART := "交替推车"
const BOSSS_ORDERS := "老大的指令"
const PAIPA := "派帕"
const DOUBLE_TURBO_ENERGY := "双重涡轮能量"
const GRAVITY_MOUNTAIN := "重力山"
const PRIME_CATCHER := "顶尖捕捉器"

const ALL_ATTACKER_NAMES: Array[String] = ["铁臂膀ex", "闪电鸟", "雷公V", "雷丘V", "密勒顿ex"]
const NON_RULE_ATTACKER: Array[String] = ["月月熊·赫月ex"]


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

	# 卡牌身份 (×2): 40-49 己方, 50-59 对手
	_encode_identity(my_player, features, 40)
	_encode_identity(opp_player, features, 50)

	# 密勒顿资源 (己方): 60-75
	_encode_miraidon_resources(my_player, game_state, perspective_player, features, 60)

	# 全局: 76-83
	_encode_global(game_state, perspective_player, my_player, opp_player, features, 76)

	# 攻击手细节: 84-91
	_encode_attacker_detail(my_player, opp_player, features, 84)

	# 保留 92-99 填零
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

	# [8] 前场可攻击
	if active != null:
		var cd: CardData = active.get_card_data()
		if cd != null and not cd.attacks.is_empty():
			var attached: int = active.attached_energy.size()
			for attack: Dictionary in cd.attacks:
				var cost: String = str(attack.get("cost", ""))
				if attached >= cost.length():
					features[offset + 8] = 1.0
					break

	# [9] 撤退差
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

	# [13] 前场是雷属性
	if active != null:
		var cd: CardData = active.get_card_data()
		if cd != null and str(cd.energy_type) == "L":
			features[offset + 13] = 1.0

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

	# [17] 前场伤害指示物比例
	if active != null:
		var cd: CardData = active.get_card_data()
		if cd != null and cd.hp > 0:
			features[offset + 17] = clampf(float(active.damage_counters) / float(cd.hp), 0.0, 1.0)

	# [18] 前场撤退费
	if active != null:
		var cd: CardData = active.get_card_data()
		if cd != null:
			features[offset + 18] = clampf(float(cd.retreat_cost) / 4.0, 0.0, 1.0)

	# [19] 后备雷系宝可梦数
	var lightning_count: int = 0
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot == null:
			continue
		var bcd: CardData = bench_slot.get_card_data()
		if bcd != null and str(bcd.energy_type) == "L":
			lightning_count += 1
	features[offset + 19] = clampf(float(lightning_count) / 5.0, 0.0, 1.0)


static func _encode_identity(player: PlayerState, features: Array[float], offset: int) -> void:
	## 卡牌身份 10 维
	if player == null:
		return

	var all_slots: Array[PokemonSlot] = _get_all_slots(player)

	# [0] 密勒顿ex 数
	features[offset + 0] = clampf(float(_count_name(all_slots, MIRAIDON_EX)) / 2.0, 0.0, 1.0)
	# [1] 铁臂膀ex 数
	features[offset + 1] = clampf(float(_count_name(all_slots, IRON_HANDS_EX)) / 2.0, 0.0, 1.0)
	# [2] 闪电鸟在场
	features[offset + 2] = 1.0 if _count_name(all_slots, ZAPDOS) > 0 else 0.0
	# [3] 雷公V在场
	features[offset + 3] = 1.0 if _count_name(all_slots, RAIKOU_V) > 0 else 0.0
	# [4] 雷丘V在场
	features[offset + 4] = 1.0 if _count_name(all_slots, RAICHU_V) > 0 else 0.0
	# [5] 月月熊在场
	features[offset + 5] = 1.0 if _count_name(all_slots, URSALUNA_EX) > 0 else 0.0
	# [6] 雷系打手总数
	var lightning_attackers: int = 0
	for slot: PokemonSlot in all_slots:
		if slot.get_pokemon_name() in ALL_ATTACKER_NAMES:
			lightning_attackers += 1
	features[offset + 6] = clampf(float(lightning_attackers) / 5.0, 0.0, 1.0)
	# [7] 就绪打手数
	var ready_count: int = 0
	for slot: PokemonSlot in all_slots:
		if slot.get_pokemon_name() in ALL_ATTACKER_NAMES or slot.get_pokemon_name() in NON_RULE_ATTACKER:
			if _can_attack(slot):
				ready_count += 1
	features[offset + 7] = clampf(float(ready_count) / 4.0, 0.0, 1.0)
	# [8] 最佳攻击手伤害（归一化）
	var best_dmg: int = 0
	for slot: PokemonSlot in all_slots:
		var dmg: int = _get_best_attack_damage(slot)
		if dmg > best_dmg:
			best_dmg = dmg
	features[offset + 8] = clampf(float(best_dmg) / 300.0, 0.0, 1.0)
	# [9] 引擎已启动（密勒顿ex >= 1 在后备）
	var engine_on_bench: bool = false
	for slot: PokemonSlot in player.bench:
		if slot != null and slot.get_pokemon_name() == MIRAIDON_EX:
			engine_on_bench = true
			break
	features[offset + 9] = 1.0 if engine_on_bench else 0.0


static func _encode_miraidon_resources(player: PlayerState, game_state: GameState, player_index: int, features: Array[float], offset: int) -> void:
	## 密勒顿资源 16 维
	if player == null:
		return

	# [0] 手牌：电气发生器
	features[offset + 0] = 1.0 if _hand_has(player, ELECTRIC_GENERATOR) else 0.0
	# [1] 手牌：派帕
	features[offset + 1] = 1.0 if _hand_has(player, PAIPA) else 0.0
	# [2] 手牌：老大的指令
	features[offset + 2] = 1.0 if _hand_has(player, BOSSS_ORDERS) else 0.0
	# [3] 手牌：交替推车
	features[offset + 3] = 1.0 if _hand_has(player, SWITCH_CART) else 0.0
	# [4] 手牌：巢穴球
	features[offset + 4] = 1.0 if _hand_has(player, NEST_BALL) else 0.0
	# [5] 手牌：雷能量数
	var hand_lightning: int = _count_energy_in_hand(player, "L")
	features[offset + 5] = clampf(float(hand_lightning) / 6.0, 0.0, 1.0)
	# [6] 手牌：双重涡轮数
	features[offset + 6] = 1.0 if _hand_has(player, DOUBLE_TURBO_ENERGY) else 0.0
	# [7] 牌库雷能量数
	var deck_lightning: int = 0
	for card: CardInstance in player.deck:
		if card != null and card.card_data != null and card.card_data.is_energy() and str(card.card_data.energy_provides) == "L":
			deck_lightning += 1
	features[offset + 7] = clampf(float(deck_lightning) / 17.0, 0.0, 1.0)
	# [8] 牌库电气发生器数
	var deck_eg: int = 0
	for card: CardInstance in player.deck:
		if card != null and card.card_data != null and str(card.card_data.name) == ELECTRIC_GENERATOR:
			deck_eg += 1
	features[offset + 8] = clampf(float(deck_eg) / 4.0, 0.0, 1.0)
	# [9] 弃牌堆雷能量数
	var discard_lightning: int = 0
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and card.card_data.is_energy() and str(card.card_data.energy_provides) == "L":
			discard_lightning += 1
	features[offset + 9] = clampf(float(discard_lightning) / 17.0, 0.0, 1.0)
	# [10] 空板位
	features[offset + 10] = clampf(float(maxi(0, 5 - player.bench.size())) / 5.0, 0.0, 1.0)
	# [11] 手牌：顶尖捕捉器
	features[offset + 11] = 1.0 if _hand_has(player, PRIME_CATCHER) else 0.0
	# [12] 场上总雷能量
	var total_lightning_on_field: int = 0
	var all_slots: Array[PokemonSlot] = _get_all_slots(player)
	for slot: PokemonSlot in all_slots:
		for e: CardInstance in slot.attached_energy:
			if e != null and e.card_data != null and str(e.card_data.energy_provides) == "L":
				total_lightning_on_field += 1
	features[offset + 12] = clampf(float(total_lightning_on_field) / 10.0, 0.0, 1.0)
	# [13] 铁臂膀ex 能量数
	var iron_hands_energy: int = 0
	for slot: PokemonSlot in all_slots:
		if slot.get_pokemon_name() == IRON_HANDS_EX:
			iron_hands_energy += slot.attached_energy.size()
	features[offset + 13] = clampf(float(iron_hands_energy) / 4.0, 0.0, 1.0)
	# [14] 弃牌堆有攻击手
	features[offset + 14] = 1.0 if _has_attacker_in_discard(game_state, player_index) else 0.0
	# [15] 重力山在场
	features[offset + 15] = 1.0 if _is_gravity_mountain_in_play(game_state) else 0.0


static func _encode_global(game_state: GameState, perspective_player: int, my_player: PlayerState, opp_player: PlayerState, features: Array[float], offset: int) -> void:
	## 全局 8 维
	# [0] 回合
	features[offset + 0] = clampf(float(game_state.turn_number) / 30.0, 0.0, 1.0)
	# [1] 先手
	features[offset + 1] = 1.0 if game_state.first_player_index == perspective_player else 0.0
	# [2] 阶段
	features[offset + 2] = 1.0 if game_state.phase == GameState.GamePhase.MAIN else 0.0
	# [3] 奖赏差
	var prize_diff: float = float(opp_player.prizes.size()) - float(my_player.prizes.size())
	features[offset + 3] = clampf((prize_diff + 6.0) / 12.0, 0.0, 1.0)
	# [4] 对手最弱后备 HP
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
	var min_energy_gap: int = 999
	var iron_hands_energy_count: int = 0

	for slot: PokemonSlot in all_slots:
		var sname: String = slot.get_pokemon_name()
		if sname not in ALL_ATTACKER_NAMES and sname not in NON_RULE_ATTACKER:
			continue
		var dmg: int = _get_best_attack_damage(slot)
		var can_atk: bool = _can_attack(slot)

		if sname == IRON_HANDS_EX:
			iron_hands_energy_count = slot.attached_energy.size()

		if slot == my_player.active_pokemon:
			active_best_dmg = maxi(active_best_dmg, dmg)
			if can_atk and dmg >= opp_active_hp:
				active_can_ko = true
		else:
			bench_best_dmg = maxi(bench_best_dmg, dmg)
			if can_atk and dmg >= opp_active_hp:
				bench_can_ko = true

		var gap: int = _get_energy_gap(slot)
		if gap < min_energy_gap:
			min_energy_gap = gap

	# [0] 前场最优伤害
	features[offset + 0] = clampf(float(active_best_dmg) / 300.0, 0.0, 1.0)
	# [1] 后备最优伤害
	features[offset + 1] = clampf(float(bench_best_dmg) / 300.0, 0.0, 1.0)
	# [2] 前场能 KO
	features[offset + 2] = 1.0 if active_can_ko else 0.0
	# [3] 后备能 KO
	features[offset + 3] = 1.0 if bench_can_ko else 0.0
	# [4] 差几能攻击
	if min_energy_gap < 999:
		features[offset + 4] = clampf(float(min_energy_gap) / 4.0, 0.0, 1.0)
	# [5] 铁臂膀能量数
	features[offset + 5] = clampf(float(iron_hands_energy_count) / 4.0, 0.0, 1.0)
	# [6] 重力山在场
	# (duplicated from resources for attacker context)
	# [7] 保留


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


static func _can_attack(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_top_card() == null:
		return false
	var cd: CardData = slot.get_card_data()
	if cd == null or cd.attacks.is_empty():
		return false
	var attached: int = slot.attached_energy.size()
	for attack: Dictionary in cd.attacks:
		var cost: String = str(attack.get("cost", ""))
		if attached >= cost.length():
			return true
	return false


static func _get_best_attack_damage(slot: PokemonSlot) -> int:
	if slot == null or slot.get_top_card() == null:
		return 0
	var cd: CardData = slot.get_card_data()
	if cd == null or cd.attacks.is_empty():
		return 0
	var best: int = 0
	for attack: Dictionary in cd.attacks:
		var dmg: int = int(str(attack.get("damage", "0")).strip_edges())
		if dmg > best:
			best = dmg
	return best


static func _get_energy_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_top_card() == null:
		return 999
	var cd: CardData = slot.get_card_data()
	if cd == null or cd.attacks.is_empty():
		return 999
	var attached: int = slot.attached_energy.size()
	var min_gap: int = 999
	for attack: Dictionary in cd.attacks:
		var cost: String = str(attack.get("cost", ""))
		var gap: int = maxi(0, cost.length() - attached)
		if gap < min_gap:
			min_gap = gap
	return min_gap


static func _has_attacker_in_discard(game_state: GameState, player_index: int) -> bool:
	if player_index < 0 or player_index >= game_state.players.size():
		return false
	for card: CardInstance in game_state.players[player_index].discard_pile:
		if card != null and card.card_data != null:
			var cname: String = str(card.card_data.name)
			if cname in ALL_ATTACKER_NAMES or cname in NON_RULE_ATTACKER:
				return true
	return false


static func _is_gravity_mountain_in_play(game_state: GameState) -> bool:
	if game_state.stadium_card == null:
		return false
	if game_state.stadium_card.card_data == null:
		return false
	return str(game_state.stadium_card.card_data.name) == GRAVITY_MOUNTAIN
