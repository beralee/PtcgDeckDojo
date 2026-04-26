class_name TestGardevoirDeadTurnRecovery
extends TestBase

## 回归测试：Opening/shell_lock 阶段"死回合"救援
##
## 场景源自 seed=6000 trace：
##   bench 已有 2 Ralts + active = Klefki
##   hand 有 Buddy Poffin + 2 Iono + Bravery Charm + 4 Dark Energy
##   没有 Kirlia，没 Gardevoir ex 在手，没 Arven，没 Ultra Ball
## 当前 bug：Poffin 评 -40（shell_lock + shell_bodies>=2 关闭）、Iono 评 0
##   → AI 只能 end_turn，连续 5 个死回合
## 期望：Poffin 和 Iono 都应该有正分，能打破死局

const DeckStrategyGardevoirScript = preload("res://scripts/ai/DeckStrategyGardevoir.gd")


func _make_cd(pname: String, ctype: String = "Pokemon", stage: String = "Basic", etype: String = "P", hp: int = 100) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = ctype
	cd.stage = stage
	cd.energy_type = etype
	cd.hp = hp
	return cd


func _make_energy_cd(pname: String, provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Basic Energy"
	cd.energy_provides = provides
	return cd


func _make_slot(cd: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(cd, owner))
	slot.turn_played = 0
	return slot


func _make_dead_turn_scenario() -> GameState:
	## 重现 seed=6000 死回合状态
	CardInstance.reset_id_counter()
	var gs := GameState.new()
	gs.turn_number = 5  # 已经第3个我方回合
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var p := PlayerState.new()
		p.player_index = pi
		gs.players.append(p)
	var me: PlayerState = gs.players[0]
	me.active_pokemon = _make_slot(_make_cd(DeckStrategyGardevoirScript.KLEFKI, "Pokemon", "Basic", "Y", 70), 0)
	me.bench.append(_make_slot(_make_cd(DeckStrategyGardevoirScript.RALTS, "Pokemon", "Basic", "P", 70), 0))
	me.bench.append(_make_slot(_make_cd(DeckStrategyGardevoirScript.RALTS, "Pokemon", "Basic", "P", 70), 0))
	# 手牌：Poffin + 2 Iono + Bravery Charm + 4 Dark Energy（没 Kirlia/GardevoirEx/Arven）
	me.hand.append(CardInstance.create(_make_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN, "Item"), 0))
	me.hand.append(CardInstance.create(_make_cd(DeckStrategyGardevoirScript.IONO, "Supporter"), 0))
	me.hand.append(CardInstance.create(_make_cd(DeckStrategyGardevoirScript.IONO, "Supporter"), 0))
	me.hand.append(CardInstance.create(_make_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0))
	for _i: int in 4:
		me.hand.append(CardInstance.create(_make_energy_cd("基本恶能量", "D"), 0))
	# 对手有一个随意的前场
	gs.players[1].active_pokemon = _make_slot(_make_cd("Opponent", "Pokemon", "Basic", "C", 100), 1)
	return gs


func test_buddy_poffin_should_rescue_dead_turn() -> String:
	## Poffin 在 shell_bodies>=2 但 hand 缺 Kirlia 时应该正分（可搜攻击手）
	var gs := _make_dead_turn_scenario()
	var s := DeckStrategyGardevoirScript.new()
	var poffin := CardInstance.create(_make_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN, "Item"), 0)
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": poffin}, gs, 0
	)
	return assert_true(score > 0.0,
		"Poffin 在死回合救援场景应正分（打破 end_turn=0 的僵局）(got %f)" % score)


func test_drifloon_should_bench_in_parallel_with_shell_build() -> String:
	## shell_lock + attacker_bodies=0 + bench 未满 → Drifloon 应能上板（与 Ralts 并行）
	## 避免 shell 上线后才 bench 攻击手导致慢 2 回合
	CardInstance.reset_id_counter()
	var gs := GameState.new()
	gs.turn_number = 2
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var p := PlayerState.new()
		p.player_index = pi
		gs.players.append(p)
	var me: PlayerState = gs.players[0]
	me.active_pokemon = _make_slot(_make_cd(DeckStrategyGardevoirScript.KLEFKI, "Pokemon", "Basic", "Y", 70), 0)
	me.bench.append(_make_slot(_make_cd(DeckStrategyGardevoirScript.RALTS, "Pokemon", "Basic", "P", 70), 0))
	me.hand.append(CardInstance.create(_make_cd(DeckStrategyGardevoirScript.DRIFLOON, "Pokemon", "Basic", "P", 70), 0))
	gs.players[1].active_pokemon = _make_slot(_make_cd("Opponent", "Pokemon", "Basic", "C", 100), 1)
	var s := DeckStrategyGardevoirScript.new()
	var drifloon := CardInstance.create(_make_cd(DeckStrategyGardevoirScript.DRIFLOON, "Pokemon", "Basic", "P", 70), 0)
	var score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": drifloon}, gs, 0
	)
	return assert_true(score > 0.0,
		"shell_lock + 无攻击手 + bench 未满 → Drifloon 应正分并行上板 (got %f)" % score)


func test_scream_tail_should_bench_in_parallel_with_shell_build() -> String:
	## 同上：Scream Tail 也应能与 shell 建设并行上板
	CardInstance.reset_id_counter()
	var gs := GameState.new()
	gs.turn_number = 2
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var p := PlayerState.new()
		p.player_index = pi
		gs.players.append(p)
	var me: PlayerState = gs.players[0]
	me.active_pokemon = _make_slot(_make_cd(DeckStrategyGardevoirScript.KLEFKI, "Pokemon", "Basic", "Y", 70), 0)
	me.bench.append(_make_slot(_make_cd(DeckStrategyGardevoirScript.RALTS, "Pokemon", "Basic", "P", 70), 0))
	me.hand.append(CardInstance.create(_make_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Pokemon", "Basic", "P", 70), 0))
	gs.players[1].active_pokemon = _make_slot(_make_cd("Opponent", "Pokemon", "Basic", "C", 100), 1)
	var s := DeckStrategyGardevoirScript.new()
	var scream := CardInstance.create(_make_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Pokemon", "Basic", "P", 70), 0)
	var score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": scream}, gs, 0
	)
	return assert_true(score > 0.0,
		"shell_lock + 无攻击手 + bench 未满 → Scream Tail 应正分并行上板 (got %f)" % score)


func test_ralts_still_dominates_attacker_in_shell_lock() -> String:
	## 防回归：shell_lock 阶段 Ralts 优先级应仍高于 Drifloon
	CardInstance.reset_id_counter()
	var gs := GameState.new()
	gs.turn_number = 2
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var p := PlayerState.new()
		p.player_index = pi
		gs.players.append(p)
	var me: PlayerState = gs.players[0]
	me.active_pokemon = _make_slot(_make_cd(DeckStrategyGardevoirScript.KLEFKI, "Pokemon", "Basic", "Y", 70), 0)
	gs.players[1].active_pokemon = _make_slot(_make_cd("Opponent", "Pokemon", "Basic", "C", 100), 1)
	var s := DeckStrategyGardevoirScript.new()
	var ralts := CardInstance.create(_make_cd(DeckStrategyGardevoirScript.RALTS, "Pokemon", "Basic", "P", 70), 0)
	var drifloon := CardInstance.create(_make_cd(DeckStrategyGardevoirScript.DRIFLOON, "Pokemon", "Basic", "P", 70), 0)
	var ralts_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": ralts}, gs, 0
	)
	var drifloon_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": drifloon}, gs, 0
	)
	return assert_true(ralts_score > drifloon_score,
		"Ralts (%f) 应高于 Drifloon (%f) 在 shell_lock 阶段" % [ralts_score, drifloon_score])


func test_poffin_still_top_priority_when_shell_not_built() -> String:
	## 防回归：shell_bodies < 2 时 Poffin 仍应高分（不被新逻辑覆盖）
	CardInstance.reset_id_counter()
	var gs := GameState.new()
	gs.turn_number = 2
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var p := PlayerState.new()
		p.player_index = pi
		gs.players.append(p)
	var me: PlayerState = gs.players[0]
	me.active_pokemon = _make_slot(_make_cd(DeckStrategyGardevoirScript.KLEFKI, "Pokemon", "Basic", "Y", 70), 0)
	me.bench.append(_make_slot(_make_cd(DeckStrategyGardevoirScript.RALTS, "Pokemon", "Basic", "P", 70), 0))
	me.hand.append(CardInstance.create(_make_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN, "Item"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_cd("Opponent", "Pokemon", "Basic", "C", 100), 1)
	var s := DeckStrategyGardevoirScript.new()
	var poffin := CardInstance.create(_make_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN, "Item"), 0)
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": poffin}, gs, 0
	)
	return assert_true(score >= 700.0,
		"shell_bodies<2 时 Poffin 应仍保持高分 (got %f)" % score)
