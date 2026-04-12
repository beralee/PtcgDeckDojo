class_name DragapultCharizardStateEncoder
extends RefCounted

## 多龙巴鲁托/喷火龙卡组专用 100 维特征编码器。
## 接口与 StateEncoder 相同：static func encode(game_state, perspective_player) -> Array[float]

const FEATURE_DIM: int = 100

# 卡牌英文名常量
const DREEPY := "Dreepy"
const DRAKLOAK := "Drakloak"
const DRAGAPULT_EX := "Dragapult ex"
const CHARMANDER := "Charmander"
const CHARMELEON := "Charmeleon"
const CHARIZARD_EX := "Charizard ex"
const ROTOM_V := "Rotom V"
const MANAPHY := "Manaphy"
const RADIANT_ALAKAZAM := "Radiant Alakazam"

# 关键道具/支援者英文名
const RARE_CANDY := "Rare Candy"
const ULTRA_BALL := "Ultra Ball"
const BUDDY_POFFIN := "Buddy-Buddy Poffin"
const ARVEN := "Arven"
const IONO := "Iono"
const BOSSS_ORDERS := "Boss's Orders"
const TM_EVOLUTION := "Technical Machine: Evolution"
const NIGHT_STRETCHER := "Night Stretcher"


static func encode(game_state: GameState, perspective_player: int) -> Array[float]:
	var features: Array[float] = []
	features.resize(FEATURE_DIM)
	features.fill(0.0)

	if game_state == null or perspective_player < 0 or perspective_player >= game_state.players.size():
		return features

	var my_player: PlayerState = game_state.players[perspective_player]
	var opp_player: PlayerState = game_state.players[1 - perspective_player]

	# 通用板面 (x2): 0-19 己方, 20-39 对手
	_encode_board(my_player, game_state, perspective_player, features, 0)
	_encode_board(opp_player, game_state, 1 - perspective_player, features, 20)

	# 卡牌身份 (x2): 40-49 己方, 50-59 对手
	_encode_identity(my_player, features, 40)
	_encode_identity(opp_player, features, 50)

	# 资源 (己方): 60-75
	_encode_resources(my_player, game_state, perspective_player, features, 60)

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
	## 卡牌身份 10 维 — 场上各角色存在/数量
	if player == null:
		return

	var all_slots: Array[PokemonSlot] = _get_all_slots(player)

	# [0] Dreepy 数
	features[offset + 0] = clampf(float(_count_name_en(all_slots, DREEPY)) / 3.0, 0.0, 1.0)
	# [1] Drakloak 数
	features[offset + 1] = clampf(float(_count_name_en(all_slots, DRAKLOAK)) / 3.0, 0.0, 1.0)
	# [2] Dragapult ex 数
	features[offset + 2] = clampf(float(_count_name_en(all_slots, DRAGAPULT_EX)) / 2.0, 0.0, 1.0)
	# [3] Charmander 数
	features[offset + 3] = clampf(float(_count_name_en(all_slots, CHARMANDER)) / 2.0, 0.0, 1.0)
	# [4] Charmeleon 数
	features[offset + 4] = clampf(float(_count_name_en(all_slots, CHARMELEON)) / 1.0, 0.0, 1.0)
	# [5] Charizard ex 数
	features[offset + 5] = clampf(float(_count_name_en(all_slots, CHARIZARD_EX)) / 1.0, 0.0, 1.0)
	# [6] 准备好的攻击手数
	var ready: int = 0
	for slot: PokemonSlot in all_slots:
		if _can_attack(slot):
			var cd: CardData = slot.get_card_data()
			if cd != null and (cd.name_en == DRAGAPULT_EX or cd.name_en == CHARIZARD_EX):
				ready += 1
	features[offset + 6] = clampf(float(ready) / 3.0, 0.0, 1.0)
	# [7] 最佳伤害归一化
	var best_dmg: int = 0
	for slot: PokemonSlot in all_slots:
		var dmg: int = _estimate_max_damage(slot)
		if dmg > best_dmg:
			best_dmg = dmg
	features[offset + 7] = clampf(float(best_dmg) / 300.0, 0.0, 1.0)
	# [8] Dragapult 体系已就绪 (Dragapult ex >= 1)
	features[offset + 8] = 1.0 if _count_name_en(all_slots, DRAGAPULT_EX) >= 1 else 0.0
	# [9] Charizard 体系已就绪 (Charizard ex >= 1)
	features[offset + 9] = 1.0 if _count_name_en(all_slots, CHARIZARD_EX) >= 1 else 0.0


static func _encode_resources(player: PlayerState, game_state: GameState, player_index: int, features: Array[float], offset: int) -> void:
	## 资源 16 维
	if player == null:
		return

	# [0] 手牌有 Rare Candy
	features[offset + 0] = 1.0 if _hand_has_en(player, RARE_CANDY) else 0.0
	# [1] 手牌有 Ultra Ball
	features[offset + 1] = 1.0 if _hand_has_en(player, ULTRA_BALL) else 0.0
	# [2] 手牌有 Buddy-Buddy Poffin
	features[offset + 2] = 1.0 if _hand_has_en(player, BUDDY_POFFIN) else 0.0
	# [3] 手牌有 Arven
	features[offset + 3] = 1.0 if _hand_has_en(player, ARVEN) else 0.0
	# [4] 手牌有 Iono
	features[offset + 4] = 1.0 if _hand_has_en(player, IONO) else 0.0
	# [5] 手牌有 Boss's Orders
	features[offset + 5] = 1.0 if _hand_has_en(player, BOSSS_ORDERS) else 0.0
	# [6] 手牌有 TM Evolution
	features[offset + 6] = 1.0 if _hand_has_en(player, TM_EVOLUTION) else 0.0
	# [7] 手牌超能量数
	var psychic_hand: int = _count_energy_in_hand(player, "P")
	features[offset + 7] = clampf(float(psychic_hand) / 4.0, 0.0, 1.0)
	# [8] 手牌火能量数
	var fire_hand: int = _count_energy_in_hand(player, "R")
	features[offset + 8] = clampf(float(fire_hand) / 4.0, 0.0, 1.0)
	# [9] 牌库超能量数
	var deck_psychic: int = _count_energy_type_in_deck(player, "P")
	features[offset + 9] = clampf(float(deck_psychic) / 10.0, 0.0, 1.0)
	# [10] 牌库火能量数
	var deck_fire: int = _count_energy_type_in_deck(player, "R")
	features[offset + 10] = clampf(float(deck_fire) / 10.0, 0.0, 1.0)
	# [11] 场上总能量数
	var field_energy: int = _count_field_energy(player)
	features[offset + 11] = clampf(float(field_energy) / 10.0, 0.0, 1.0)
	# [12] 空板位数
	features[offset + 12] = clampf(float(maxi(0, 5 - player.bench.size())) / 5.0, 0.0, 1.0)
	# [13] 弃牌堆有核心进化棋子
	features[offset + 13] = 1.0 if _has_in_discard_names_en(game_state, player_index, [DRAKLOAK, DRAGAPULT_EX, CHARMELEON, CHARIZARD_EX]) else 0.0
	# [14] 手牌有 Night Stretcher
	features[offset + 14] = 1.0 if _hand_has_en(player, NIGHT_STRETCHER) else 0.0
	# [15] 保留
	features[offset + 15] = 0.0


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

	for slot: PokemonSlot in all_slots:
		var dmg: int = _estimate_max_damage(slot)
		if slot == my_player.active_pokemon:
			active_best_dmg = maxi(active_best_dmg, dmg)
			if dmg >= opp_active_hp:
				active_can_ko = true
		else:
			bench_best_dmg = maxi(bench_best_dmg, dmg)
			if dmg >= opp_active_hp:
				bench_can_ko = true

	# [0] 前场最优伤害
	features[offset + 0] = clampf(float(active_best_dmg) / 300.0, 0.0, 1.0)
	# [1] 后备最优伤害
	features[offset + 1] = clampf(float(bench_best_dmg) / 300.0, 0.0, 1.0)
	# [2] 前场能 KO
	features[offset + 2] = 1.0 if active_can_ko else 0.0
	# [3] 后备能 KO
	features[offset + 3] = 1.0 if bench_can_ko else 0.0
	# [4] 幻影俯冲可收割（对手后备有低 HP 目标，Phantom Dive 附带效果可击杀）
	var phantom_pickoff: bool = false
	for opp_slot: PokemonSlot in opp_player.bench:
		if opp_slot == null:
			continue
		if opp_slot.get_remaining_hp() <= 60:
			phantom_pickoff = true
			break
	features[offset + 4] = 1.0 if phantom_pickoff else 0.0
	# [5] Dragapult ex 攻击能量缺口
	var drag_gap: int = _attack_energy_gap(my_player, DRAGAPULT_EX)
	features[offset + 5] = clampf(float(drag_gap) / 3.0, 0.0, 1.0)
	# [6] Charizard ex 攻击能量缺口
	var zard_gap: int = _attack_energy_gap(my_player, CHARIZARD_EX)
	features[offset + 6] = clampf(float(zard_gap) / 4.0, 0.0, 1.0)
	# [7] 对手后备有低 HP 目标 (< 60)
	var opp_bench_low: bool = false
	for opp_slot: PokemonSlot in opp_player.bench:
		if opp_slot == null:
			continue
		if opp_slot.get_remaining_hp() < 60:
			opp_bench_low = true
			break
	features[offset + 7] = 1.0 if opp_bench_low else 0.0


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


static func _count_name_en(slots: Array[PokemonSlot], name_en: String) -> int:
	var count: int = 0
	for slot: PokemonSlot in slots:
		var cd: CardData = slot.get_card_data()
		if cd != null and cd.name_en == name_en:
			count += 1
	return count


static func _hand_has_en(player: PlayerState, card_name_en: String) -> bool:
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.name_en == card_name_en:
			return true
	return false


static func _count_energy_in_hand(player: PlayerState, etype: String) -> int:
	var count: int = 0
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.is_energy() and str(card.card_data.energy_provides) == etype:
			count += 1
	return count


static func _count_energy_type_in_deck(player: PlayerState, etype: String) -> int:
	var count: int = 0
	for card: CardInstance in player.deck:
		if card != null and card.card_data != null and card.card_data.is_energy() and str(card.card_data.energy_provides) == etype:
			count += 1
	return count


static func _count_field_energy(player: PlayerState) -> int:
	var total: int = 0
	var all_slots: Array[PokemonSlot] = _get_all_slots(player)
	for slot: PokemonSlot in all_slots:
		total += slot.attached_energy.size()
	return total


static func _has_in_discard_names_en(game_state: GameState, player_index: int, names: Array) -> bool:
	if player_index < 0 or player_index >= game_state.players.size():
		return false
	for card: CardInstance in game_state.players[player_index].discard_pile:
		if card != null and card.card_data != null and card.card_data.name_en in names:
			return true
	return false


static func _estimate_max_damage(slot: PokemonSlot) -> int:
	## 粗略估算该宝可梦最大伤害（取招式中 damage 最高值）
	if slot == null or slot.get_top_card() == null:
		return 0
	var cd: CardData = slot.get_card_data()
	if cd == null or cd.attacks.is_empty():
		return 0
	var best: int = 0
	for attack: Dictionary in cd.attacks:
		var dmg: int = int(attack.get("damage", 0))
		if dmg > best:
			best = dmg
	return best


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


static func _attack_energy_gap(player: PlayerState, name_en: String) -> int:
	## 计算指定宝可梦攻击所需能量缺口（取最小缺口）
	var all_slots: Array[PokemonSlot] = _get_all_slots(player)
	var min_gap: int = 99
	for slot: PokemonSlot in all_slots:
		var cd: CardData = slot.get_card_data()
		if cd == null or cd.name_en != name_en:
			continue
		var attached: int = slot.attached_energy.size()
		for attack: Dictionary in cd.attacks:
			var cost: String = str(attack.get("cost", ""))
			var gap: int = maxi(0, cost.length() - attached)
			if gap < min_gap:
				min_gap = gap
	return min_gap if min_gap < 99 else 0
