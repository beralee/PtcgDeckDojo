class_name TestCharizardUltraBallSearchPick
extends TestBase


const CHARIZARD_SCRIPT_PATH := "res://scripts/ai/DeckStrategyCharizardEx.gd"


func _new_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	var script: Variant = load(CHARIZARD_SCRIPT_PATH)
	return (script as GDScript).new() if script is GDScript else null


func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "C",
	hp: int = 100,
	evolves_from: String = "",
	mechanic: String = "",
	retreat_cost: int = 1
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	cd.evolves_from = evolves_from
	cd.mechanic = mechanic
	cd.retreat_cost = retreat_cost
	return cd


func _make_trainer_cd(pname: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = card_type
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _make_player(pi: int = 0) -> PlayerState:
	var player := PlayerState.new()
	player.player_index = pi
	return player


func _make_game_state(turn: int = 2) -> GameState:
	var gs := GameState.new()
	gs.turn_number = turn
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := _make_player(pi)
		player.active_pokemon = _make_slot(_make_pokemon_cd("Active%d" % pi), pi)
		gs.players.append(player)
	return gs


# Regression for scenario match_20260418_163308_440500_turn1_p1:
# 起始 hand (tracked p1, T1): [黑夜魔灵, 放逐吸尘器, 神奇糖果, 高级球, 反击捕捉器]
# active: Pidgey, bench: Charmander
# 期望: Ultra Ball 搜到 Rotom V 或 Charmander 作为人类的桥接/组合件，
#        而非 Dusclops（彷徨夜灵）这类仍需底座的 Stage1。
#
# bug 根因: DeckStrategyCharizardEx.pick_interaction_items 没有处理 "search_pokemon"
# step_id，AILegalActionBuilder 因而回退到 items.slice(0,1)，按 deck 原始顺序
# 取第一张 Pokemon。若 Dusclops 在 deck index 前面，就被错搜。
func test_pick_interaction_items_search_pokemon_prefers_live_basic_over_stage1_dead_weight() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyCharizardEx.gd should exist"
	var gs := _make_game_state(1)
	gs.current_player_index = 1
	gs.first_player_index = 1
	var player: PlayerState = gs.players[1]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 1)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 1))
	# Candidates as they would appear inside player.deck (Dusclops first, matches real scenario order)
	var dusclops := CardInstance.create(_make_pokemon_cd("Dusclops", "Stage 1", "P", 90, "Duskull"), 1)
	var rotom_v := CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 1)
	var charmander := CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 1)
	var pidgeot_ex := CardInstance.create(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 1)
	player.deck.append(dusclops)
	player.deck.append(rotom_v)
	player.deck.append(charmander)
	player.deck.append(pidgeot_ex)

	var items: Array = [dusclops, rotom_v, charmander, pidgeot_ex]
	var planned: Variant = strategy.pick_interaction_items(
		items,
		{"id": "search_pokemon", "max_select": 1},
		{"game_state": gs, "player_index": 1}
	)
	if not (planned is Array) or (planned as Array).is_empty():
		return "pick_interaction_items should return a non-empty plan for search_pokemon step, got %s" % str(planned)
	var chosen: CardInstance = (planned as Array)[0] as CardInstance
	var chosen_name := str(chosen.card_data.name) if chosen != null and chosen.card_data != null else ""
	return run_checks([
		assert_true(chosen_name in ["Rotom V", "Charmander"],
			"Ultra Ball search should pick a live basic bridge (Rotom V or Charmander), not Dusclops/Pidgeot ex (got %s)" % chosen_name),
		assert_false(chosen_name == "Dusclops",
			"Ultra Ball must never search Dusclops when no Duskull is on board"),
	])
