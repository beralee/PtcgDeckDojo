## 沙奈朵卡组 AI 策略单元测试
class_name TestGardevoirStrategy
extends TestBase

const DeckStrategyGardevoirScript = preload("res://scripts/ai/DeckStrategyGardevoir.gd")
const AIHeuristicsScript = preload("res://scripts/ai/AIHeuristics.gd")


func _new_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	return DeckStrategyGardevoirScript.new()


# -- 辅助函数 --

func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "P",
	hp: int = 100,
	evolves_from: String = "",
	mechanic: String = "",
	abilities: Array = [],
	attacks: Array = []
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	cd.evolves_from = evolves_from
	cd.mechanic = mechanic
	cd.abilities.clear()
	for ability: Dictionary in abilities:
		cd.abilities.append(ability.duplicate(true))
	cd.attacks.clear()
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _make_energy_cd(pname: String, energy_provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy_provides
	return cd


func _make_trainer_cd(pname: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = card_type
	return cd


func _make_tool_cd(pname: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Tool"
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _make_player(pi: int = 0) -> PlayerState:
	var p := PlayerState.new()
	p.player_index = pi
	return p


func _make_game_state(turn: int = 2) -> GameState:
	var gs := GameState.new()
	gs.turn_number = turn
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var p := _make_player(pi)
		p.active_pokemon = _make_slot(_make_pokemon_cd("Active%d" % pi), pi)
		gs.players.append(p)
	return gs


func _ctx(gs: GameState, pi: int = 0) -> Dictionary:
	return {"game_state": gs, "player_index": pi}


# ============================================================
#  开局规划测试
# ============================================================

func test_setup_prefers_ralts_over_random_basic() -> String:
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Pidgey", "Basic", "C"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("拉鲁拉丝"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Shinx", "Basic", "L"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Potion"), 0))
	var s := _new_strategy()
	var choice: Dictionary = s.plan_opening_setup(player)
	return assert_eq(int(choice.get("active_hand_index", -1)), 1, "拉鲁拉丝应被优先选为前场")


func test_setup_prefers_klefki_active_with_multiple_ralts() -> String:
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("拉鲁拉丝"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("拉鲁拉丝"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("钥圈儿", "Basic", "Y"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝"), 0))
	var s := _new_strategy()
	var choice: Dictionary = s.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name: String = str(player.hand[active_idx].card_data.name) if active_idx >= 0 else ""
	var bench_indices: Array = choice.get("bench_hand_indices", [])
	return run_checks([
		assert_eq(active_name, "钥圈儿", "有 2 只拉鲁拉丝时应选钥圈儿前场"),
		assert_true(bench_indices.size() >= 2, "后备区应至少有 2 张卡"),
	])


func test_setup_drifloon_active_with_single_ralts() -> String:
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("拉鲁拉丝"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("飘飘球", "Basic", "P"), 0))
	var s := _new_strategy()
	var choice: Dictionary = s.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name: String = str(player.hand[active_idx].card_data.name) if active_idx >= 0 else ""
	return assert_eq(active_name, "飘飘球", "单拉鲁拉丝时应选飘飘球前场保护拉鲁拉丝")


func test_flutter_mane_preferred_active_in_opening() -> String:
	## 开局振翼发优先上前场
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("拉鲁拉丝"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("振翼发", "Basic", "P", 90), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("飘飘球", "Basic", "P"), 0))
	var s := _new_strategy()
	var choice: Dictionary = s.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name: String = str(player.hand[active_idx].card_data.name) if active_idx >= 0 else ""
	return assert_eq(active_name, "振翼发", "有振翼发时应优先上前场")


# ============================================================
#  动作评分测试
# ============================================================

func test_score_evolve_kirlia_higher_than_generic() -> String:
	var gs := _make_game_state()
	var s := _new_strategy()
	var kirlia_cd := _make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝")
	var generic_cd := _make_pokemon_cd("Pidgeotto", "Stage 1", "C", 80, "Pidgey")
	var score_kirlia: float = s.score_action({"kind": "evolve", "card": CardInstance.create(kirlia_cd, 0)}, _ctx(gs))
	var score_generic: float = s.score_action({"kind": "evolve", "card": CardInstance.create(generic_cd, 0)}, _ctx(gs))
	return run_checks([
		assert_true(score_kirlia > score_generic, "奇鲁莉安进化分 (%f) 应高于通用进化 (%f)" % [score_kirlia, score_generic]),
		assert_true(score_kirlia >= 150.0, "奇鲁莉安进化分应 >= 150 (got %f)" % score_kirlia),
	])


func test_score_evolve_gardevoir_ex_highest() -> String:
	var gs := _make_game_state()
	var s := _new_strategy()
	var gardevoir_cd := _make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex")
	var kirlia_cd := _make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝")
	var score_gard: float = s.score_action({"kind": "evolve", "card": CardInstance.create(gardevoir_cd, 0)}, _ctx(gs))
	var score_kirlia: float = s.score_action({"kind": "evolve", "card": CardInstance.create(kirlia_cd, 0)}, _ctx(gs))
	return run_checks([
		assert_true(score_gard >= 300.0, "首只沙奈朵ex进化分应 >= 300 (got %f)" % score_gard),
		assert_true(score_gard > score_kirlia, "沙奈朵ex进化分应高于奇鲁莉安"),
	])


func test_score_psychic_embrace_respects_empty_discard() -> String:
	var gs := _make_game_state(4)
	var gardevoir_cd := _make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex",
		[{"name": "精神拥抱", "text": "test"}])
	gs.players[0].active_pokemon = _make_slot(gardevoir_cd, 0)
	var s := _new_strategy()
	var score: float = s.score_action({
		"kind": "use_ability",
		"source_slot": gs.players[0].active_pokemon,
		"ability_index": 0,
	}, _ctx(gs))
	return assert_true(score < 0.0, "弃牌堆无超能量时 Psychic Embrace delta 应为负分 (got %f)" % score)


func test_score_psychic_embrace_with_discard_fuel() -> String:
	var gs := _make_game_state(4)
	var player := gs.players[0]
	for i: int in 3:
		player.discard_pile.append(CardInstance.create(_make_energy_cd("超能量", "P"), 0))
	var gardevoir_cd := _make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex",
		[{"name": "精神拥抱", "text": "test"}])
	player.active_pokemon = _make_slot(gardevoir_cd, 0)
	var s := _new_strategy()
	var score: float = s.score_action({
		"kind": "use_ability",
		"source_slot": player.active_pokemon,
		"ability_index": 0,
	}, _ctx(gs))
	# 有燃料但无好目标时 delta 可能不高；关键是比无燃料时高
	return assert_true(score > -210.0, "弃牌堆有超能量时 Psychic Embrace delta 应高于无燃料 (got %f)" % score)


func test_score_munkidori_only_when_ko_possible() -> String:
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var munki_cd := _make_pokemon_cd("愿增猿", "Basic", "D", 110, "", "",
		[{"name": "Adrenaline Poisoning", "text": "test"}])
	var munki_slot := _make_slot(munki_cd, 0)
	munki_slot.damage_counters = 30
	player.bench.append(munki_slot)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Defender", "Basic", "C", 200), 1)
	var s := _new_strategy()
	var action := {"kind": "use_ability", "source_slot": munki_slot, "ability_index": 0}
	var score_no_ko: float = s.score_action(action, _ctx(gs))
	gs.players[1].active_pokemon.damage_counters = 190
	var score_ko: float = s.score_action(action, _ctx(gs))
	return assert_true(score_ko > score_no_ko, "能凑 KO 时分数 (%f) 应高于不能时 (%f)" % [score_ko, score_no_ko])


func test_refinement_scored_high_with_hand_cards() -> String:
	## 精炼特性在手牌多时应高分（A 段）
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var kirlia_cd := _make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝", "",
		[{"name": "精炼", "text": "弃1抽2"}])
	var kirlia_slot := _make_slot(kirlia_cd, 0)
	player.bench.append(kirlia_slot)
	# 手里有多余卡牌
	player.hand.append(CardInstance.create(_make_pokemon_cd("玛纳霏", "Basic", "W"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("超能量", "P"), 0))
	player.hand.append(CardInstance.create(_make_tool_cd("招式学习器 进化"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": kirlia_slot, "ability_index": 0},
		gs, 0
	)
	return assert_true(score >= 350.0,
		"精炼在手牌多时应高分 (got %f)" % score)


func test_concealed_cards_high_with_psychic_energy_in_hand() -> String:
	## 隐藏牌（光辉甲贺忍蛙）有超能量时应高分
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var greninja_cd := _make_pokemon_cd("光辉甲贺忍蛙", "Basic", "W", 120, "", "",
		[{"name": "隐藏牌", "text": "弃1能量抽2"}])
	var greninja_slot := _make_slot(greninja_cd, 0)
	player.bench.append(greninja_slot)
	player.hand.append(CardInstance.create(_make_energy_cd("超能量", "P"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": greninja_slot, "ability_index": 0},
		gs, 0
	)
	return assert_true(score >= 400.0,
		"隐藏牌有超能量时应在 A 段 (got %f)" % score)


# ============================================================
#  弃牌优先级测试
# ============================================================

func test_discard_priority_psychic_energy_highest() -> String:
	var s := _new_strategy()
	var score_psychic: int = s.get_discard_priority(CardInstance.create(_make_energy_cd("超能量", "P"), 0))
	var score_dark: int = s.get_discard_priority(CardInstance.create(_make_energy_cd("恶能量", "D"), 0))
	var score_item: int = s.get_discard_priority(CardInstance.create(_make_trainer_cd("Potion"), 0))
	var score_gard: int = s.get_discard_priority(CardInstance.create(_make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex"), 0))
	return run_checks([
		assert_true(score_psychic > score_dark, "超能量弃牌优先级应高于恶能量"),
		assert_true(score_dark > score_item, "恶能量弃牌优先级应高于道具"),
		assert_true(score_item > score_gard, "道具弃牌优先级应高于核心卡沙奈朵ex"),
		assert_eq(score_psychic, 250, "超能量弃牌优先级应为 250"),
	])


func test_refinement_discard_prefers_psychic_energy() -> String:
	## 精炼优先弃超能量（场面感知版）
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.bench.append(_make_slot(_make_pokemon_cd("拉鲁拉丝"), 0))
	var s := _new_strategy()
	var psychic := CardInstance.create(_make_energy_cd("超能量", "P"), 0)
	var dark := CardInstance.create(_make_energy_cd("恶能量", "D"), 0)
	var poffin := CardInstance.create(_make_trainer_cd("友好宝芬"), 0)
	var score_p: int = s.get_discard_priority_contextual(psychic, gs, 0)
	var score_d: int = s.get_discard_priority_contextual(dark, gs, 0)
	var score_poffin: int = s.get_discard_priority_contextual(poffin, gs, 0)
	return run_checks([
		assert_true(score_p > score_d, "超能量弃牌优先级应高于恶能量 (P=%d, D=%d)" % [score_p, score_d]),
		assert_true(score_p > score_poffin, "超能量弃牌优先级应高于宝芬 (P=%d, poffin=%d)" % [score_p, score_poffin]),
	])


func test_refinement_discard_deprioritizes_poffin_when_bench_full() -> String:
	## 满板时宝芬降低优先级
	var gs := _make_game_state(3)
	var player := gs.players[0]
	# 填满后备区（5 个）
	for i: int in 5:
		player.bench.append(_make_slot(_make_pokemon_cd("拉鲁拉丝"), 0))
	var s := _new_strategy()
	var poffin := CardInstance.create(_make_trainer_cd("友好宝芬"), 0)
	var score_full: int = s.get_discard_priority_contextual(poffin, gs, 0)
	# 清空后备区
	player.bench.clear()
	var score_empty: int = s.get_discard_priority_contextual(poffin, gs, 0)
	return assert_true(score_full > score_empty,
		"满板时宝芬弃牌优先级 (%d) 应高于空板时 (%d)" % [score_full, score_empty])


# ============================================================
#  早期铺板 + 贴能测试
# ============================================================

func test_early_game_prioritizes_bench_development() -> String:
	var gs := _make_game_state(1)
	var s := _new_strategy()
	var score_ralts: float = s.score_action({"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("拉鲁拉丝"), 0)}, _ctx(gs))
	var score_pidgey: float = s.score_action({"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Pidgey", "Basic", "C"), 0)}, _ctx(gs))
	return run_checks([
		assert_true(score_ralts > score_pidgey, "早期拉鲁拉丝上板分 (%f) 应高于 Pidgey (%f)" % [score_ralts, score_pidgey]),
		assert_true(score_ralts >= 150.0, "早期拉鲁拉丝上板 delta 应 >= 150 (got %f)" % score_ralts),
	])


func test_attach_dark_energy_only_to_munkidori() -> String:
	## 恶能量唯一目标是愿增猿，给辅助型负分
	var gs := _make_game_state(4)
	var munki_cd := _make_pokemon_cd("愿增猿", "Basic", "D", 110, "", "", [], [{"name": "Poison", "cost": "DC", "damage": "40"}])
	var munki_slot := _make_slot(munki_cd, 0)
	var mana_slot := _make_slot(_make_pokemon_cd("玛纳霏", "Basic", "W", 70, "", "", [{"name": "Wave Veil", "text": "test"}]), 0)
	var ralts_slot := _make_slot(_make_pokemon_cd("拉鲁拉丝"), 0)
	gs.players[0].active_pokemon = ralts_slot
	gs.players[0].bench.append(munki_slot)
	gs.players[0].bench.append(mana_slot)
	var s := _new_strategy()
	var dark := CardInstance.create(_make_energy_cd("恶能量", "D"), 0)
	var score_munki: float = s.score_action({"kind": "attach_energy", "card": dark, "target_slot": munki_slot}, _ctx(gs))
	var score_mana: float = s.score_action({"kind": "attach_energy", "card": dark, "target_slot": mana_slot}, _ctx(gs))
	var score_ralts: float = s.score_action({"kind": "attach_energy", "card": dark, "target_slot": ralts_slot}, _ctx(gs))
	return run_checks([
		assert_true(score_munki > 0.0, "恶能量给愿增猿应正分 (got %f)" % score_munki),
		assert_true(score_mana < 0.0, "恶能量给玛纳霏应负分 (got %f)" % score_mana),
		assert_true(score_ralts < 0.0, "恶能量给拉鲁拉丝应负分 (got %f)" % score_ralts),
	])


func test_attach_psychic_energy_always_negative() -> String:
	## 超能量永远不手贴，无论目标是谁
	var gs := _make_game_state(4)
	var drifloon_slot := _make_slot(_make_pokemon_cd("飘飘球", "Basic", "P", 70, "", "", [], [{"name": "Spin", "cost": "PC", "damage": "30"}]), 0)
	var klefki_slot := _make_slot(_make_pokemon_cd("钥圈儿", "Basic", "Y", 70), 0)
	gs.players[0].active_pokemon = drifloon_slot
	gs.players[0].bench.append(klefki_slot)
	var s := _new_strategy()
	var psychic := CardInstance.create(_make_energy_cd("超能量", "P"), 0)
	var score_drifloon: float = s.score_action({"kind": "attach_energy", "card": psychic, "target_slot": drifloon_slot}, _ctx(gs))
	var score_klefki: float = s.score_action({"kind": "attach_energy", "card": psychic, "target_slot": klefki_slot}, _ctx(gs))
	return run_checks([
		assert_true(score_drifloon < -200.0, "超能量给飘飘球应大负分 (got %f)" % score_drifloon),
		assert_true(score_klefki < -200.0, "超能量给钥圈儿应大负分 (got %f)" % score_klefki),
	])


func test_psychic_energy_never_hand_attach() -> String:
	## 超能量永不手贴 — 无论目标是谁
	var gs := _make_game_state(4)
	var drifloon_cd := _make_pokemon_cd("飘飘球", "Basic", "P", 70, "", "", [], [{"name": "Spin", "cost": "PC", "damage": "30"}])
	var drifloon_slot := _make_slot(drifloon_cd, 0)
	var gard_cd := _make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex")
	var gard_slot := _make_slot(gard_cd, 0)
	gs.players[0].active_pokemon = drifloon_slot
	gs.players[0].bench.append(gard_slot)
	var s := _new_strategy()
	var psychic := CardInstance.create(_make_energy_cd("超能量", "P"), 0)
	var score_drifloon: float = s.score_action({"kind": "attach_energy", "card": psychic, "target_slot": drifloon_slot}, _ctx(gs))
	var score_gard: float = s.score_action({"kind": "attach_energy", "card": psychic, "target_slot": gard_slot}, _ctx(gs))
	return run_checks([
		assert_true(score_drifloon < -200.0, "超能量手贴给飘飘球应大负分 (got %f)" % score_drifloon),
		assert_true(score_gard < -200.0, "超能量手贴给沙奈朵应大负分 (got %f)" % score_gard),
	])


# ============================================================
#  训练师评分测试
# ============================================================

func test_trainer_earthen_vessel_high_mid_game() -> String:
	var gs := _make_game_state(3)
	# 手里有超能量时大地容器价值更高（弃超能 = Embrace 燃料）
	gs.players[0].hand.append(CardInstance.create(_make_energy_cd("超能量", "P"), 0))
	var s := _new_strategy()
	var score_vessel: float = s.score_action({"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("大地容器"), 0)}, _ctx(gs))
	var score_potion: float = s.score_action({"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Potion"), 0)}, _ctx(gs))
	return run_checks([
		assert_true(score_vessel > score_potion, "大地容器中期分 (%f) 应高于 Potion (%f)" % [score_vessel, score_potion]),
		assert_true(score_vessel >= 150.0, "大地容器中期 delta 应 >= 150 (got %f)" % score_vessel),
	])


func test_rare_candy_with_ralts_and_gardevoir_in_hand() -> String:
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.bench.append(_make_slot(_make_pokemon_cd("拉鲁拉丝"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex"), 0))
	var s := _new_strategy()
	var score: float = s.score_action({"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Rare Candy"), 0)}, _ctx(gs))
	return assert_true(score >= 300.0, "Rare Candy + 拉鲁拉丝 + 沙奈朵ex应得极高分 (got %f)" % score)


func test_boss_orders_high_when_can_ko_bench_target() -> String:
	## 能击倒后备时老大指令应在 S 段
	var gs := _make_game_state(5)
	var player := gs.players[0]
	# 攻击手在前场，有攻击能力
	var drifloon_cd := _make_pokemon_cd("飘飘球", "Basic", "P", 70, "", "", [],
		[{"name": "气球炸弹", "cost": "PP", "damage": "60"}])
	var drifloon_slot := _make_slot(drifloon_cd, 0)
	drifloon_slot.damage_counters = 40
	drifloon_slot.attached_energy.append(CardInstance.create(_make_energy_cd("超能量", "P"), 0))
	drifloon_slot.attached_energy.append(CardInstance.create(_make_energy_cd("超能量", "P"), 0))
	player.active_pokemon = drifloon_slot
	# 对手后备有低 HP 目标
	gs.players[1].bench.append(_make_slot(_make_pokemon_cd("弱小目标", "Basic", "C", 40), 1))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("老大的指令", "Supporter"), 0)},
		gs, 0
	)
	return assert_true(score >= 800.0,
		"能击倒后备弱目标时老大指令应在 S 段 (got %f)" % score)


func test_arven_high_when_deck_has_ultra_ball_and_need_gardevoir() -> String:
	## 派帕决策链：牌库有高级球 + 场上有奇鲁莉安 + 无沙奈朵 → 高分
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.bench.append(_make_slot(_make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝"), 0))
	# 牌库放入高级球
	var ultra_ball_cd := _make_trainer_cd("高级球")
	player.deck.append(CardInstance.create(ultra_ball_cd, 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("派帕", "Supporter"), 0)},
		gs, 0
	)
	return assert_true(score >= 250.0,
		"派帕能找高级球启动引擎时应高分 (got %f)" % score)


func test_arven_picks_ultra_ball_when_need_gardevoir() -> String:
	## 派帕搜索目标选择：需要沙奈朵时优先找高级球
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.bench.append(_make_slot(_make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝"), 0))
	var ultra_ball := CardInstance.create(_make_trainer_cd("高级球"), 0)
	var potion := CardInstance.create(_make_trainer_cd("Potion"), 0)
	var nest_ball := CardInstance.create(_make_trainer_cd("巢穴球"), 0)
	var items: Array = [potion, nest_ball, ultra_ball]
	var s := _new_strategy()
	var picked: Variant = s.pick_search_item(items, gs, 0)
	var picked_name: String = ""
	if picked is CardInstance:
		picked_name = str((picked as CardInstance).card_data.name)
	return assert_eq(picked_name, "高级球", "需要沙奈朵时派帕应优先找高级球")


func test_second_gardevoir_evolve_low_when_losing_last_kirlia() -> String:
	## 第二只沙奈朵进化会失去最后一只奇鲁莉安时应低分
	var gs := _make_game_state(5)
	var player := gs.players[0]
	# 场上已有 1 只沙奈朵ex
	player.bench.append(_make_slot(_make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex"), 0))
	# 只有 1 只奇鲁莉安（进化后就没了）
	var kirlia_slot := _make_slot(_make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝"), 0)
	player.bench.append(kirlia_slot)
	var s := _new_strategy()
	var gard_cd := _make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex")
	var score: float = s.score_action_absolute(
		{"kind": "evolve", "card": CardInstance.create(gard_cd, 0)}, gs, 0)
	return assert_true(score <= 150.0,
		"失去最后一只奇鲁莉安时第二只沙奈朵分应低 (got %f)" % score)


# ============================================================
#  检索偏好测试
# ============================================================

func test_search_priority_ralts_highest() -> String:
	var s := _new_strategy()
	var score_ralts: int = s.get_search_priority(CardInstance.create(_make_pokemon_cd("拉鲁拉丝"), 0))
	var score_pidgey: int = s.get_search_priority(CardInstance.create(_make_pokemon_cd("Pidgey", "Basic", "C"), 0))
	var score_kirlia: int = s.get_search_priority(CardInstance.create(_make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝"), 0))
	return run_checks([
		assert_true(score_ralts > score_kirlia, "拉鲁拉丝检索优先级应高于奇鲁莉安"),
		assert_true(score_kirlia > score_pidgey, "奇鲁莉安检索优先级应高于 Pidgey"),
	])


# ============================================================
#  AIHeuristics 集成测试
# ============================================================

func test_heuristics_delegates_gardevoir_bias() -> String:
	CardInstance.reset_id_counter()
	var heuristics := AIHeuristicsScript.new()
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.hand.append(CardInstance.create(_make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝"), 0))
	var action := {
		"kind": "evolve",
		"card": CardInstance.create(_make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝"), 0),
		"reason_tags": [],
	}
	var ctx := {"gsm": null, "game_state": gs, "player_index": 0, "features": {}}
	var score: float = heuristics.score_action(action, ctx)
	return assert_true(score >= 300.0, "Heuristics 应委托策略类给出高分 (got %f)" % score)


# ============================================================
#  绝对分评估 + Combo 测试
# ============================================================

func test_score_action_absolute_gardevoir_evolve_s_tier() -> String:
	## 首只沙奈朵ex进化应该在 S 段（800+）
	var gs := _make_game_state(4)
	var s := _new_strategy()
	var gard_cd := _make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex")
	var score: float = s.score_action_absolute(
		{"kind": "evolve", "card": CardInstance.create(gard_cd, 0)},
		gs, 0
	)
	return assert_true(score >= 800.0, "首只沙奈朵ex进化绝对分应 >= 800 (got %f)" % score)


func test_combo_refinement_boosts_embrace() -> String:
	## Combo: 弃牌堆加速 — 弃牌堆有超能量时 Embrace 分数应高于无燃料时
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var gardevoir_cd := _make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex",
		[{"name": "精神拥抱", "text": "test"}])
	var gard_slot := _make_slot(gardevoir_cd, 0)
	player.active_pokemon = gard_slot
	# 添加一个攻击手到后备（Embrace 的贴能目标）
	var drifloon_cd := _make_pokemon_cd("飘飘球", "Basic", "P", 70, "", "", [],
		[{"name": "Balloon Bomb", "cost": "PP", "damage": "0"}])
	var drifloon_slot := _make_slot(drifloon_cd, 0)
	player.bench.append(drifloon_slot)
	var s := _new_strategy()
	var action := {"kind": "use_ability", "source_slot": gard_slot, "ability_index": 0}
	# 无燃料
	var score_no_fuel: float = s.score_action_absolute(action, gs, 0)
	# 添加弃牌堆超能量（模拟 Refinement 弃了超能量）
	for i: int in 3:
		player.discard_pile.append(CardInstance.create(_make_energy_cd("超能量", "P"), 0))
	var score_with_fuel: float = s.score_action_absolute(action, gs, 0)
	return run_checks([
		assert_true(score_with_fuel > score_no_fuel,
			"弃牌堆有燃料时 Embrace 绝对分 (%f) 应高于无燃料时 (%f)" % [score_with_fuel, score_no_fuel]),
		assert_true(score_with_fuel >= 250.0,
			"有攻击手 + 燃料时 Embrace 应高分 (got %f)" % score_with_fuel),
	])


func test_combo_embrace_enables_attack() -> String:
	## Combo: Embrace 给攻击手贴能后 attack 分数应在正区间
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var drifloon_cd := _make_pokemon_cd("飘飘球", "Basic", "P", 70, "", "", [],
		[{"name": "Balloon Bomb", "cost": "PP", "damage": "0"}])
	var drifloon_slot := _make_slot(drifloon_cd, 0)
	# 模拟 Embrace 已贴了 2 个能量 + 伤害指示物
	drifloon_slot.damage_counters = 40
	drifloon_slot.attached_energy.append(CardInstance.create(_make_energy_cd("超能量", "P"), 0))
	drifloon_slot.attached_energy.append(CardInstance.create(_make_energy_cd("超能量", "P"), 0))
	player.active_pokemon = drifloon_slot
	# 对手
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Defender", "Basic", "C", 100), 1)
	var s := _new_strategy()
	var attack_action := {"kind": "attack", "attack_index": 0, "projected_damage": 120}
	var score: float = s.score_action_absolute(attack_action, gs, 0)
	return assert_true(score >= 800.0,
		"Embrace 后能击倒对手时 attack 应在 S 段 (got %f)" % score)


func test_negative_action_blocked() -> String:
	## 超能量手贴、能量给错目标应该分数 ≤ 0
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var ralts_slot := _make_slot(_make_pokemon_cd("拉鲁拉丝"), 0)
	var klefki_slot := _make_slot(_make_pokemon_cd("钥圈儿", "Basic", "Y", 70), 0)
	player.active_pokemon = ralts_slot
	player.bench.append(klefki_slot)
	var s := _new_strategy()
	var psychic := CardInstance.create(_make_energy_cd("超能量", "P"), 0)
	var dark := CardInstance.create(_make_energy_cd("恶能量", "D"), 0)
	var score_psychic_ralts: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": psychic, "target_slot": ralts_slot}, gs, 0)
	var score_dark_klefki: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": dark, "target_slot": klefki_slot}, gs, 0)
	return run_checks([
		assert_true(score_psychic_ralts <= 0.0,
			"超能量手贴给拉鲁拉丝绝对分应 <= 0 (got %f)" % score_psychic_ralts),
		assert_true(score_dark_klefki <= 0.0,
			"恶能量给钥圈儿绝对分应 <= 0 (got %f)" % score_dark_klefki),
	])


# ============================================================
#  TM Evolution 道具赋予招式测试
# ============================================================

func test_tm_evolution_tool_scored_high_with_bench_ralts() -> String:
	## TM Evolution 在有可进化后备拉鲁拉丝 + 前场有/可贴能量时高分
	var gs := _make_game_state(2)
	var player := gs.players[0]
	# 前场振翼发（控制型），已有1个能量（可支付进化招式费用 C）
	var flutter_slot := _make_slot(_make_pokemon_cd("振翼发", "Basic", "P", 90), 0)
	flutter_slot.attached_energy.append(CardInstance.create(_make_energy_cd("恶能量", "D"), 0))
	player.active_pokemon = flutter_slot
	# 后备拉鲁拉丝（可进化目标）
	player.bench.append(_make_slot(_make_pokemon_cd("拉鲁拉丝"), 0))
	var s := _new_strategy()
	var tm_card := CardInstance.create(_make_tool_cd("招式学习器 进化"), 0)
	var score_active: float = s.score_action_absolute(
		{"kind": "attach_tool", "card": tm_card, "target_slot": flutter_slot},
		gs, 0
	)
	# 贴给后备应负分
	var bench_slot: PokemonSlot = player.bench[0]
	var score_bench: float = s.score_action_absolute(
		{"kind": "attach_tool", "card": tm_card, "target_slot": bench_slot},
		gs, 0
	)
	return run_checks([
		assert_true(score_active >= 500.0,
			"TM Evolution 贴给前场 + 有能量 + 有可进化后备时应 >= 500 (got %f)" % score_active),
		assert_true(score_bench < 0.0,
			"TM Evolution 贴给后备应负分 (got %f)" % score_bench),
	])


func test_granted_attack_tm_evolution_high_with_targets() -> String:
	## TM Evolution 进化招式在有可进化后备时 A 段
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("振翼发", "Basic", "P", 90), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("拉鲁拉丝"), 0))
	var s := _new_strategy()
	var action := {
		"kind": "granted_attack",
		"granted_attack_data": {"name": "进化", "cost": "", "damage": 0},
		"attack_index": -1,
		"source_slot": player.active_pokemon,
	}
	var score: float = s.score_action_absolute(action, gs, 0)
	return assert_true(score >= 600.0,
		"TM Evolution 进化招式在有可进化后备时应 >= 600 (got %f)" % score)


# ============================================================
#  MCTS + 策略评估测试
# ============================================================

func test_mcts_evaluate_board_used_over_rollout() -> String:
	## MCTSPlanner 有 deck_strategy 时应用 evaluate_board 而非 rollout
	var s := _new_strategy()
	var planner := preload("res://scripts/ai/MCTSPlanner.gd").new()
	planner.deck_strategy = s
	# 构造一个简单 GameState
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.bench.append(_make_slot(_make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex"), 0))
	# evaluate_board 应返回正值（场上有沙奈朵ex引擎）
	var raw: float = s.evaluate_board(gs, 0)
	# 归一化后应在 (0, 1)
	var normalized: float = clampf((raw + 2000.0) / 6000.0, 0.0, 1.0)
	return run_checks([
		assert_true(raw > 0.0, "有沙奈朵ex引擎时 evaluate_board 应正值 (got %f)" % raw),
		assert_true(normalized > 0.3, "归一化后应 > 0.3 (got %f)" % normalized),
		assert_true(normalized < 1.0, "归一化后应 < 1.0 (got %f)" % normalized),
	])


func test_get_mcts_config_returns_valid_config() -> String:
	## get_mcts_config 应返回有效配置字典
	var s := _new_strategy()
	var config: Dictionary = s.get_mcts_config()
	return run_checks([
		assert_true(config.has("branch_factor"), "应包含 branch_factor"),
		assert_true(config.has("time_budget_ms"), "应包含 time_budget_ms"),
		assert_eq(int(config.get("rollouts_per_sequence", -1)), 0, "rollouts_per_sequence 应为 0（不 rollout）"),
		assert_eq(int(config.get("branch_factor", 0)), 3, "branch_factor 应为 3"),
	])
