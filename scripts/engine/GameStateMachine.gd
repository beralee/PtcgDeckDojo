## 游戏状态机 - 控制 PTCG 完整对战流程
## 负责游戏初始化、回合流转、操作执行、胜负判定
class_name GameStateMachine
extends RefCounted

const AbilityAttachFromDeckEffect = preload("res://scripts/effects/pokemon_effects/AbilityAttachFromDeck.gd")

## 游戏状态变更信号
signal state_changed(new_phase: GameState.GamePhase)
## 操作日志信号（UI订阅用于显示）
signal action_logged(action: GameAction)
## 需要玩家选择（如Mulligan后对手是否额外抽牌）
signal player_choice_required(choice_type: String, data: Dictionary)
## 游戏结束信号
signal game_over(winner_index: int, reason: String)

var game_state: GameState
var rule_validator: RuleValidator
var damage_calculator: DamageCalculator
var effect_processor: EffectProcessor
var coin_flipper: CoinFlipper

## 操作日志
var action_log: Array[GameAction] = []

## 特性自爆等回合中间发生的 KO，替换完后应回到 MAIN 阶段而非结束回合
var _knockout_return_to_main: bool = false

## Mulligan计数（用于对手额外抽牌）
var _mulligan_counts: Array[int] = [0, 0]
var _pending_heavy_baton_player_index: int = -1
var _pending_heavy_baton_slot: PokemonSlot = null
var _pending_heavy_baton_is_active: bool = false
var _pending_prize_player_index: int = -1
var _pending_prize_remaining: int = 0
var _pending_prize_knocked_out_player_index: int = -1
var _pending_prize_knockout_is_active: bool = false
var _pending_prize_resume_mode: String = ""
var _pending_prize_resume_player_index: int = -1


func _init() -> void:
	coin_flipper = CoinFlipper.new()
	rule_validator = RuleValidator.new()
	damage_calculator = DamageCalculator.new()
	effect_processor = EffectProcessor.new(coin_flipper)
	game_state = GameState.new()


# ===================== 游戏初始化 =====================

## 开始新游戏
## deck_1/deck_2: 卡组数据；force_first: -1=随机, 0=玩家0先攻, 1=玩家1先攻
func start_game(deck_1: DeckData, deck_2: DeckData, force_first: int = -1) -> void:
	game_state = GameState.new()
	action_log.clear()
	_mulligan_counts = [0, 0]
	effect_processor = EffectProcessor.new(coin_flipper)
	_clear_pending_prize_choice()

	# 决定先攻
	if force_first == -1:
		game_state.first_player_index = 0 if coin_flipper.flip() else 1
	else:
		game_state.first_player_index = force_first
	game_state.current_player_index = game_state.first_player_index

	# 初始化两位玩家
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		game_state.players.append(player)

	# 构建牌库
	_build_deck(0, deck_1)
	_build_deck(1, deck_2)

	_log_action(GameAction.ActionType.GAME_START, -1, {
		"first_player": game_state.first_player_index
	}, "游戏开始，玩家%d先攻" % game_state.first_player_index)

	# 进入准备阶段
	_enter_phase(GameState.GamePhase.SETUP)
	_run_setup_phase()


## 根据 DeckData 构建 CardInstance 牌库并洗牌
func _build_deck(player_index: int, deck_data: DeckData) -> void:
	var player: PlayerState = game_state.players[player_index]
	game_state.last_knockout_turn_against[player_index] = game_state.turn_number
	CardInstance.reset_id_counter()
	for entry: Dictionary in deck_data.cards:
		var set_code: String = entry.get("set_code", "")
		var card_index: String = entry.get("card_index", "")
		var count: int = entry.get("count", 1)
		var card_data: CardData = CardDatabase.get_card(set_code, card_index)
		if card_data == null:
			push_warning("GameStateMachine: 找不到卡牌 %s_%s" % [set_code, card_index])
			continue
		effect_processor.register_pokemon_card(card_data)
		for _i: int in count:
			player.deck.append(CardInstance.create(card_data, player_index))
	player.shuffle_deck()


# ===================== 准备阶段 =====================

func _run_setup_phase() -> void:
	# 双方各抽7张初始手牌，处理Mulligan
	_deal_initial_hands()


func _deal_initial_hands() -> void:
	# 双方抽7张
	for pi: int in 2:
		var player: PlayerState = game_state.players[pi]
		var drawn: Array[CardInstance] = player.draw_cards(7)
		_log_action(GameAction.ActionType.DRAW_CARD, pi,
			{"count": drawn.size()}, "玩家%d抽取初始手牌7张" % pi)

	# 检查Mulligan
	_check_mulligan()


func _check_mulligan() -> void:
	var needs_mulligan: Array[bool] = [false, false]
	for pi: int in 2:
		if not rule_validator.has_basic_pokemon_in_hand(game_state.players[pi]):
			needs_mulligan[pi] = true

	# 双方都无基础宝可梦：都重来
	if needs_mulligan[0] and needs_mulligan[1]:
		for pi: int in 2:
			_do_mulligan(pi)
		_check_mulligan()
		return

	# 处理单方Mulligan
	for pi: int in 2:
		if needs_mulligan[pi]:
			_do_mulligan(pi)
			var opp_index: int = 1 - pi
			_mulligan_counts[pi] += 1
			# 对手可选择额外抽1张
			if _mulligan_counts[pi] > 0:
				# 通知UI让对手选择是否额外抽牌
				player_choice_required.emit("mulligan_extra_draw", {
					"beneficiary": opp_index,
					"mulligan_count": _mulligan_counts[pi]
				})
				# 注意：实际等待玩家选择后由 resolve_mulligan_choice() 继续
				return

	# 所有玩家手牌中都有基础宝可梦，等待UI调用 begin_setup_placement()
	player_choice_required.emit("setup_ready", {})


## 执行Mulligan：将手牌放回牌库，重新洗牌并抽7张
func _do_mulligan(player_index: int) -> void:
	var player: PlayerState = game_state.players[player_index]
	# 将手牌放回牌库
	for card: CardInstance in player.hand:
		player.deck.append(card)
	player.hand.clear()
	player.shuffle_deck()
	# 重新抽7张
	var drawn: Array[CardInstance] = player.draw_cards(7)
	_log_action(GameAction.ActionType.MULLIGAN, player_index,
		{"count": drawn.size()}, "玩家%d Mulligan，重新抽7张手牌" % player_index)


## 解决Mulligan后的选择（对手是否额外抽牌）
func resolve_mulligan_choice(beneficiary: int, draw_extra: bool) -> void:
	if draw_extra:
		var drawn: Array[CardInstance] = game_state.players[beneficiary].draw_cards(1)
		if not drawn.is_empty():
			_log_action(GameAction.ActionType.DRAW_CARD, beneficiary,
				{"count": 1}, "玩家%d因对手Mulligan额外抽1张" % beneficiary)

	# 检查重抽后是否还需要Mulligan
	var mulligan_player: int = 1 - beneficiary
	if not rule_validator.has_basic_pokemon_in_hand(game_state.players[mulligan_player]):
		_do_mulligan(mulligan_player)
		_mulligan_counts[mulligan_player] += 1
		player_choice_required.emit("mulligan_extra_draw", {
			"beneficiary": beneficiary,
			"mulligan_count": _mulligan_counts[mulligan_player]
		})
		return

	player_choice_required.emit("setup_ready", {})


## 准备阶段：放置战斗宝可梦（由UI调用）
func setup_place_active_pokemon(player_index: int, card: CardInstance) -> bool:
	if not card.card_data.is_basic_pokemon():
		return false
	var player: PlayerState = game_state.players[player_index]
	if not card in player.hand:
		return false

	player.hand.erase(card)
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	slot.turn_played = 0  # 准备阶段放置
	player.active_pokemon = slot
	card.face_up = false  # 准备阶段反面放置

	_log_action(GameAction.ActionType.SETUP_PLACE_ACTIVE, player_index,
		{"card_name": card.card_data.name},
		"玩家%d选择 %s 作为战斗宝可梦" % [player_index, card.card_data.name])
	return true


## 准备阶段：放置备战区宝可梦（可选，由UI调用，pass_setup表示不再放置）
func setup_place_bench_pokemon(player_index: int, card: CardInstance) -> bool:
	if not card.card_data.is_basic_pokemon():
		return false
	var player: PlayerState = game_state.players[player_index]
	if not card in player.hand:
		return false
	if player.is_bench_full():
		return false

	player.hand.erase(card)
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	slot.turn_played = 0
	player.bench.append(slot)
	card.face_up = false

	_log_action(GameAction.ActionType.SETUP_PLACE_BENCH, player_index,
		{"card_name": card.card_data.name},
		"玩家%d将 %s 放入备战区" % [player_index, card.card_data.name])
	return true


## 准备完成，摆放奖赏卡并正式开始（两位玩家都设置好active后由UI调用一次）
## 返回 true 表示双方都已就绪并开始游戏，false 表示尚未满足条件
func setup_complete(player_index: int) -> bool:
	# 检查双方是否都有战斗宝可梦
	for pi: int in 2:
		if game_state.players[pi].active_pokemon == null:
			return false

	# 双方都已设置，翻开宝可梦并摆放奖赏卡
	for pi: int in 2:
		var player: PlayerState = game_state.players[pi]
		if player.active_pokemon != null:
			player.active_pokemon.get_top_card().face_up = true
		for bench_slot: PokemonSlot in player.bench:
			bench_slot.get_top_card().face_up = true
		# 摆放6张奖赏卡
		var prizes: Array[CardInstance] = []
		for _i: int in 6:
			if player.deck.is_empty():
				break
			var prize: CardInstance = player.deck.pop_front()
			prize.face_up = false
			prizes.append(prize)
		player.set_prizes(prizes)
		_log_action(GameAction.ActionType.SETUP_SET_PRIZES, pi,
			{"count": prizes.size()}, "玩家%d摆放6张奖赏卡" % pi)

	# 开始第一回合
	_start_turn()
	return true


# ===================== 回合流转 =====================

func _start_turn() -> void:
	var cp: int = game_state.current_player_index
	game_state.turn_number += 1
	game_state.energy_attached_this_turn = false
	game_state.supporter_used_this_turn = false
	game_state.stadium_played_this_turn = false
	game_state.retreat_used_this_turn = false

	_log_action(GameAction.ActionType.TURN_START, cp,
		{"turn": game_state.turn_number}, "第%d回合开始，玩家%d行动" % [game_state.turn_number, cp])

	_enter_phase(GameState.GamePhase.DRAW)

	# 抽牌
	var drawn: Array[CardInstance] = game_state.players[cp].draw_cards(1)
	if drawn.is_empty():
		# 牌库耗尽，败北
		_trigger_game_over(1 - cp, "牌库耗尽")
		return

	_log_action(GameAction.ActionType.DRAW_CARD, cp,
		{"count": 1}, "玩家%d抽1张牌" % cp)

	# 进入主阶段
	_enter_phase(GameState.GamePhase.MAIN)


## 玩家结束回合（选择不使用招式）
func end_turn(player_index: int) -> void:
	if game_state.current_player_index != player_index:
		return
	if game_state.phase != GameState.GamePhase.MAIN:
		return

	_log_action(GameAction.ActionType.TURN_END, player_index,
		{}, "玩家%d结束回合" % player_index)

	_enter_phase(GameState.GamePhase.POKEMON_CHECK)
	_do_pokemon_check()


func _do_pokemon_check() -> void:
	var damaged_slots: Array[PokemonSlot] = effect_processor.process_pokemon_check(game_state)

	_log_action(GameAction.ActionType.POKEMON_CHECK, -1, {}, "宝可梦检查")

	# 检查昏厥
	_check_all_knockouts()


func _check_all_knockouts() -> void:
	var knockout_found := false
	for pi: int in 2:
		var player: PlayerState = game_state.players[pi]
		# 检查战斗宝可梦
		if player.active_pokemon != null and effect_processor.is_effectively_knocked_out(player.active_pokemon, game_state):
			if not _handle_knockout(pi, player.active_pokemon, true):
				return
			knockout_found = true
		# 检查备战区
		var bench_to_remove: Array[PokemonSlot] = []
		for bench_slot: PokemonSlot in player.bench:
			if effect_processor.is_effectively_knocked_out(bench_slot, game_state):
				bench_to_remove.append(bench_slot)
		for slot: PokemonSlot in bench_to_remove:
			if not _handle_knockout(pi, slot, false):
				return
			knockout_found = true

	if game_state.phase == GameState.GamePhase.KNOCKOUT_REPLACE:
		return
	if not knockout_found:
		_advance_to_next_turn()
	elif _knockout_return_to_main:
		# 回合中通过特性/训练家/竞技场等造成的 KO，结算后应继续当前玩家的 MAIN。
		_knockout_return_to_main = false
		_enter_phase(GameState.GamePhase.MAIN)
	else:
		# 攻击击倒备战区等无需替换的 KO，结算后仍应正常换到对手回合。
		_advance_to_next_turn()


func _has_pending_knockouts() -> bool:
	for player: PlayerState in game_state.players:
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot != null and effect_processor.is_effectively_knocked_out(slot, game_state):
				return true
	return false


func _resolve_mid_turn_knockouts() -> bool:
	if not _has_pending_knockouts():
		return false
	_knockout_return_to_main = true
	_enter_phase(GameState.GamePhase.POKEMON_CHECK)
	_check_all_knockouts()
	return true


## 处理宝可梦昏厥
func _handle_knockout(player_index: int, slot: PokemonSlot, is_active: bool) -> bool:
	if _maybe_request_heavy_baton_choice(player_index, slot, is_active):
		return false
	_apply_heavy_baton_if_possible(player_index, slot, null)
	return _finalize_knockout(player_index, slot, is_active)


func _finalize_knockout(player_index: int, slot: PokemonSlot, is_active: bool) -> bool:
	var opp_index: int = 1 - player_index
	var pokemon_name: String = slot.get_pokemon_name()
	var base_prize_count: int = slot.get_prize_count()
	var prize_count: int = _get_knockout_prize_count(slot)
	var player: PlayerState = game_state.players[player_index]
	game_state.last_knockout_turn_against[player_index] = game_state.turn_number

	# 遗赠能量：减少对手拿取的奖赏卡
	var prize_modifier: int = effect_processor.get_knockout_prize_modifier(slot, game_state)
	if prize_modifier != 0:
		_log_action(GameAction.ActionType.USE_ABILITY, player_index,
			{}, "遗赠能量生效：对手拿取的奖赏卡从%d张减为%d张" % [base_prize_count, prize_count])
	effect_processor.mark_knockout_prize_modifier_consumed(slot, game_state)

	# 馈赠能量：附着宝可梦昏厥时，拥有者抽卡到手牌7张
	if EffectGiftEnergy.check_gift_energy_on_knockout(slot):
		var hand_before: int = player.hand.size()
		EffectGiftEnergy.trigger_on_knockout(player)
		var drawn: int = player.hand.size() - hand_before
		if drawn > 0:
			_log_action(GameAction.ActionType.DRAW_CARD, player_index,
				{"count": drawn}, "馈赠能量生效：抽取%d张卡牌（手牌到7张）" % drawn)

	_move_knocked_out_cards(slot, player)

	# 从场上移除
	if is_active:
		player.active_pokemon = null
	else:
		player.bench.erase(slot)

	_log_action(GameAction.ActionType.KNOCKOUT, player_index,
		{"pokemon_name": pokemon_name, "prize_count": prize_count},
		"玩家%d的 %s 昏厥" % [player_index, pokemon_name])

	# 对手拿取奖赏卡
	var prizes_taken: Array[CardInstance] = []
	var available_prizes: int = game_state.players[opp_index].prizes.size()
	var pending_prize_count: int = mini(prize_count, available_prizes)
	if pending_prize_count > 0:
		_pending_prize_player_index = opp_index
		_pending_prize_remaining = pending_prize_count
		_pending_prize_knocked_out_player_index = player_index
		_pending_prize_knockout_is_active = is_active
		if is_active:
			if game_state.players[player_index].bench.is_empty():
				_pending_prize_resume_mode = "game_over"
				_pending_prize_resume_player_index = opp_index
			else:
				_pending_prize_resume_mode = "send_out"
				_pending_prize_resume_player_index = player_index
		elif _knockout_return_to_main:
			_pending_prize_resume_mode = "resume_main"
			_pending_prize_resume_player_index = player_index
		else:
			_pending_prize_resume_mode = "resume_check"
			_pending_prize_resume_player_index = player_index
		player_choice_required.emit("take_prize", {
			"player": opp_index,
			"count": pending_prize_count,
			"description": "Select 1 prize card"
		})
		return false

	for _i: int in prize_count:
		if not game_state.players[opp_index].prizes.is_empty():
			var prize: CardInstance = game_state.players[opp_index].prizes.pop_back()
			game_state.players[opp_index].hand.append(prize)
			prizes_taken.append(prize)

	if not prizes_taken.is_empty():
		_log_action(GameAction.ActionType.TAKE_PRIZE, opp_index,
			{"count": prizes_taken.size()},
			"玩家%d拿取%d张奖赏卡" % [opp_index, prizes_taken.size()])

	# 检查胜利条件
	if _check_win_condition() >= 0:
		return true

	# 战斗宝可梦昏厥需要派出替换宝可梦
	if is_active:
		if game_state.players[player_index].bench.is_empty():
			# 无备战宝可梦，对手获胜
			_trigger_game_over(opp_index, "对手无宝可梦可派出")
		else:
			_enter_phase(GameState.GamePhase.KNOCKOUT_REPLACE)
			player_choice_required.emit("send_out_pokemon", {
				"player": player_index,
				"description": "请选择1只备战宝可梦派出"
			})


	return true


func resolve_take_prize(player_index: int, slot_index: int) -> bool:
	if player_index != _pending_prize_player_index or _pending_prize_remaining <= 0:
		return false
	var player: PlayerState = game_state.players[player_index]
	var taken_prize: CardInstance = player.take_prize_from_slot(slot_index)
	if taken_prize == null:
		return false

	_pending_prize_remaining -= 1
	_log_action(GameAction.ActionType.TAKE_PRIZE, player_index,
		{
			"count": 1,
			"card_name": taken_prize.card_data.name if taken_prize.card_data != null else ""
		},
		"玩家%d拿取1张奖赏卡" % player_index)

	if _pending_prize_remaining > 0 and not player.prizes.is_empty():
		player_choice_required.emit("take_prize", {
			"player": player_index,
			"count": _pending_prize_remaining,
			"description": "Select 1 prize card"
		})
		return true

	var resume_mode: String = _pending_prize_resume_mode
	var resume_player_index: int = _pending_prize_resume_player_index
	_clear_pending_prize_choice()

	if _check_win_condition() >= 0:
		return true

	match resume_mode:
		"send_out":
			_enter_phase(GameState.GamePhase.KNOCKOUT_REPLACE)
			player_choice_required.emit("send_out_pokemon", {
				"player": resume_player_index,
				"description": "请选择1只备战宝可梦派出"
			})
		"game_over":
			_trigger_game_over(resume_player_index, "对手无宝可梦")
		"resume_main":
			if _has_pending_knockouts():
				_enter_phase(GameState.GamePhase.POKEMON_CHECK)
				_check_all_knockouts()
			else:
				_knockout_return_to_main = false
				_enter_phase(GameState.GamePhase.MAIN)
		"resume_check":
			_enter_phase(GameState.GamePhase.POKEMON_CHECK)
			_check_all_knockouts()
	return true


func _clear_pending_prize_choice() -> void:
	_pending_prize_player_index = -1
	_pending_prize_remaining = 0
	_pending_prize_knocked_out_player_index = -1
	_pending_prize_knockout_is_active = false
	_pending_prize_resume_mode = ""
	_pending_prize_resume_player_index = -1


func _move_knocked_out_cards(slot: PokemonSlot, player: PlayerState) -> void:
	if _should_lost_city_redirect_knockout():
		for pokemon_card: CardInstance in slot.pokemon_stack:
			player.lost_zone.append(pokemon_card)
		for energy: CardInstance in slot.attached_energy:
			player.discard_pile.append(energy)
		if slot.attached_tool != null:
			player.discard_pile.append(slot.attached_tool)
		return

	for card: CardInstance in slot.collect_all_cards():
		player.discard_pile.append(card)


func _should_lost_city_redirect_knockout() -> bool:
	if game_state.stadium_card == null:
		return false
	var stadium_effect: BaseEffect = effect_processor.get_effect(game_state.stadium_card.card_data.effect_id)
	return stadium_effect != null and stadium_effect.has_method("redirects_knocked_out_pokemon_to_lost_zone") and bool(stadium_effect.call("redirects_knocked_out_pokemon_to_lost_zone"))


func _maybe_request_heavy_baton_choice(player_index: int, slot: PokemonSlot, is_active: bool) -> bool:
	var transferable: Array[CardInstance] = _get_heavy_baton_transferable_energy(slot)
	if transferable.is_empty():
		return false
	var targets: Array[PokemonSlot] = _get_available_heavy_baton_targets(player_index, slot)
	if targets.is_empty():
		return false
	if targets.size() == 1:
		return false
	_pending_heavy_baton_player_index = player_index
	_pending_heavy_baton_slot = slot
	_pending_heavy_baton_is_active = is_active
	player_choice_required.emit("heavy_baton_target", {
		"player": player_index,
		"bench": targets.duplicate(),
		"count": mini(3, transferable.size()),
		"source_name": slot.attached_tool.card_data.name if slot.attached_tool != null else "沉重接力棒",
	})
	return true


func _get_heavy_baton_effect(slot: PokemonSlot) -> EffectToolHeavyBaton:
	if slot == null or slot.attached_tool == null:
		return null
	if effect_processor.is_tool_effect_suppressed(slot, game_state):
		return null
	var tool_eid: String = slot.attached_tool.card_data.effect_id
	var effect: BaseEffect = effect_processor.get_effect(tool_eid)
	if not effect is EffectToolHeavyBaton:
		return null
	return effect as EffectToolHeavyBaton


func _get_heavy_baton_transferable_energy(slot: PokemonSlot) -> Array[CardInstance]:
	var heavy_baton: EffectToolHeavyBaton = _get_heavy_baton_effect(slot)
	if heavy_baton == null:
		return []
	if not heavy_baton.can_trigger(slot):
		return []
	return heavy_baton.get_transferable_energy(slot)


func _apply_heavy_baton_if_possible(
	player_index: int,
	slot: PokemonSlot,
	target_slot: PokemonSlot
) -> void:
	var heavy_baton: EffectToolHeavyBaton = _get_heavy_baton_effect(slot)
	if heavy_baton == null:
		return
	var transferable: Array[CardInstance] = _get_heavy_baton_transferable_energy(slot)
	if transferable.is_empty():
		return
	var resolved_target: PokemonSlot = target_slot
	if resolved_target == null:
		var targets: Array[PokemonSlot] = _get_available_heavy_baton_targets(player_index, slot)
		if targets.is_empty():
			return
		resolved_target = targets[0]
	if not resolved_target in _get_available_heavy_baton_targets(player_index, slot):
		return
	heavy_baton.transfer_energy(slot, resolved_target, transferable)
	_log_action(GameAction.ActionType.ATTACH_ENERGY, player_index,
		{
			"tool": slot.attached_tool.card_data.name,
			"count": transferable.size(),
			"target": resolved_target.get_pokemon_name()
		},
		"%s将%d张基本能量转移给%s" % [
			slot.attached_tool.card_data.name,
			transferable.size(),
			resolved_target.get_pokemon_name()
		])


func _get_available_heavy_baton_targets(player_index: int, knocked_out_slot: PokemonSlot) -> Array[PokemonSlot]:
	var player: PlayerState = game_state.players[player_index]
	var targets: Array[PokemonSlot] = []
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot != knocked_out_slot and not bench_slot.is_knocked_out():
			targets.append(bench_slot)
	return targets


func resolve_heavy_baton_choice(player_index: int, bench_slot: PokemonSlot) -> bool:
	if (
		_pending_heavy_baton_slot == null
		or _pending_heavy_baton_player_index != player_index
		or bench_slot == null
	):
		return false
	if not bench_slot in _get_available_heavy_baton_targets(player_index, _pending_heavy_baton_slot):
		return false

	var pending_slot: PokemonSlot = _pending_heavy_baton_slot
	var pending_is_active: bool = _pending_heavy_baton_is_active
	_pending_heavy_baton_player_index = -1
	_pending_heavy_baton_slot = null
	_pending_heavy_baton_is_active = false

	_apply_heavy_baton_if_possible(player_index, pending_slot, bench_slot)
	var knockout_completed: bool = _finalize_knockout(player_index, pending_slot, pending_is_active)

	if knockout_completed and game_state.phase == GameState.GamePhase.POKEMON_CHECK:
		_check_all_knockouts()
	return true


## 派出替换宝可梦（昏厥后由UI调用）
func send_out_pokemon(player_index: int, bench_slot: PokemonSlot) -> bool:
	var player: PlayerState = game_state.players[player_index]
	if _pending_prize_remaining > 0:
		return false
	if not bench_slot in player.bench:
		return false
	if player.active_pokemon != null:
		return false

	player.bench.erase(bench_slot)
	player.active_pokemon = bench_slot

	_log_action(GameAction.ActionType.SEND_OUT, player_index,
		{"pokemon_name": bench_slot.get_pokemon_name()},
		"玩家%d派出 %s" % [player_index, bench_slot.get_pokemon_name()])

	if _has_pending_knockouts():
		_enter_phase(GameState.GamePhase.POKEMON_CHECK)
		_check_all_knockouts()
		return true

	# 特性自爆等回合中间 KO：替换完后回到 MAIN 阶段继续操作
	if _knockout_return_to_main:
		_knockout_return_to_main = false
		_enter_phase(GameState.GamePhase.MAIN)
		return true
	# 正常攻击后 KO：切换回合
	_advance_to_next_turn()
	return true


func _advance_to_next_turn() -> void:
	if _check_win_condition() >= 0:
		return
	_discard_expired_tools()
	# 切换玩家
	game_state.switch_player()
	_start_turn()


# ===================== 玩家操作 =====================

## 抽牌（通常用于效果触发的抽牌）
func draw_card(player_index: int, count: int = 1) -> Array[CardInstance]:
	var drawn: Array[CardInstance] = game_state.players[player_index].draw_cards(count)
	if not drawn.is_empty():
		_log_action(GameAction.ActionType.DRAW_CARD, player_index,
			{"count": drawn.size()}, "玩家%d抽%d张牌" % [player_index, drawn.size()])
	return drawn


## 从手牌放出基础宝可梦到备战区
func play_basic_to_bench(
	player_index: int,
	card: CardInstance,
	auto_trigger_bench_ability: bool = true
) -> bool:
	if not rule_validator.can_play_basic_to_bench(game_state, player_index, card):
		return false

	var player: PlayerState = game_state.players[player_index]
	player.hand.erase(card)
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	slot.turn_played = game_state.turn_number
	player.bench.append(slot)

	_log_action(GameAction.ActionType.PLAY_POKEMON, player_index,
		{"card_name": card.card_data.name},
		"玩家%d将 %s 放入备战区" % [player_index, card.card_data.name])
	if auto_trigger_bench_ability:
		_try_auto_resolve_on_bench_enter_ability(player_index, slot)
	return true


## 进化宝可梦
func evolve_pokemon(player_index: int, evolution: CardInstance, target_slot: PokemonSlot) -> bool:
	if not rule_validator.can_evolve(game_state, player_index, target_slot, evolution):
		return false

	var player: PlayerState = game_state.players[player_index]
	player.hand.erase(evolution)
	target_slot.pokemon_stack.append(evolution)
	target_slot.turn_evolved = game_state.turn_number
	# 进化清除特殊状态
	target_slot.clear_all_status()

	_log_action(GameAction.ActionType.EVOLVE, player_index,
		{"evolution": evolution.card_data.name, "base": target_slot.get_pokemon_name()},
		"玩家%d将 %s 进化为 %s" % [player_index, target_slot.get_pokemon_name(), evolution.card_data.name])
	_try_auto_resolve_on_evolve_ability(player_index, target_slot)
	return true


func get_evolve_ability_interaction_steps(slot: PokemonSlot) -> Array[Dictionary]:
	if slot == null or slot.get_top_card() == null:
		return []
	var top: CardInstance = slot.get_top_card()
	var effect: BaseEffect = effect_processor.get_effect(top.card_data.effect_id)
	if not effect is AbilityAttachFromDeck:
		return []
	var attach_effect: AbilityAttachFromDeck = effect as AbilityAttachFromDeck
	if not attach_effect.on_evolve_only:
		return []
	if not effect_processor.can_use_ability(slot, game_state, 0):
		return []
	return attach_effect.get_interaction_steps(top, game_state)


func _try_auto_resolve_on_evolve_ability(player_index: int, slot: PokemonSlot) -> void:
	if slot == null or slot.get_top_card() == null:
		return
	var top: CardInstance = slot.get_top_card()
	var effect: BaseEffect = effect_processor.get_effect(top.card_data.effect_id)
	if not effect is AbilityAttachFromDeckEffect:
		return
	var attach_effect = effect as AbilityAttachFromDeckEffect
	if not attach_effect.on_evolve_only:
		return
	if not effect_processor.can_use_ability(slot, game_state, 0):
		return
	if not attach_effect.get_interaction_steps(top, game_state).is_empty():
		return

	var default_targets: Array = []
	match attach_effect.target_filter:
		"self", "own_one":
			default_targets.append(slot)
		"own":
			for _i: int in attach_effect.max_count:
				default_targets.append(slot)

	use_ability(player_index, slot, 0, default_targets)


## 附着能量到宝可梦
func _try_auto_resolve_on_bench_enter_ability(player_index: int, slot: PokemonSlot) -> void:
	if slot == null or slot.get_top_card() == null:
		return
	var effect: BaseEffect = effect_processor.get_ability_effect(slot, 0, game_state)
	if not effect is AbilityOnBenchEnter:
		return
	if not effect_processor.can_use_ability(slot, game_state, 0):
		return
	effect.execute_ability(slot, 0, [], game_state)
	var ability_name: String = effect_processor.get_ability_name(slot, 0, game_state)
	if ability_name == "":
		ability_name = slot.get_pokemon_name()
	_log_action(GameAction.ActionType.USE_ABILITY, player_index,
		{"pokemon_name": slot.get_pokemon_name(), "ability_name": ability_name},
		"Used ability: %s" % ability_name)


func attach_energy(player_index: int, energy: CardInstance, target_slot: PokemonSlot) -> bool:
	if not rule_validator.can_attach_energy(game_state, player_index):
		return false

	var player: PlayerState = game_state.players[player_index]
	if not energy in player.hand:
		return false

	player.hand.erase(energy)
	target_slot.attached_energy.append(energy)
	game_state.energy_attached_this_turn = true
	effect_processor.execute_card_effect(energy, [target_slot], game_state)

	_log_action(GameAction.ActionType.ATTACH_ENERGY, player_index,
		{"energy": energy.card_data.name, "target": target_slot.get_pokemon_name()},
		"玩家%d将 %s 附着到 %s" % [player_index, energy.card_data.name, target_slot.get_pokemon_name()])
	return true


## 附着道具卡到宝可梦
func attach_tool(player_index: int, tool_card: CardInstance, target_slot: PokemonSlot) -> bool:
	if not rule_validator.can_attach_tool(game_state, player_index, target_slot):
		return false

	var player: PlayerState = game_state.players[player_index]
	if not tool_card in player.hand:
		return false

	player.hand.erase(tool_card)
	target_slot.attached_tool = tool_card

	_log_action(GameAction.ActionType.PLAY_TOOL, player_index,
		{"tool": tool_card.card_data.name, "target": target_slot.get_pokemon_name()},
		"玩家%d将 %s 附着到 %s" % [player_index, tool_card.card_data.name, target_slot.get_pokemon_name()])
	return true


## 使用训练家卡（物品卡/支援者卡）
func play_trainer(player_index: int, card: CardInstance, targets: Array) -> bool:
	var card_type: String = card.card_data.card_type
	if card_type == "Item" and not rule_validator.can_play_item(game_state, player_index):
		return false
	# 支援者卡检查
	if card_type == "Supporter":
		if not rule_validator.can_play_supporter(game_state, player_index) and not _can_play_supporter_exception(player_index, card):
			return false

	var player: PlayerState = game_state.players[player_index]
	if not card in player.hand:
		return false

	player.hand.erase(card)

	# 执行效果
	var success: bool = effect_processor.execute_card_effect(card, targets, game_state)
	if not success:
		# 效果执行失败，将卡牌放回手牌
		player.hand.append(card)
		return false

	# 放入弃牌区
	player.discard_pile.append(card)

	if card_type == "Supporter":
		game_state.supporter_used_this_turn = true

	_log_action(GameAction.ActionType.PLAY_TRAINER, player_index,
		{"card_name": card.card_data.name}, "玩家%d使用 %s" % [player_index, card.card_data.name])
	_resolve_mid_turn_knockouts()
	return true


## 使出竞技场卡
func play_stadium(player_index: int, card: CardInstance, targets: Array = []) -> bool:
	if not rule_validator.can_play_stadium(game_state, player_index, card):
		return false

	var player: PlayerState = game_state.players[player_index]
	if not card in player.hand:
		return false

	# 旧竞技场放入持有者弃牌区
	if game_state.stadium_card != null:
		var old_owner: PlayerState = game_state.players[game_state.stadium_owner_index]
		old_owner.discard_pile.append(game_state.stadium_card)

	player.hand.erase(card)
	game_state.stadium_card = card
	game_state.stadium_owner_index = player_index
	game_state.stadium_played_this_turn = true

	var stadium_effect: BaseEffect = effect_processor.get_effect(card.card_data.effect_id)
	if stadium_effect != null:
		stadium_effect.execute_on_play(card, game_state, targets)

	_log_action(GameAction.ActionType.PLAY_STADIUM, player_index,
		{"card_name": card.card_data.name}, "玩家%d使出竞技场 %s" % [player_index, card.card_data.name])
	_resolve_mid_turn_knockouts()
	return true


func _can_play_supporter_exception(player_index: int, card: CardInstance) -> bool:
	if game_state.current_player_index != player_index:
		return false
	if game_state.phase != GameState.GamePhase.MAIN:
		return false
	if game_state.supporter_used_this_turn:
		return false
	return card.card_data.effect_id == "8150af4062192998497e376ad931bea4"


func can_use_stadium_effect(player_index: int) -> bool:
	if game_state.current_player_index != player_index:
		return false
	if game_state.phase != GameState.GamePhase.MAIN:
		return false
	if game_state.stadium_card == null:
		return false
	var effect: BaseEffect = effect_processor.get_effect(game_state.stadium_card.card_data.effect_id)
	if effect == null:
		return false
	if not effect.can_use_as_stadium_action(game_state.stadium_card, game_state):
		return false
	if (
		game_state.stadium_effect_used_turn == game_state.turn_number
		and game_state.stadium_effect_used_player == player_index
	):
		return false
	return effect.can_execute(game_state.stadium_card, game_state)


func use_stadium_effect(player_index: int, targets: Array = []) -> bool:
	if not can_use_stadium_effect(player_index):
		return false
	var stadium_card: CardInstance = game_state.stadium_card
	var effect: BaseEffect = effect_processor.get_effect(stadium_card.card_data.effect_id)
	if effect == null:
		return false

	effect.execute(stadium_card, targets, game_state)
	game_state.stadium_effect_used_turn = game_state.turn_number
	game_state.stadium_effect_used_player = player_index

	_log_action(GameAction.ActionType.USE_STADIUM, player_index,
		{"card_name": stadium_card.card_data.name}, "玩家%d使用竞技场效果 %s" % [player_index, stadium_card.card_data.name])
	_resolve_mid_turn_knockouts()
	return true


## 撤退
func retreat(player_index: int, energy_to_discard: Array[CardInstance], bench_slot: PokemonSlot) -> bool:
	if not rule_validator.can_retreat(game_state, player_index):
		return false

	var player: PlayerState = game_state.players[player_index]
	var active: PokemonSlot = player.active_pokemon
	var retreat_cost: int = effect_processor.get_effective_retreat_cost(active, game_state)

	if not rule_validator.has_enough_energy_to_retreat(
		active,
		energy_to_discard,
		retreat_cost,
		effect_processor,
		game_state
	):
		return false
	if not rule_validator.validate_energy_on_pokemon(active, energy_to_discard):
		return false
	if not bench_slot in player.bench:
		return false

	# 弃置能量
	for energy: CardInstance in energy_to_discard:
		active.attached_energy.erase(energy)
		player.discard_pile.append(energy)

	# 清除特殊状态（撤退到备战区）
	active.clear_all_status()

	# 交换战斗宝可梦
	player.bench.erase(bench_slot)
	player.bench.append(active)
	player.active_pokemon = bench_slot

	game_state.retreat_used_this_turn = true

	_log_action(GameAction.ActionType.RETREAT, player_index,
		{
			"from": active.get_pokemon_name(),
			"to": bench_slot.get_pokemon_name(),
			"energy_discarded": energy_to_discard.size()
		},
		"玩家%d将 %s 撤退，派出 %s" % [player_index, active.get_pokemon_name(), bench_slot.get_pokemon_name()])
	return true


## 使用招式
func can_use_attack(player_index: int, attack_index: int) -> bool:
	return rule_validator.can_use_attack(game_state, player_index, attack_index, effect_processor)


func get_attack_unusable_reason(player_index: int, attack_index: int) -> String:
	return rule_validator.get_attack_unusable_reason(game_state, player_index, attack_index, effect_processor)


func get_attack_preview_damage(player_index: int, attack_index: int) -> int:
	if player_index < 0 or player_index >= game_state.players.size():
		return 0
	var player: PlayerState = game_state.players[player_index]
	var opp_index: int = 1 - player_index
	if opp_index < 0 or opp_index >= game_state.players.size():
		return 0
	var attacker: PokemonSlot = player.active_pokemon
	var defender: PokemonSlot = game_state.players[opp_index].active_pokemon
	if attacker == null or defender == null:
		return 0
	var attacks: Array = attacker.get_card_data().attacks
	if attack_index < 0 or attack_index >= attacks.size():
		return 0
	return _calculate_attack_damage(attacker, defender, attacks[attack_index], attack_index)


func use_attack(player_index: int, attack_index: int, targets: Array = []) -> bool:
	if not can_use_attack(player_index, attack_index):
		return false

	var player: PlayerState = game_state.players[player_index]
	var opp_index: int = 1 - player_index
	var attacker: PokemonSlot = player.active_pokemon
	var defender: PokemonSlot = game_state.players[opp_index].active_pokemon

	if defender == null:
		return false

	var attack: Dictionary = attacker.get_card_data().attacks[attack_index]
	var attack_name: String = attack.get("name", "")

	# 混乱状态投币判定
	if attacker.status_conditions.get("confused", false):
		var flip_result: bool = coin_flipper.flip()
		_log_action(GameAction.ActionType.COIN_FLIP, player_index,
			{"result": flip_result, "reason": "混乱投币"}, "混乱投币：%s" % ("正面" if flip_result else "反面"))
		if not flip_result:
			# 反面：失败，战斗宝可梦自伤30
			damage_calculator.apply_damage_to_slot(attacker, 30)
			_log_action(GameAction.ActionType.DAMAGE_DEALT, player_index,
				{"target": attacker.get_pokemon_name(), "damage": 30}, "混乱自伤30")
			# 结束回合（使用招式后）
			_after_attack(player_index)
			return true

	# 计算并应用伤害
	var damage: int = _calculate_attack_damage(attacker, defender, attack, attack_index, targets)

	if damage > 0:
		damage_calculator.apply_damage_to_slot(defender, damage)
		_log_action(GameAction.ActionType.DAMAGE_DEALT, player_index,
			{"target": defender.get_pokemon_name(), "damage": damage},
			"玩家%d使用 %s 对 %s 造成 %d 点伤害" % [player_index, attack_name, defender.get_pokemon_name(), damage])

	# VSTAR力量标记
	if attack.get("is_vstar_power", false):
		game_state.vstar_power_used[player_index] = true

	# 执行招式附加效果
	effect_processor.execute_attack_effect(attacker, attack_index, defender, game_state, targets)

	_log_action(GameAction.ActionType.ATTACK, player_index,
		{"attack_name": attack_name}, "玩家%d使用招式「%s」" % [player_index, attack_name])

	_after_attack(player_index)
	return true


func use_granted_attack(
	player_index: int,
	attacker: PokemonSlot,
	granted_attack: Dictionary,
	targets: Array = []
) -> bool:
	if game_state.current_player_index != player_index:
		return false
	if game_state.phase != GameState.GamePhase.MAIN:
		return false
	if attacker == null or attacker.get_top_card() == null:
		return false
	if attacker != game_state.players[player_index].active_pokemon:
		return false
	if attacker.attached_tool == null:
		return false
	if effect_processor.is_tool_effect_suppressed(attacker, game_state):
		return false
	var cost: String = str(granted_attack.get("cost", ""))
	if not rule_validator.has_enough_energy(attacker, cost, effect_processor, game_state):
		return false

	var defender: PokemonSlot = game_state.players[1 - player_index].active_pokemon
	if defender == null:
		return false

	if not effect_processor.execute_granted_attack(attacker, granted_attack, defender, game_state, targets):
		return false

	var attack_name: String = str(granted_attack.get("name", ""))
	_log_action(GameAction.ActionType.ATTACK, player_index, {"attack_name": attack_name}, "玩家%d使用招式：%s" % [player_index, attack_name])
	_after_attack(player_index)
	return true


func _calculate_attack_damage(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	attack: Dictionary,
	attack_index: int = 0,
	targets: Array = []
) -> int:
	var ignore_defender_effects: bool = effect_processor.attack_ignores_defender_effects(attacker, attack_index, game_state)
	var ignore_weakness: bool = effect_processor.attack_ignores_weakness(attacker, attack_index, game_state)
	var ignore_resistance: bool = effect_processor.attack_ignores_resistance(attacker, attack_index, game_state)
	if not ignore_defender_effects and effect_processor.is_damage_prevented_by_defender_ability(attacker, defender, game_state):
		return 0
	var atk_mod: int = effect_processor.get_attack_damage_modifier(attacker, defender, attack, game_state, targets)
	var atk_self_mod: int = effect_processor.get_attacker_modifier(attacker, game_state)
	var def_mod: int = 0 if ignore_defender_effects else effect_processor.get_defender_modifier(defender, game_state, attacker)
	return damage_calculator.calculate_damage(
		attacker,
		defender,
		attack,
		game_state,
		atk_mod,
		atk_self_mod,
		def_mod,
		ignore_weakness,
		ignore_resistance
	)


## 招式使用后的流程
func _after_attack(player_index: int) -> void:
	_enter_phase(GameState.GamePhase.POKEMON_CHECK)
	_do_pokemon_check()
	_clear_expired_attack_markers()


func _discard_expired_tools() -> void:
	for player: PlayerState in game_state.players:
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot == null or slot.attached_tool == null:
				continue
			var tool_effect: BaseEffect = effect_processor.get_effect(slot.attached_tool.card_data.effect_id)
			if tool_effect == null or not tool_effect.has_method("discard_at_end_of_turn"):
				continue
			if not bool(tool_effect.call("discard_at_end_of_turn", slot, game_state)):
				continue
			player.discard_pile.append(slot.attached_tool)
			slot.attached_tool = null


func _get_knockout_prize_count(slot: PokemonSlot) -> int:
	var prize_count: int = slot.get_prize_count()
	for effect: Dictionary in slot.effects:
		if effect.get("type", "") == "extra_prize":
			prize_count += int(effect.get("count", 0))
	var modifier: int = effect_processor.get_knockout_prize_modifier(slot, game_state)
	prize_count += modifier
	return maxi(0, prize_count)


func _clear_expired_attack_markers() -> void:
	for player: PlayerState in game_state.players:
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot == null or slot.is_knocked_out():
				continue
			var remaining_effects: Array[Dictionary] = []
			for effect: Dictionary in slot.effects:
				if effect.get("type", "") == "extra_prize" and effect.get("source", "") == "attack":
					continue
				remaining_effects.append(effect)
			slot.effects = remaining_effects


# ===================== 胜负判定 =====================

## 检查胜利条件，返回获胜玩家索引，-1表示未结束
func _check_win_condition() -> int:
	for pi: int in 2:
		var player: PlayerState = game_state.players[pi]
		# 拿完奖赏卡获胜
		if player.prizes.is_empty() and game_state.turn_number > 0:
			_trigger_game_over(pi, "拿完奖赏卡")
			return pi

	for pi: int in 2:
		var player: PlayerState = game_state.players[pi]
		# 无宝可梦在场且无备战区宝可梦
		if player.active_pokemon == null and player.bench.is_empty():
			_trigger_game_over(1 - pi, "对手无宝可梦")
			return 1 - pi

	return -1


func _trigger_game_over(winner_index: int, reason: String) -> void:
	_enter_phase(GameState.GamePhase.GAME_OVER)
	game_state.set_game_over(winner_index, reason)
	_log_action(GameAction.ActionType.GAME_END, winner_index,
		{"reason": reason}, "游戏结束，玩家%d获胜（%s）" % [winner_index, reason])
	game_over.emit(winner_index, reason)


# ===================== 工具方法 =====================

func _enter_phase(phase: GameState.GamePhase) -> void:
	game_state.phase = phase
	state_changed.emit(phase)


func _log_action(
	action_type: GameAction.ActionType,
	player_index: int,
	data: Dictionary,
	description: String
) -> void:
	var action: GameAction = GameAction.create(
		action_type, player_index, data, game_state.turn_number, description
	)
	action_log.append(action)
	action_logged.emit(action)


## 获取当前游戏状态（只读引用）
func get_state() -> GameState:
	return game_state


## 获取完整操作日志
func get_action_log() -> Array[GameAction]:
	return action_log


func _should_end_turn_after_ability(player_index: int, pokemon: PokemonSlot, ability_index: int) -> bool:
	if ability_index != 0 or pokemon == null:
		return false
	for effect_data: Dictionary in pokemon.effects:
		if effect_data.get("type", "") != "ability_end_turn_draw_triggered":
			continue
		if effect_data.get("turn", -1) != game_state.turn_number:
			continue
		if effect_data.get("player", player_index) != player_index:
			continue
		return true
	return false


func use_ability(
	player_index: int,
	pokemon: PokemonSlot,
	ability_index: int = 0,
	targets: Array = []
) -> bool:
	if game_state.current_player_index != player_index:
		return false
	if game_state.phase != GameState.GamePhase.MAIN:
		return false
	if pokemon == null or pokemon.get_top_card() == null:
		return false
	var top: CardInstance = pokemon.get_top_card()
	if top.owner_index != player_index:
		return false
	if not effect_processor.can_use_ability(pokemon, game_state, ability_index):
		return false

	var ability_name: String = effect_processor.get_ability_name(pokemon, ability_index, game_state)
	if not effect_processor.execute_ability_effect(pokemon, ability_index, targets, game_state):
		return false

	_log_action(GameAction.ActionType.USE_ABILITY, player_index,
		{"pokemon_name": pokemon.get_pokemon_name(), "ability_name": ability_name},
		"Used ability: %s" % ability_name)
	if _resolve_mid_turn_knockouts():
		return true
	if _should_end_turn_after_ability(player_index, pokemon, ability_index):
		end_turn(player_index)
	return true
