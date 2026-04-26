class_name LLMTurnPlanPromptBuilder
extends RefCounted

const LLMDecisionTreeExecutorScript = preload("res://scripts/ai/LLMDecisionTreeExecutor.gd")
const LLMDeckCapabilityExtractorScript = preload("res://scripts/ai/LLMDeckCapabilityExtractor.gd")
const LLMRouteCandidateBuilderScript = preload("res://scripts/ai/LLMRouteCandidateBuilder.gd")

const SCHEMA_VERSION := "llm_decision_tree_v1"
const ACTION_ID_SCHEMA_VERSION := "llm_action_id_tree_v1"
const FAST_CHOICE_SCHEMA_VERSION := "llm_fast_choice_v1"

const VALID_ACTION_TYPES: Array[String] = [
	"play_basic_to_bench", "attach_energy", "attach_tool", "evolve",
	"play_trainer", "play_stadium", "use_ability", "retreat", "attack", "end_turn",
]

const EFFECT_ID_RULE_TAGS := {
	"1af63a7e2cb7a79215474ad8db8fd8fd": ["search_deck", "bench_related", "pokemon_related"],
	"70d14b4a5a9c15581b8a0c8dfd325717": ["draw", "discard", "filter_engine", "productive_engine"],
	"e366f56ecd3f805a28294109a1a37453": ["search_deck", "energy_related", "discard"],
	"3e6f1daf545dfed48d0588dd50792a2e": ["recover_to_hand", "energy_related", "pokemon_related"],
	"651276c51911345aa091c1c7b87f3f4f": ["energy_related", "supporter_related", "energy_acceleration"],
	"8538726d6cdfad2fa3ca5f4b462c12c5": ["energy_related", "recover_to_hand"],
	"409898a79b38fe8ca279e7bdaf4fd52e": ["energy_related", "draw", "ability_engine", "charge_engine", "safe_pre_attack", "productive_engine"],
	"768b545a38fccd5e265093b5adce10af": ["search_deck", "supporter_related"],
	"a337ed34a45e63c6d21d98c3d8e0cb6e": ["search_deck", "discard"],
	"d3891abcfe3277c8811cde06741d3236": ["evolution"],
	"8e1fa2c9018db938084c94c7c970d419": ["gust"],
	"4ec261453212280d0eb03ed8254ca97f": ["gust", "switch_or_retreat"],
	"8342fe3eeec6f897f3271be1aa26a412": ["switch_or_retreat"],
	"d1c2f018a644e662f2b6895fdfc29281": ["tool_modifier", "hp_boost", "basic_pokemon_only"],
}

var _capability_extractor: RefCounted = LLMDeckCapabilityExtractorScript.new()
var _route_candidate_builder: RefCounted = LLMRouteCandidateBuilderScript.new()
var _deck_strategy_id: String = ""
var _deck_strategy_prompt: PackedStringArray = PackedStringArray()


func set_deck_strategy_prompt(strategy_id: String, prompt_lines: PackedStringArray) -> void:
	_deck_strategy_id = strategy_id
	_deck_strategy_prompt = prompt_lines


func build_request_payload(game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	var opponent_index: int = 1 - player_index
	var opponent: PlayerState = game_state.players[opponent_index] if opponent_index >= 0 and opponent_index < game_state.players.size() else null
	var payload := {
		"system_prompt_version": SCHEMA_VERSION,
		"response_format": response_schema(),
		"instructions": instructions(),
		"game_state": _serialize_game_state(game_state, player, opponent, player_index),
		"deck_capabilities": _capability_extractor.call("extract_for_player", player),
	}
	if _deck_strategy_id != "" or not _deck_strategy_prompt.is_empty():
		payload["deck_strategy_id"] = _deck_strategy_id
		payload["deck_strategy_prompt"] = _deck_strategy_prompt
	return payload


func build_action_id_request_payload(
	game_state: GameState,
	player_index: int,
	legal_actions: Array
) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	var opponent_index: int = 1 - player_index
	var opponent: PlayerState = game_state.players[opponent_index] if opponent_index >= 0 and opponent_index < game_state.players.size() else null
	var summarized_actions: Array[Dictionary] = summarize_legal_actions(legal_actions, game_state, player_index)
	_annotate_resource_conflicts(summarized_actions, player)
	var future_actions: Array[Dictionary] = _future_action_refs(game_state, player, player_index, summarized_actions)
	var prompt_actions: Array[Dictionary] = summarized_actions.duplicate(true)
	prompt_actions.append_array(future_actions)
	var legal_action_groups: Dictionary = _legal_action_groups(summarized_actions)
	var future_action_groups: Dictionary = _legal_action_groups(future_actions)
	var turn_tactical_facts: Dictionary = _turn_tactical_facts(game_state, player, player_index, summarized_actions, legal_action_groups, future_actions)
	var candidate_routes: Array[Dictionary] = _route_candidate_builder.call("build_candidate_routes", summarized_actions, future_actions, turn_tactical_facts)
	var payload := {
		"system_prompt_version": ACTION_ID_SCHEMA_VERSION,
		"response_format": action_id_response_schema(),
		"instructions": action_id_instructions(),
		"game_state": _serialize_compact_game_state(game_state, player, opponent, player_index),
		"legal_actions": prompt_actions,
		"currently_legal_actions": summarized_actions,
		"future_actions": future_actions,
		"legal_action_groups": legal_action_groups,
		"future_action_groups": future_action_groups,
		"turn_tactical_facts": turn_tactical_facts,
		"candidate_routes": candidate_routes,
		"decision_tree_contract": _decision_tree_contract(),
	}
	if _deck_strategy_id != "":
		payload["deck_strategy_id"] = _deck_strategy_id
	var compact_hints: PackedStringArray = _compact_deck_strategy_prompt()
	if not compact_hints.is_empty():
		payload["deck_strategy_hints"] = compact_hints
	return payload


func build_fast_choice_payload(
	game_state: GameState,
	player_index: int,
	prompt_kind: String,
	candidates: Array[Dictionary]
) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	var opponent_index: int = 1 - player_index
	var opponent: PlayerState = game_state.players[opponent_index] if opponent_index >= 0 and opponent_index < game_state.players.size() else null
	var payload := {
		"system_prompt_version": FAST_CHOICE_SCHEMA_VERSION,
		"response_format": fast_choice_response_schema(),
		"instructions": fast_choice_instructions(),
		"max_tokens": 140,
		"fast_choice_context": {
			"prompt_kind": prompt_kind,
			"player_index": player_index,
			"turn_number": int(game_state.turn_number),
			"candidates": candidates,
			"rule": "Return selected_index from the candidates array. For setup, also return bench_indices in desired bench order.",
		},
		"game_state": _serialize_game_state(game_state, player, opponent, player_index),
		"deck_capabilities": _capability_extractor.call("extract_for_player", player),
	}
	if _deck_strategy_id != "" or not _deck_strategy_prompt.is_empty():
		payload["deck_strategy_id"] = _deck_strategy_id
		payload["deck_strategy_prompt"] = _deck_strategy_prompt
	return payload


func parse_fast_choice_response(response: Dictionary) -> Dictionary:
	if response.has("status") and str(response.get("status", "")) == "error":
		return {}
	var result := {
		"selected_index": int(response.get("selected_index", -1)),
		"bench_indices": [],
		"reasoning": str(response.get("reasoning", "")),
	}
	var raw_bench: Variant = response.get("bench_indices", [])
	if raw_bench is Array:
		var bench_indices: Array[int] = []
		for raw_index: Variant in raw_bench:
			bench_indices.append(int(raw_index))
		result["bench_indices"] = bench_indices
	return result


func parse_llm_response_to_decision_tree(response: Dictionary) -> Dictionary:
	var raw_tree: Variant = response.get("decision_tree", {})
	if raw_tree is Dictionary and (raw_tree.has("actions") or raw_tree.has("branches") or raw_tree.has("children") or raw_tree.has("fallback_actions")):
		return raw_tree.duplicate(true)
	var legacy_actions: Array[Dictionary] = parse_llm_response_to_action_queue(response)
	if not legacy_actions.is_empty():
		return {"actions": legacy_actions}
	return {}


func summarize_legal_actions(
	legal_actions: Array,
	game_state: GameState,
	player_index: int
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw_action: Variant in legal_actions:
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		var ref: Dictionary = legal_action_reference(action, game_state, player_index)
		var action_id: String = str(ref.get("id", ""))
		if action_id == "" or bool(seen.get(action_id, false)):
			continue
		seen[action_id] = true
		result.append(ref)
	return result


func legal_action_reference(action: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	var kind: String = str(action.get("kind", ""))
	var action_id: String = action_id_for_action(action, game_state, player_index)
	var ref := {
		"id": action_id,
		"type": kind,
		"summary": kind,
		"requires_interaction": bool(action.get("requires_interaction", false)),
	}
	var card: Variant = action.get("card")
	if card is CardInstance and (card as CardInstance).card_data != null:
		var cd: CardData = (card as CardInstance).card_data
		ref["card"] = _best_card_name(cd)
		ref["card_type"] = str(cd.card_type)
		ref["card_rules"] = _card_rule_summary(cd, kind)
		if cd.is_energy():
			ref["energy_type"] = _energy_word(str(cd.energy_provides))
	var target_slot: Variant = action.get("target_slot")
	if target_slot is PokemonSlot:
		ref["target"] = str((target_slot as PokemonSlot).get_pokemon_name())
		ref["position"] = _resolve_slot_position(target_slot as PokemonSlot, game_state, player_index)
	var source_slot: Variant = action.get("source_slot")
	if source_slot is PokemonSlot:
		ref["pokemon"] = str((source_slot as PokemonSlot).get_pokemon_name())
		ref["position"] = _resolve_slot_position(source_slot as PokemonSlot, game_state, player_index)
		var source_cd: CardData = (source_slot as PokemonSlot).get_card_data()
		if source_cd != null:
			ref["card_rules"] = _card_rule_summary(source_cd, kind)
	if kind == "use_ability":
		ref["ability_index"] = int(action.get("ability_index", -1))
		ref["ability"] = _ability_name_for_action(action)
		ref["ability_rules"] = _ability_rule_summary(action)
	if kind in ["attack", "granted_attack"]:
		ref["attack_index"] = int(action.get("attack_index", -1))
		ref["attack_name"] = _attack_name_for_action(action, game_state, player_index)
		ref["attack_rules"] = _attack_rule_summary(action, game_state, player_index)
		ref["attack_quality"] = _attack_quality_summary(ref.get("attack_rules", {}), int(ref.get("attack_index", -1)))
	if kind == "retreat":
		var bench_slot: Variant = action.get("bench_target")
		if bench_slot is PokemonSlot:
			ref["bench_target"] = str((bench_slot as PokemonSlot).get_pokemon_name())
			ref["bench_position"] = _resolve_slot_position(bench_slot as PokemonSlot, game_state, player_index)
		ref["discard_energy_count"] = (action.get("energy_to_discard", []) as Array).size() if action.get("energy_to_discard", []) is Array else 0
	_annotate_action_resource_use(ref, action, game_state, player_index)
	if _ref_rule_tags_require_interaction(ref):
		ref["requires_interaction"] = true
	if bool(ref.get("requires_interaction", false)):
		ref["interaction_schema"] = _interaction_schema_for_ref(ref)
	ref["summary"] = _legal_action_summary(ref)
	return ref


func action_id_for_action(action: Dictionary, game_state: GameState, player_index: int) -> String:
	var kind: String = str(action.get("kind", ""))
	match kind:
		"attach_energy", "attach_tool", "evolve":
			return "%s:%s:%s" % [kind, _card_instance_token(action.get("card")), _slot_token(action.get("target_slot"), game_state, player_index)]
		"play_basic_to_bench", "play_trainer", "play_stadium":
			return "%s:%s" % [kind, _card_instance_token(action.get("card"))]
		"use_ability":
			return "%s:%s:%d" % [kind, _slot_token(action.get("source_slot"), game_state, player_index), int(action.get("ability_index", -1))]
		"retreat":
			return "%s:%s:%s" % [kind, _slot_token(action.get("bench_target"), game_state, player_index), _card_list_token(action.get("energy_to_discard", []))]
		"attack", "granted_attack":
			return "%s:%d:%s" % [kind, int(action.get("attack_index", -1)), _attack_name_for_action(action, game_state, player_index).to_lower()]
		"end_turn":
			return "end_turn"
	return kind


func parse_llm_response_to_action_queue(response: Dictionary) -> Array[Dictionary]:
	var raw_actions: Variant = response.get("actions", [])
	if not (raw_actions is Array):
		return []
	var executor: RefCounted = LLMDecisionTreeExecutorScript.new()
	return executor.call("normalize_actions", raw_actions)


func instructions() -> PackedStringArray:
	return PackedStringArray([
		"You are the strategy planner for the current deck. Think once per turn and return one decision_tree for the entire turn.",
		"The engine will not wait for another LLM response during this turn. After each action, the rule executor reads the latest game_state and selects an executable branch from your decision_tree.",
		"Every card name, Pokemon name, attack name, ability name, energy type, and target must be copied from game_state, deck_capabilities, or deck_strategy_prompt. Do not translate names or invent aliases.",
		"Read deck_capabilities. It lists the real actions, interaction ids, and strategic roles produced by the cards in this deck. Do not invent interaction ids outside deck_capabilities.",
		"Read deck_strategy_prompt when present. It contains deck-specific strategic priorities and common decision-tree branches.",
		"game_state.battle_context_schema is battle_context_v2. Use it as the source of truth.",
		"my_field contains exact information for the AI player: active, bench, grouped hand, hand_count, deck_count, discard_pile, lost_zone, prizes_remaining, and energy_in_hand.",
		"opponent_field contains public opponent board information plus opponent hand_count. It intentionally does not contain opponent hand cards.",
		"Each Pokemon slot contains name/name_en, position, stage, mechanic, tags, HP, damage_counters, attached_energy, attached_energy_cards, attached_tool, retreat_cost, weakness, resistance, status_conditions, active_statuses, effects, attacks, and abilities.",
		"game_state.stadium contains the current stadium card and owner_index. game_state.turn_flags contains energy/supporter/stadium/retreat usage, VSTAR usage, knockout timing, and shared turn flags.",
		"Always consider opponent active HP and damage, opponent bench threats, opponent energy/tool/status, opponent prizes_remaining, and opponent hand_count.",
		"If a higher-damage attack is available and meets the energy condition, choose it over a weaker attack unless the weaker attack has a specific strategic effect.",
		"Preserve the next turn: do not empty the hand for a board that cannot attack or survive unless it wins immediately.",
		"Use action.interactions for every search, discard, energy assignment, damage placement, switch, or self-KO effect.",
		"Return a decision_tree object. A node may contain actions, branches, and fallback_actions. Use branches to cover post-search, post-draw, and post-discard outcomes because the executor will not ask the LLM again this turn.",
		"Only use supported branch facts: always, can_attack, can_use_supporter, energy_not_attached, energy_attached_this_turn, supporter_not_used, supporter_used_this_turn, retreat_not_used, retreat_used_this_turn, hand_has_card, discard_has_card, hand_has_type, discard_basic_energy_count_at_least, active_has_energy_at_least, active_attack_ready, has_bench_space.",
		"Every action object must include all schema fields. Put an empty string in unused string fields and an empty object in unused interactions.",
	])


func _legacy_instructions_unused() -> PackedStringArray:
	return PackedStringArray([
		"You are the strategy planner for the current deck. Think once per turn and return one decision_tree for the entire turn.",
		"The engine will not wait for another LLM response during this turn. After each action, the rule executor reads the latest game_state and selects an executable branch from your decision_tree.",
		"Every card name, Pokemon name, attack name, ability name, energy type, and target must be copied from game_state or deck_capabilities. Do not translate names or invent aliases.",
		"Read deck_capabilities. It lists the real actions, interaction ids, and strategic roles produced by the cards in this deck. Do not invent interaction ids outside deck_capabilities.",
		"game_state.battle_context_schema is battle_context_v2. Use it as the source of truth.",
		"my_field contains exact information for the AI player: active, bench, grouped hand, hand_count, deck_count, discard_pile, lost_zone, prizes_remaining, and energy_in_hand.",
		"opponent_field contains public opponent board information plus opponent hand_count. It intentionally does not contain opponent hand cards.",
		"Each Pokemon slot contains name/name_en, position, stage, mechanic, tags, HP, damage_counters, attached_energy, attached_energy_cards, attached_tool, retreat_cost, weakness, resistance, status_conditions, active_statuses, effects, attacks, and abilities.",
		"game_state.stadium contains the current stadium card and owner_index. game_state.turn_flags contains energy/supporter/stadium/retreat usage, VSTAR usage, knockout timing, and shared turn flags.",
		"Always consider opponent active HP and damage, opponent bench threats, opponent energy/tool/status, opponent prizes_remaining, and opponent hand_count.",
		"If a higher-damage attack is available and meets the energy condition, choose it over a weaker attack unless the weaker attack has a specific strategic effect.",
		"Preserve the next turn: do not empty the hand for a board that cannot attack or survive unless it wins immediately.",
		"Use action.interactions for every search, discard, energy assignment, damage placement, switch, or self-KO effect.",
		"Return a decision_tree object. A node may contain actions, branches, and fallback_actions. Use branches to cover post-search, post-draw, and post-discard outcomes because the executor will not ask the LLM again this turn.",
		"Only use supported branch facts: always, can_attack, can_use_supporter, energy_not_attached, energy_attached_this_turn, supporter_not_used, supporter_used_this_turn, retreat_not_used, retreat_used_this_turn, hand_has_card, discard_has_card, hand_has_type, discard_basic_energy_count_at_least, active_has_energy_at_least, active_attack_ready, has_bench_space.",
		"Every action object must include all schema fields. Put an empty string in unused string fields and an empty object in unused interactions.",
		"你是当前卡组的策略AI。你的任务是每回合只思考一次，返回一棵本回合决策树。",
		"系统不会在本回合中再次等待LLM；后续每一步由规则模型读取最新game_state，在你的decision_tree里选择可执行分支。",
		"你给出的每一步操作必须精确到具体卡牌名、具体能量类型、具体目标。卡牌名必须从game_state里的name或name_en字段复制，禁止自己翻译或发明别名。",
		"必须阅读deck_capabilities。它列出了当前卡组真实卡牌可产生的actions、interactions和roles。不要生成deck_capabilities之外的interaction id。",
		"",
		"## 卡组核心链路",
		"用手牌中实际存在的检索/弃牌道具把基础能量送入弃牌堆 → 用手牌中实际存在的能量加速支援者从弃牌堆贴能到主攻击手 → 用game_state.active.attacks里的真实攻击名攻击。",
		"",
		"## 回合限制（必须检查game_state中的标志）",
		"- is_first_turn=true且going_first=true时：不能使用支援者卡，不能攻击！只能下场宝可梦、贴能量、使用特性、使用道具。",
		"- can_use_supporter=false时：不要规划任何支援者卡。",
		"- can_attack=false时：不要规划attack，最后用end_turn结束。",
		"- energy_attached_this_turn=true时：本回合已贴过能量，不要再规划attach_energy。",
		"- supporter_used_this_turn=true时：本回合已用过支援者，不要再规划支援者卡。",
		"- retreat_used_this_turn=true时：本回合已撤退过，不要再规划retreat。",
		"",
		"## 对手场面分析（必须考虑）",
		"- 查看opponent_field中对手的前场宝可梦(active)：HP、已贴能量、攻击招式和伤害",
		"- 查看对手后备(bench)：有哪些威胁宝可梦在充能",
		"- 根据对手的奖赏卡数(prize_count)判断局势：对手剩1-2张奖赏 = 即将获胜，需要加速",
		"- 计算我方攻击能否击倒对手前场，决定是否需要先充能再攻击",
		"",
		"## 卡组关键规则",
		"- 每回合只能使用1张支援者(Supporter)卡。如果手牌里有从弃牌堆给远古宝可梦贴能量的支援者，且弃牌堆≥2基础能量，绝不能把支援者位浪费给抽牌支援者。",
		"- 每回合只能手动贴1次能量。优先贴给能量缺口最小、最可能本回合攻击的主攻击手。",
		"- 主攻击会弃掉指定能量时，尽量用能量加速贴非关键消耗能量，手动贴攻击所需的关键能量。",
		"- 如果场上有弃1能量抽2牌的特性，优先弃基础能量来填充弃牌堆。",
		"- 如果场上有自带贴能特性的宝可梦，可以使用该特性；它和每回合手动贴能量不冲突。",
		"",
		"## 返回格式",
		"返回decision_tree对象。每个节点可包含actions、branches、fallback_actions。",
		"actions是在进入该节点后优先尝试的有序动作；branches按顺序匹配，第一个when条件全部满足的分支生效；fallback_actions是在没有分支匹配时使用的动作。",
		"每条分支可以包含actions，也可以包含then子节点继续细分。",
		"",
		"## 动作类型和必填字段",
		"",
		"attach_energy — 手动贴能量（每回合限1次）",
		"  必填: energy_type(Lightning/Fighting/Grass), target(宝可梦名), position(active/bench_0/bench_1)",
		"  energy_type留空的指令会被丢弃！你必须明确指定贴哪种能量。",
		"",
		"attack — 使用前场宝可梦的攻击",
		"  必填: attack_name(从game_state的attacks数组复制name字段)",
		"  attack_name留空可能选错技能！",
		"",
		"use_ability — 使用宝可梦特性",
		"  必填: pokemon(宝可梦名), ability(从game_state的abilities数组复制name字段)",
		"",
		"play_trainer — 打出训练师/支援者/道具卡",
		"  必填: card(完整卡牌名)",
		"  如果该卡需要弃牌，填discard_choice(弃什么，逗号分隔)",
		"  如果该卡需要搜索，填search_target(搜什么，逗号分隔)",
		"  更复杂的卡牌效果必须填interactions，例如 {\"search_item\":{\"prefer\":[\"神奇糖果\"]},\"search_tool\":{\"prefer\":[\"森林封印石\"]}}",
		"",
		"play_basic_to_bench — 下场基础宝可梦",
		"  必填: card(宝可梦名)",
		"",
		"evolve — 进化宝可梦",
		"  必填: card(进化卡名), target(被进化的宝可梦名), position",
		"",
		"retreat — 撤退换人",
		"  必填: bench_target(换上来的宝可梦名), bench_position",
		"  建议填: discard_energy_type(优先弃哪种能量)",
		"",
		"end_turn — 结束回合",
		"",
		"## 训练师卡操作示范",
		"{type:play_trainer, card:\"<从game_state.my_field.hand复制的完整name或name_en>\", discard_choice:\"<从手牌复制要弃的卡名>\", search_target:\"<要搜索的卡名或能量类型>\"}",
		"{type:play_trainer, card:\"<从game_state.my_field.hand复制的完整name或name_en>\", search_target:\"<从弃牌堆或卡组选择的真实卡名>\", target:\"<从my_field复制的宝可梦名>\", position:\"active\"}",
		"{type:play_trainer, card:\"<神奇糖果的真实name/name_en>\", interactions:{\"stage2_card\":{\"prefer\":[\"<二阶进化卡名>\"]},\"target_pokemon\":{\"prefer\":[\"<基础宝可梦名>\"]}}}",
		"{type:use_ability, pokemon:\"<黑夜魔灵或大比鸟等真实name/name_en>\", ability:\"<从abilities复制name>\", interactions:{\"self_ko_target\":{\"prefer\":[\"<对手宝可梦名>\"]},\"search_cards\":{\"prefer\":[\"<要找的卡名>\"]}}}",
		"示范中的尖括号只是占位说明，真实返回禁止包含尖括号，必须填game_state中存在的真实名称。",
		"",
		"## 决策树条件",
		"when只能使用规则模型支持的结构化条件，禁止自然语言条件。",
		"支持的fact: always, can_attack, can_use_supporter, energy_not_attached, energy_attached_this_turn, supporter_not_used, supporter_used_this_turn, retreat_not_used, retreat_used_this_turn, hand_has_card, discard_has_card, hand_has_type, discard_basic_energy_count_at_least, active_has_energy_at_least, active_attack_ready, has_bench_space。",
		"条件示例: {\"fact\":\"hand_has_card\",\"card\":\"<从手牌复制name或name_en>\"}",
		"条件示例: {\"fact\":\"discard_basic_energy_count_at_least\",\"count\":2}",
		"条件示例: {\"fact\":\"active_attack_ready\",\"attack_name\":\"<从active.attacks复制name>\"}",
		"",
		"## 卡牌能力约束",
		"- 如果deck_capabilities里某张卡有interactions，使用该卡时必须在action.interactions里写清楚对应交互意图。",
		"- 检索类卡必须说明search_*优先目标；弃牌成本必须说明discard_*策略；能量分配必须说明energy_assignments或对应专用assignment策略。",
		"- Stage 2/神奇糖果路线必须同时考虑stage2_card和target_pokemon。",
		"- 放置/移动伤害指示物必须指定self_ko_target、counter_distribution、source_pokemon/target_pokemon等交互意图。",
		"",
		"## 分支处理",
		"- 搜索、抽牌、弃牌后的结果要用branches覆盖：例如搜到关键卡、没搜到关键卡、已用支援者、还没贴能。",
		"- 每个关键动作后都要考虑下一步局面可能已经变化，靠then里的子分支处理，不要依赖再次请求LLM。",
		"- fallback_actions必须保守合法，通常是补能、攻击或end_turn。",
		"",
		"## 格式要求",
		"- 每个动作对象必须包含所有字段，不需要的字段填空字符串\"\"",
		"  全部字段: type, card, energy_type, target, position, pokemon, ability, bench_target, bench_position, attack_name, discard_energy_type, search_target, discard_choice, interactions",
		"- card/pokemon/target字段必须使用game_state中显示的完整name；如果你用英文，必须是同一张卡JSON里的name_en",
		"- 当多只同名宝可梦在场时，用position字段区分(active/bench_0/bench_1)",
		"- reasoning用一句话解释本回合策略",
	])


func response_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": false,
		"required": ["decision_tree", "reasoning"],
		"properties": {
			"decision_tree": _decision_tree_schema(),
			"reasoning": {"type": "string", "maxLength": 300},
		},
	}


func fast_choice_response_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": false,
		"required": ["selected_index", "bench_indices", "reasoning"],
		"properties": {
			"selected_index": {"type": "integer"},
			"bench_indices": {
				"type": "array",
				"maxItems": 5,
				"items": {"type": "integer"},
			},
			"reasoning": {"type": "string", "maxLength": 160},
		},
	}


func fast_choice_instructions() -> PackedStringArray:
	return PackedStringArray([
		"You are making a fast non-turn-chain choice, not planning a full turn.",
		"Do not produce a decision_tree. Return one JSON object only.",
		"Choose only from fast_choice_context.candidates by integer index.",
		"For setup_active, selected_index is the hand index of the Active Pokemon. bench_indices is the ordered list of Basic Pokemon hand indices to place on Bench.",
		"For send_out, selected_index is the bench index to promote to Active. bench_indices should be empty.",
		"Use game_state only for quick public context: current board, opponent active, prize race, and energy/status/tool information.",
		"Use deck_strategy_prompt for deck-specific priorities, but answer quickly. This prompt is for a 1-of-N choice, not a multi-step play sequence.",
		"Prefer a ready attacker or intended lead for send_out. Do not send out fragile engine Pokemon if a real attacker or pivot is available.",
		"Prefer the deck's intended opener for setup Active, then bench core engines before optional support basics.",
	])


func action_id_instructions() -> PackedStringArray:
	return PackedStringArray([
		"Return one route-style priority-ordered decision_tree from legal_actions only. Use ids exactly; do not invent ids.",
		"Read candidate_routes first. If a candidate route matches the turn, prefer using its route_action_id as a single branch action, for example {\"id\":\"route:primary_visible_engine\"}; the runtime expands it into exact currently legal action refs.",
		"If turn_tactical_facts.gust_ko_opportunities is non-empty, treat the first listed opportunity as a top-priority prize route; use its route_action_id when candidate_routes exposes one, otherwise use the listed gust_action_id with selection_policy.opponent_bench_target followed by attack_action_id.",
		"If no candidate route fits, build a route from exact legal_actions ids directly. Do not mix a candidate route id with duplicated copies of the same route actions.",
		"legal_actions contains currently_legal_actions plus future_actions. currently_legal_actions are executable now. future_actions are standardized ids that may become executable after earlier same-turn setup such as attach, switch, retreat, search, or draw.",
		"This must be a decision tree, not a serial script. Branches are checked in array order and only the first matching route executes.",
		"Hard contract: every branch condition object must use {\"fact\":\"<supported_fact>\"}. Never use condition, label, natural-language predicates, or made-up facts.",
		"Hard contract: hand_has_card and discard_has_card must include card/name. hand_has_type must include card_type or energy_type. active_attack_ready must include attack_name copied from legal_actions/game_state.",
		"Hard contract: do not use can_attack as the first attack route. can_attack only means the phase permits attacking; attack-first routes must use active_attack_ready.",
		"Hard contract: if the only ready attack is a hand-discard redraw/setup attack and turn_tactical_facts says the primary deck attack is reachable through visible search/setup, do not choose the redraw attack as the first branch.",
		"Hard contract: if a route has active_attack_ready, or uses attack-enabling setup actions such as acceleration, resource search, charge abilities, pivot, or attach_energy to active, and an attack legal_action exists, that route must include an attack action before end_turn.",
		"Hard contract: every action must be {\"id\":\"<exact legal_actions[].id>\"}. Never invent ids such as attack_active_index_1 or use_supporter:Card Name.",
		"Hard contract: a single route may contain at most one manual attach_energy action because only one manual attachment is allowed per turn.",
		"Hard contract: interactions must match the exact card_rules and interaction_hints for that legal action. Do not copy an interaction shape from a different card.",
		"Preferred contract: for card-specific choices, provide selection_policy with human strategic intent, and only add low-level interactions when legal_action.interaction_schema names the exact key. The executor will compile selection_policy to deterministic interaction picks.",
		"Examples: selection_policy.resource='basic_grass_energy_from_hand' for Ogerpon; selection_policy.discard='expendable_energy_or_duplicate_basic' and selection_policy.search=['Fighting Energy'] for Earthen Vessel; selection_policy.assignments for Sada-like acceleration.",
		"For Sada-like acceleration, read turn_tactical_facts.sada_assignment_recommendations and prefer Energy types that fill the target Pokemon's missing attack cost; do not attach off-type Energy to a primary attacker when Lightning/Fighting or another listed missing cost is available.",
		"For non-trivial turns, build route slots in this order when legal_actions contain them: primary_damage attack-now, safe setup/tool/charge before attack, supporter engine, search/resource engine, ability engine, pivot/gust, manual attach, preserve-hand fallback. Low-priority redraw/setup attacks belong near fallback, not first.",
		"Each route may contain up to 8 actions. Put attack near the end after safe setup/charge/tool actions that do not consume or block the attack.",
		"Bad->good: active_attack_ready -> end_turn is invalid; active_attack_ready -> optional safe setup/tool/charge ids -> exact attack id is correct.",
		"Bad->good: attack-only while bench/search/charge actions are safe is too shallow; include those safe actions before attack when they improve prize pressure, survival, or next turn without losing the attack.",
		"Use only visible game_state and legal_actions. Do not assume hidden deck, prizes, or opponent hand contents.",
		"Read deck_strategy_hints when present. They contain the deck-specific turn shape and must override generic tempo habits.",
		"Read turn_tactical_facts before deck_strategy_hints. Current legal actions and tactical facts override generic deck templates; if primary_attack_ready is false, build setup/search/attach routes toward primary_attack_name instead of using a low-value ready redraw attack.",
		"If replan_context is present, this is a same-turn replan after draw/search/discard changed the hand. Re-evaluate the new legal_actions and current hand instead of continuing the old route.",
		"Read each legal_action.card_rules, ability_rules, attack_rules, and interaction_hints. These are generated from the real card JSON and explain what every currently playable card can do.",
		"Read legal_action.consumes_hand_card_ids, may_consume_hand_energy_symbols, and resource_conflicts. Do not put two resource-conflicting actions in the same route unless an earlier draw/search branch can replace the consumed resource.",
		"Use legal_action_groups to ensure you considered attack, manual attach, engine/draw, search/setup, pivot/gust, and fallback actions.",
		"Use future_actions to close a route when a currently illegal attack/retreat can become legal after prior actions. Do not use future_actions as the first step unless its prerequisite is already satisfied.",
		"If future_actions includes future:attach_after_search and future:attack_after_search_attach, a legal search action can create the missing Energy route; prefer that over a low-value redraw attack.",
		"If turn_tactical_facts.manual_attach_enables_primary_attack is true, prefer the exact best_manual_attach_to_primary_attack_action_id route before draw/filter abilities such as Greninja or Shoes.",
		"If turn_tactical_facts.manual_attach_enables_best_active_attack is true, prefer best_manual_attach_to_best_active_attack_action_id followed by the resulting active attack; if best_active_attack_after_manual_attach.kos_opponent_active_after_best_manual_attach is true, treat it as a top conversion route.",
		"If turn_tactical_facts.primary_attack_reachable_after_visible_engine is true, build a route using primary_attack_route and future_actions before falling back to shallow setup actions.",
		"If turn_tactical_facts.no_deck_draw_lock is true, do not choose draw, search, discard-to-draw, or recovery churn unless it is the only legal way to avoid immediate loss.",
		"Read turn_tactical_facts.safe_pre_primary_actions. These actions can usually be inserted before the primary route when they do not consume the same resource or block the attack.",
		"Read turn_tactical_facts.productive_engine_actions. High-priority charge/draw/filter actions are not optional decoration: include them before end_turn or before a low-pressure attack when they build the board, find missing attack pieces, or increase damage without blocking the route.",
		"If a legal ability attaches Energy and draws a card, consider it before attack/search/end_turn unless resource_conflicts says it consumes the only Energy needed for manual attach.",
		"If a legal draw/filter Item is available and the primary attack is not ready or missing pieces, use it before ending the turn instead of preserving a large unplayed hand.",
		"Also consider tool_or_modifier actions before combat when they improve the active or next attacker without consuming the attack.",
		"If turn_tactical_facts.legal_survival_tool_actions is non-empty, treat those as safe pre-terminal actions for the exposed active or next attacker unless a stronger tool route is already chosen.",
		"Prefer immediate KO/high prize pressure, but if safe setup/charge actions can happen before the attack without losing the attack, include them before attacking.",
		"Resource budget: after safe setup and a winning or sufficient attack line are available, stop optional digging. Do not add draw/churn/discard actions unless they unlock attack, KO math, survival, or next-turn attacker continuity.",
		"Return JSON only. Do not output reasoning, rationale, analysis, thinking, comments, or markdown.",
		"Add interactions only when a legal action needs search/discard/assignment/gust choices and you know the exact schema key. Otherwise use selection_policy; do not invent generic interaction keys such as search or discard.",
	])


func action_id_response_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": false,
		"required": ["decision_tree"],
		"properties": {
			"decision_tree": _action_id_tree_schema(),
		},
	}


func _decision_tree_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": true,
		"properties": {
			"actions": _actions_schema(),
			"branches": {
				"type": "array",
				"maxItems": 8,
				"items": {
					"type": "object",
					"additionalProperties": true,
					"properties": {
						"when": {
							"type": "array",
							"maxItems": 5,
							"items": {"type": "object", "required": ["fact"], "additionalProperties": true},
						},
						"actions": _actions_schema(),
						"then": {"type": "object", "additionalProperties": true},
					},
				},
			},
			"fallback_actions": _actions_schema(),
		},
	}


func _action_id_tree_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": true,
		"properties": {
			"actions": _action_id_actions_schema(),
			"branches": {
				"type": "array",
				"maxItems": 8,
				"items": {
					"type": "object",
					"additionalProperties": true,
					"properties": {
						"when": {
							"type": "array",
							"maxItems": 4,
							"items": {"type": "object", "required": ["fact"], "additionalProperties": true},
						},
						"actions": _action_id_actions_schema(),
						"then": {"type": "object", "additionalProperties": true},
					},
				},
			},
			"fallback_actions": _action_id_actions_schema(),
		},
	}


func _action_id_actions_schema() -> Dictionary:
	return {
		"type": "array",
		"maxItems": 8,
		"items": {
			"type": "object",
			"required": ["id"],
			"additionalProperties": false,
			"properties": {
				"id": {"type": "string"},
				"interactions": {"type": "object", "additionalProperties": true},
				"selection_policy": {"type": "object", "additionalProperties": true},
			},
		},
	}


func _decision_tree_contract() -> Dictionary:
	return {
		"branch_selection": "first_matching_branch_only",
		"target_shape": "5-8 route branches plus fallback_actions when non-trivial",
		"priority_order": [
			"primary_damage_attack_now_if_ready_or_KO",
			"if_hand_is_strong_setup_bench_and_charge_before_attacking",
			"make_attack_ready_this_turn",
			"use_engine_search_or_draw_if_attack_not_ready",
			"setup_next_turn_without_emptying_hand",
			"fallback_preserve_resources_or_end_turn",
		],
		"route_checklist": [
			"attack_now",
			"setup_then_attack",
			"manual_attach_then_attack",
			"supporter_or_engine_then_attack",
			"search_or_resource_then_attack",
			"ability_charge_or_draw_then_attack",
			"pivot_or_gust_then_attack",
			"preserve_hand_fallback",
		],
		"required_branch_slots_when_legal": [
			"active_attack_ready: only lead with this when attack_quality is not low, otherwise prefer visible routes toward primary_attack_name",
			"supporter_engine: supporter acceleration, draw, search, or disruption before attack when it improves the route",
			"search_engine: search effects to find missing attacker, evolution, switch, tool, or energy",
			"ability_engine: draw, charge, search, damage, or switching ability when its card text advances the route",
			"pivot_gust: switch or gust only when it improves prize pressure or prevents loss",
			"manual_attach: one attach route for the smallest real attack gap",
			"preserve_hand_fallback: stop digging and end/attach safely",
		],
		"supported_facts": [
			"always",
			"can_attack",
			"can_use_supporter",
			"energy_not_attached",
			"energy_attached_this_turn",
			"supporter_not_used",
			"supporter_used_this_turn",
			"retreat_not_used",
			"retreat_used_this_turn",
			"hand_has_card",
			"discard_has_card",
			"hand_has_type",
			"discard_basic_energy_count_at_least",
			"active_has_energy_at_least",
			"active_attack_ready",
			"has_bench_space",
		],
		"invalid_examples": [
			{"bad": {"condition": "can_attack_and_ko_or_high_pressure", "value": true}, "why": "condition is not supported; use fact only"},
			{"bad": {"fact": "hand_has_card"}, "why": "hand_has_card must name the exact card"},
			{"bad": {"fact": "can_attack"}, "why": "too broad for attack-first route; use active_attack_ready with attack_name"},
			{"bad": [{"id": "<tool_or_charge_id>"}, {"id": "end_turn"}], "why": "active_attack_ready route must not end the turn without attacking"},
			{"bad": [{"id": "<attack_id>"}], "why": "too shallow when safe setup/tool/charge actions are legal before the attack"},
			{"bad": [{"id": "<attach_energy_to_active_id>"}, {"id": "end_turn"}], "why": "attack setup route must close with an attack when attack is legal"},
			{"bad": [{"id": "<ability_that_consumes_hand_resource>"}, {"id": "<attach_same_only_resource_id>"}], "why": "resource_conflicts says these actions may consume the same hand resource; split into branches or choose one"},
			{"bad": {"id": "attack_active_index_1"}, "why": "id was invented; copy exact legal_actions[].id"},
			{"bad": {"id": "use_supporter:Card Name"}, "why": "supporter id was invented; copy exact play_trainer id"},
			{"bad": {"id": "<supporter_id>", "interactions": {"search_targets": ["Energy"]}}, "why": "do not invent interaction keys; copy the shape implied by card_rules and interaction_hints"},
		],
	}


func _legal_action_groups(actions: Array[Dictionary]) -> Dictionary:
	var groups := {
		"attack": [],
		"manual_attach": [],
		"tool_or_modifier": [],
		"engine_or_draw": [],
		"search_or_setup": [],
		"pivot_or_gust": [],
		"other_play": [],
		"fallback": [],
	}
	for action: Dictionary in actions:
		var group_name: String = _legal_action_group_name(action)
		var group: Array = groups.get(group_name, [])
		if group.size() >= 8:
			continue
		var action_id: String = str(action.get("id", ""))
		if action_id == "":
			continue
		group.append(action_id)
		groups[group_name] = group
	return groups


func _legal_action_group_name(action: Dictionary) -> String:
	var kind: String = str(action.get("type", ""))
	var card_name: String = str(action.get("card", ""))
	var summary: String = str(action.get("summary", ""))
	var text := ("%s %s %s" % [kind, card_name, summary]).to_lower()
	match kind:
		"attack", "granted_attack":
			return "attack"
		"attach_energy":
			return "manual_attach"
		"attach_tool":
			return "tool_or_modifier"
		"retreat":
			return "pivot_or_gust"
		"play_basic_to_bench", "evolve":
			return "search_or_setup"
		"end_turn":
			return "fallback"
		"play_trainer", "play_stadium", "use_ability":
			if _text_has_any(text, ["boss", "catcher", "switch", "cart", "retreat", "prime catcher"]):
				return "pivot_or_gust"
			if _text_has_any(text, ["ball", "poffin", "vessel", "artazon", "candy", "search", "bench", "evolve"]):
				return "search_or_setup"
			if _text_has_any(text, ["iono", "research", "sada", "greninja", "squawkabilly", "shoes", "draw", "energy switch", "ogerpon"]):
				return "engine_or_draw"
			return "other_play"
	return "other_play"


func _text_has_any(text: String, needles: Array[String]) -> bool:
	for needle: String in needles:
		if text.contains(needle.to_lower()):
			return true
	return false


func _annotate_action_resource_use(ref: Dictionary, action: Dictionary, game_state: GameState, player_index: int) -> void:
	var kind: String = str(action.get("kind", ""))
	var card: Variant = action.get("card")
	if kind in ["attach_energy", "attach_tool", "evolve", "play_basic_to_bench", "play_trainer", "play_stadium"]:
		if card is CardInstance and _card_is_in_player_hand(card as CardInstance, game_state, player_index):
			var ci: CardInstance = card as CardInstance
			ref["consumes_hand_card_ids"] = [_card_instance_token(ci)]
			ref["consumes_hand_cards"] = [_card_resource_entry(ci)]
			if ci.card_data != null and ci.card_data.is_energy():
				ref["consumes_hand_energy_symbol"] = str(ci.card_data.energy_provides)
	if kind == "use_ability":
		var ability_consumption: Dictionary = _ability_hand_resource_consumption(action, game_state, player_index)
		if not ability_consumption.is_empty():
			for key: String in ability_consumption.keys():
				ref[key] = ability_consumption[key]
	if bool(action.get("requires_interaction", false)):
		_annotate_interaction_resource_use(ref)


func _annotate_interaction_resource_use(ref: Dictionary) -> void:
	var tags: Array[String] = _ref_rule_tags(ref)
	if "discard" in tags:
		ref["may_discard_from_hand"] = true
	if "search_deck" in tags:
		ref["may_search_deck"] = true
	if "recover_to_hand" in tags:
		ref["may_recover_to_hand"] = true


func _ability_hand_resource_consumption(action: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	var source_slot: Variant = action.get("source_slot")
	var ability_index: int = int(action.get("ability_index", -1))
	if not (source_slot is PokemonSlot):
		return {}
	var cd: CardData = (source_slot as PokemonSlot).get_card_data()
	if cd == null or ability_index < 0 or ability_index >= cd.abilities.size():
		return {}
	var ability: Dictionary = cd.abilities[ability_index]
	var text: String = ("%s %s" % [str(ability.get("name", "")), str(ability.get("text", ""))]).to_lower()
	var mentions_hand := _text_has_any(text, ["hand", "手牌"])
	var mentions_energy := _text_has_any(text, ["energy", "能量"])
	if not mentions_hand or not mentions_energy:
		return {}
	var symbols: Array[String] = []
	var source_symbol := _energy_symbol(str(cd.energy_type))
	if _text_has_any(text, ["attach", "附着"]) and source_symbol != "" and source_symbol != "N":
		symbols.append(source_symbol)
	else:
		symbols = _basic_energy_symbols_in_hand(game_state.players[player_index]) if game_state != null and player_index >= 0 and player_index < game_state.players.size() else []
	var result := {
		"may_consume_hand_energy_symbols": symbols,
		"resource_effect": "use_energy_from_hand",
	}
	if _text_has_any(text, ["discard", "弃"]):
		result["resource_effect"] = "discard_energy_from_hand"
	return result


func _annotate_resource_conflicts(actions: Array[Dictionary], player: PlayerState) -> void:
	var hand_energy_counts: Dictionary = _hand_energy_symbol_counts(player)
	for i: int in actions.size():
		var action: Dictionary = actions[i]
		var conflicts: Array[String] = []
		var exact_ids: Array[String] = _string_array(action.get("consumes_hand_card_ids", []))
		var energy_symbol: String = str(action.get("consumes_hand_energy_symbol", ""))
		var may_symbols: Array[String] = _string_array(action.get("may_consume_hand_energy_symbols", []))
		for j: int in actions.size():
			if i == j:
				continue
			var other: Dictionary = actions[j]
			var other_id := str(other.get("id", ""))
			if other_id == "":
				continue
			if _arrays_overlap(exact_ids, _string_array(other.get("consumes_hand_card_ids", []))):
				_append_unique_string(conflicts, other_id)
				continue
			var other_energy_symbol: String = str(other.get("consumes_hand_energy_symbol", ""))
			var other_may_symbols: Array[String] = _string_array(other.get("may_consume_hand_energy_symbols", []))
			if energy_symbol != "" and other_may_symbols.has(energy_symbol) and int(hand_energy_counts.get(energy_symbol, 0)) <= 1:
				_append_unique_string(conflicts, other_id)
				continue
			if other_energy_symbol != "" and may_symbols.has(other_energy_symbol) and int(hand_energy_counts.get(other_energy_symbol, 0)) <= 1:
				_append_unique_string(conflicts, other_id)
				continue
		if not conflicts.is_empty():
			action["resource_conflicts"] = conflicts


func _ref_rule_tags_require_interaction(ref: Dictionary) -> bool:
	var tags: Array[String] = _ref_rule_tags(ref)
	for tag: String in ["search_deck", "discard", "recover_to_hand", "gust", "switch_or_retreat", "damage_counters"]:
		if tags.has(tag):
			return true
	return false


func _ref_rule_tags(ref: Dictionary) -> Array[String]:
	var tags: Array[String] = []
	for key: String in ["card_rules", "ability_rules", "attack_rules"]:
		var raw_rules: Variant = ref.get(key, {})
		if not (raw_rules is Dictionary):
			continue
		var raw_tags: Variant = (raw_rules as Dictionary).get("tags", [])
		if not (raw_tags is Array):
			continue
		for raw_tag: Variant in raw_tags:
			_append_unique_string(tags, str(raw_tag))
	return tags


func _card_is_in_player_hand(card: CardInstance, game_state: GameState, player_index: int) -> bool:
	if card == null or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	for hand_card: CardInstance in game_state.players[player_index].hand:
		if hand_card == card:
			return true
	return false


func _hand_energy_symbol_counts(player: PlayerState) -> Dictionary:
	var counts := {}
	if player == null:
		return counts
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null or not card.card_data.is_energy():
			continue
		var symbol := _energy_symbol(str(card.card_data.energy_provides))
		if symbol == "":
			continue
		counts[symbol] = int(counts.get(symbol, 0)) + 1
	return counts


func _card_resource_entry(card: CardInstance) -> Dictionary:
	if card == null or card.card_data == null:
		return {}
	var entry := {
		"id": _card_instance_token(card),
		"name": _best_card_name(card.card_data),
		"type": str(card.card_data.card_type),
	}
	if card.card_data.is_energy():
		entry["energy"] = str(card.card_data.energy_provides)
	return entry


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for raw: Variant in value:
		var text := str(raw)
		if text != "":
			result.append(text)
	return result


func _arrays_overlap(a: Array[String], b: Array[String]) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	for value: String in a:
		if b.has(value):
			return true
	return false


func _append_unique_string(target: Array[String], value: String) -> void:
	if value != "" and not target.has(value):
		target.append(value)


func _unique_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for raw: Variant in values:
		_append_unique_string(result, str(raw))
	return result


func _legal_energy_search_action_ids(current_refs: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for ref: Dictionary in current_refs:
		if not (str(ref.get("type", "")) in ["play_trainer", "play_stadium", "use_ability"]):
			continue
		var tags: Array[String] = _ref_rule_tags(ref)
		if not (tags.has("search_deck") and tags.has("energy_related")):
			continue
		var action_id := str(ref.get("id", ""))
		if action_id != "":
			_append_unique_string(result, action_id)
	return result


func _legal_energy_discard_engine_action_ids(current_refs: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for ref: Dictionary in current_refs:
		if not (str(ref.get("type", "")) in ["play_trainer", "use_ability"]):
			continue
		var tags: Array[String] = _ref_rule_tags(ref)
		if not (tags.has("discard") and tags.has("energy_related")):
			continue
		var action_id := str(ref.get("id", ""))
		if action_id != "":
			_append_unique_string(result, action_id)
	return result


func _future_discard_energy_acceleration_supporters(player: PlayerState, _player_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if player == null:
		return result
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		var cd: CardData = card.card_data
		if str(cd.card_type) != "Supporter":
			continue
		if not _is_discard_energy_acceleration_supporter(cd):
			continue
		var action_id := "play_trainer:%s" % _card_instance_token(card)
		result.append({
			"id": action_id,
			"action_id": action_id,
			"type": "play_trainer",
			"card": _best_card_name(cd),
			"card_type": str(cd.card_type),
			"card_rules": _card_rule_summary(cd, "play_trainer"),
			"requires_interaction": true,
			"future": true,
			"prerequisite": "basic_energy_in_discard_created_this_turn",
			"summary": "future: play %s after this turn creates basic Energy in discard" % _best_card_name(cd),
		})
	return result


func _is_discard_energy_acceleration_supporter(cd: CardData) -> bool:
	if cd == null:
		return false
	var text := ("%s %s %s %s" % [str(cd.name), str(cd.name_en), str(cd.description), str(cd.effect_id)]).to_lower()
	if text.contains("professor sada") or text.contains("奥琳"):
		return true
	return _contains_any(text, ["discard pile", "弃牌"]) \
		and _contains_any(text, ["attach", "附着"]) \
		and _contains_any(text, ["basic energy", "基本"])


func _future_acceleration_supporter_ref(
	supporter_ref: Dictionary,
	search_action_ids: Array[String],
	discard_engine_ids: Array[String],
	plan: Dictionary
) -> Dictionary:
	var ref: Dictionary = supporter_ref.duplicate(true)
	ref["prerequisite_actions"] = search_action_ids + discard_engine_ids
	ref["engine_energy_plan"] = plan.duplicate(true)
	ref["interaction_hints"] = {
		"sada_assignments": [
			{
				"energy_type": _energy_word(str(plan.get("sada_attach_energy", ""))),
				"target_position": "active",
			}
		],
		"energy_assignment": "attach the newly discarded missing basic Energy to the active primary attacker when legal",
	}
	return ref


func _visible_engine_energy_plan(missing_symbols: Array[String]) -> Dictionary:
	if missing_symbols.is_empty() or missing_symbols.size() > 2:
		return {}
	var search_energy: Array[String] = []
	for symbol: String in missing_symbols:
		search_energy.append(_energy_word(symbol))
	var sada_symbol := missing_symbols[0]
	var manual_symbol := missing_symbols[0] if missing_symbols.size() == 1 else missing_symbols[1]
	return {
		"search_energy": search_energy,
		"discard_energy": _energy_word(sada_symbol),
		"sada_attach_energy": _energy_word(sada_symbol),
		"manual_attach_energy": _energy_word(manual_symbol),
	}


func _best_search_energy_for_cost(cost: String, attached_counts: Dictionary, hand_energy_symbols: Array[String]) -> String:
	var current_missing: Array[String] = _missing_attack_cost_symbols(cost, attached_counts)
	if current_missing.is_empty():
		return ""
	for missing_word: String in current_missing:
		var symbol := _energy_symbol(missing_word)
		if symbol == "" or symbol == "C":
			continue
		if hand_energy_symbols.has(symbol):
			continue
		return symbol
	for missing_word: String in current_missing:
		var symbol := _energy_symbol(missing_word)
		if symbol != "" and symbol != "C":
			return symbol
	return ""


func _future_action_refs(
	game_state: GameState,
	player: PlayerState,
	player_index: int,
	current_refs: Array[Dictionary]
) -> Array[Dictionary]:
	var refs: Array[Dictionary] = []
	if game_state == null or player == null:
		return refs
	var seen_ids := {}
	for ref: Dictionary in current_refs:
		var ref_id := str(ref.get("id", ""))
		if ref_id != "":
			seen_ids[ref_id] = true
	_append_future_active_attacks_after_attach(refs, seen_ids, game_state, player, player_index)
	_append_future_active_attacks_after_energy_search(refs, seen_ids, game_state, player, player_index, current_refs)
	_append_future_active_attacks_after_visible_engine(refs, seen_ids, game_state, player, player_index, current_refs)
	_append_future_retreats_and_pivot_attacks(refs, seen_ids, game_state, player, player_index)
	return refs


func _append_future_active_attacks_after_attach(
	refs: Array[Dictionary],
	seen_ids: Dictionary,
	game_state: GameState,
	player: PlayerState,
	player_index: int
) -> void:
	if game_state.energy_attached_this_turn:
		return
	var active: PokemonSlot = player.active_pokemon
	if active == null or active.get_card_data() == null:
		return
	var attached_counts: Dictionary = _slot_energy_counts_by_symbol(active)
	var hand_energy_symbols: Array[String] = _basic_energy_symbols_in_hand(player)
	for attack_index: int in active.get_card_data().attacks.size():
		var attack: Dictionary = active.get_card_data().attacks[attack_index]
		var current_missing: Array[String] = _missing_attack_cost_symbols(str(attack.get("cost", "")), attached_counts)
		if current_missing.is_empty():
			continue
		var after_attach: Dictionary = _best_manual_attach_for_cost(str(attack.get("cost", "")), attached_counts, hand_energy_symbols)
		var after_missing: Array = after_attach.get("missing", current_missing)
		if not after_missing.is_empty():
			continue
		var action_id := "future:attack_after_attach:active:%d:%s" % [attack_index, _safe_action_token(str(attack.get("name", "")))]
		_append_future_action(refs, seen_ids, {
			"id": action_id,
			"action_id": action_id,
			"type": "attack",
			"summary": "future: after manual attach %s to active, attack with %s" % [str(after_attach.get("energy", "")), str(attack.get("name", ""))],
			"requires_interaction": true,
			"attack_index": attack_index,
			"attack_name": str(attack.get("name", "")),
			"attack_quality": _attack_quality_summary_from_attack(attack, attack_index),
			"position": "active",
			"future": true,
			"prerequisite": "manual_attach_to_active",
			"best_manual_attach_energy": str(after_attach.get("energy", "")),
			"missing_cost_now": current_missing,
			"missing_cost_after_prerequisite": after_missing,
		})


func _append_future_active_attacks_after_energy_search(
	refs: Array[Dictionary],
	seen_ids: Dictionary,
	game_state: GameState,
	player: PlayerState,
	player_index: int,
	current_refs: Array[Dictionary]
) -> void:
	if game_state.energy_attached_this_turn:
		return
	var active: PokemonSlot = player.active_pokemon
	if active == null or active.get_card_data() == null:
		return
	var search_action_ids: Array[String] = _legal_energy_search_action_ids(current_refs)
	if search_action_ids.is_empty():
		return
	var attached_counts: Dictionary = _slot_energy_counts_by_symbol(active)
	var hand_energy_symbols: Array[String] = _basic_energy_symbols_in_hand(player)
	for attack_index: int in active.get_card_data().attacks.size():
		var attack: Dictionary = active.get_card_data().attacks[attack_index]
		var quality: Dictionary = _attack_quality_summary_from_attack(attack, attack_index)
		if str(quality.get("terminal_priority", "")) == "low":
			continue
		var current_missing: Array[String] = _missing_attack_cost_symbols(str(attack.get("cost", "")), attached_counts)
		if current_missing.is_empty():
			continue
		var needed_search_energy := _best_search_energy_for_cost(str(attack.get("cost", "")), attached_counts, hand_energy_symbols)
		if needed_search_energy == "":
			continue
		var after_search_hand := hand_energy_symbols.duplicate()
		after_search_hand.append(needed_search_energy)
		var after_attach: Dictionary = _best_manual_attach_for_cost(str(attack.get("cost", "")), attached_counts, after_search_hand)
		var after_missing: Array = after_attach.get("missing", current_missing)
		if not after_missing.is_empty():
			continue
		var attach_id := "future:attach_after_search:%s:active" % _safe_action_token(_energy_word(needed_search_energy))
		_append_future_action(refs, seen_ids, {
			"id": attach_id,
			"action_id": attach_id,
			"type": "attach_energy",
			"summary": "future: after visible energy search, attach %s to active" % _energy_word(needed_search_energy),
			"energy_type": _energy_word(needed_search_energy),
			"target": str(active.get_pokemon_name()),
			"position": "active",
			"future": true,
			"prerequisite": "energy_search_then_manual_attach",
			"prerequisite_actions": search_action_ids,
			"reachable_with_known_resources": true,
		})
		var action_id := "future:attack_after_search_attach:active:%d:%s" % [attack_index, _safe_action_token(str(attack.get("name", "")))]
		_append_future_action(refs, seen_ids, {
			"id": action_id,
			"action_id": action_id,
			"type": "attack",
			"summary": "future: after energy search and %s attach to active, attack with %s" % [_energy_word(needed_search_energy), str(attack.get("name", ""))],
			"requires_interaction": true,
			"attack_index": attack_index,
			"attack_name": str(attack.get("name", "")),
			"attack_quality": quality,
			"position": "active",
			"future": true,
			"prerequisite": "energy_search_then_manual_attach",
			"prerequisite_actions": search_action_ids,
			"best_manual_attach_energy": _energy_word(needed_search_energy),
			"missing_cost_now": current_missing,
			"missing_cost_after_prerequisite": after_missing,
			"reachable_with_known_resources": true,
		})


func _append_future_active_attacks_after_visible_engine(
	refs: Array[Dictionary],
	seen_ids: Dictionary,
	game_state: GameState,
	player: PlayerState,
	player_index: int,
	current_refs: Array[Dictionary]
) -> void:
	if game_state.energy_attached_this_turn:
		return
	var active: PokemonSlot = player.active_pokemon
	if active == null or active.get_card_data() == null:
		return
	var search_action_ids: Array[String] = _legal_energy_search_action_ids(current_refs)
	var discard_engine_ids: Array[String] = _legal_energy_discard_engine_action_ids(current_refs)
	var acceleration_supporters: Array[Dictionary] = _future_discard_energy_acceleration_supporters(player, player_index)
	if search_action_ids.is_empty() or discard_engine_ids.is_empty() or acceleration_supporters.is_empty():
		return
	var attached_counts: Dictionary = _slot_energy_counts_by_symbol(active)
	for attack_index: int in active.get_card_data().attacks.size():
		var attack: Dictionary = active.get_card_data().attacks[attack_index]
		var quality: Dictionary = _attack_quality_summary_from_attack(attack, attack_index)
		if str(quality.get("terminal_priority", "")) == "low":
			continue
		var missing_symbols: Array[String] = _missing_attack_cost_symbol_codes(str(attack.get("cost", "")), attached_counts)
		if missing_symbols.is_empty() or missing_symbols.size() > 2:
			continue
		var plan: Dictionary = _visible_engine_energy_plan(missing_symbols)
		if plan.is_empty():
			continue
		for supporter_ref: Dictionary in acceleration_supporters:
			var supporter_action_id := str(supporter_ref.get("id", ""))
			_append_future_action(refs, seen_ids, _future_acceleration_supporter_ref(supporter_ref, search_action_ids, discard_engine_ids, plan))
			var attach_id := "future:attach_after_visible_engine:%s:active" % _safe_action_token(_energy_word(str(plan.get("manual_attach_energy", ""))))
			_append_future_action(refs, seen_ids, {
				"id": attach_id,
				"action_id": attach_id,
				"type": "attach_energy",
				"summary": "future: after visible engine, manually attach %s to active" % _energy_word(str(plan.get("manual_attach_energy", ""))),
				"energy_type": _energy_word(str(plan.get("manual_attach_energy", ""))),
				"target": str(active.get_pokemon_name()),
				"position": "active",
				"future": true,
				"prerequisite": "visible_engine_search_discard_accelerate_attach",
				"prerequisite_actions": _unique_string_array(search_action_ids + discard_engine_ids + [supporter_action_id]),
				"reachable_with_known_resources": true,
			})
			var action_id := "future:attack_after_visible_engine:active:%d:%s" % [attack_index, _safe_action_token(str(attack.get("name", "")))]
			_append_future_action(refs, seen_ids, {
				"id": action_id,
				"action_id": action_id,
				"type": "attack",
				"summary": "future: after visible search/discard/acceleration/manual attach engine, attack with %s" % str(attack.get("name", "")),
				"requires_interaction": true,
				"attack_index": attack_index,
				"attack_name": str(attack.get("name", "")),
				"attack_quality": quality,
				"position": "active",
				"future": true,
				"prerequisite": "visible_engine_search_discard_accelerate_attach",
				"prerequisite_actions": _unique_string_array(search_action_ids + discard_engine_ids + [supporter_action_id, attach_id]),
				"engine_energy_plan": plan,
				"best_manual_attach_energy": _energy_word(str(plan.get("manual_attach_energy", ""))),
				"missing_cost_now": _energy_words_from_symbols(missing_symbols),
				"missing_cost_after_prerequisite": [],
				"reachable_with_known_resources": true,
			})


func _append_future_retreats_and_pivot_attacks(
	refs: Array[Dictionary],
	seen_ids: Dictionary,
	game_state: GameState,
	player: PlayerState,
	player_index: int
) -> void:
	if player.bench.is_empty():
		return
	for bench_index: int in player.bench.size():
		var bench_slot: PokemonSlot = player.bench[bench_index]
		if bench_slot == null or bench_slot.get_card_data() == null:
			continue
		var bench_pos := "bench_%d" % bench_index
		if not bool(game_state.retreat_used_this_turn):
			var retreat_id := "future:retreat_to:%s" % bench_pos
			_append_future_action(refs, seen_ids, {
				"id": retreat_id,
				"action_id": retreat_id,
				"type": "retreat",
				"summary": "future: retreat or switch active to %s %s after paying cost or resolving a switch effect" % [bench_pos, str(bench_slot.get_pokemon_name())],
				"requires_interaction": true,
				"bench_target": str(bench_slot.get_pokemon_name()),
				"bench_position": bench_pos,
				"future": true,
				"prerequisite": "pay_retreat_or_switch_effect",
				"interaction_hints": {"retreat_target": bench_pos, "switch_target": bench_pos},
			})
		var attached_counts: Dictionary = _slot_energy_counts_by_symbol(bench_slot)
		var hand_energy_symbols: Array[String] = _basic_energy_symbols_in_hand(player)
		for attack_index: int in bench_slot.get_card_data().attacks.size():
			var attack: Dictionary = bench_slot.get_card_data().attacks[attack_index]
			var current_missing: Array[String] = _missing_attack_cost_symbols(str(attack.get("cost", "")), attached_counts)
			var after_attach: Dictionary = _best_manual_attach_for_cost(str(attack.get("cost", "")), attached_counts, hand_energy_symbols)
			var after_missing: Array = after_attach.get("missing", current_missing)
			var attack_id := "future:attack_after_pivot:%s:%d:%s" % [bench_pos, attack_index, _safe_action_token(str(attack.get("name", "")))]
			_append_future_action(refs, seen_ids, {
				"id": attack_id,
				"action_id": attack_id,
				"type": "attack",
				"summary": "future: after pivot to %s %s, attack with %s" % [bench_pos, str(bench_slot.get_pokemon_name()), str(attack.get("name", ""))],
				"requires_interaction": true,
				"attack_index": attack_index,
				"attack_name": str(attack.get("name", "")),
				"attack_quality": _attack_quality_summary_from_attack(attack, attack_index),
				"position": bench_pos,
				"source_pokemon": str(bench_slot.get_pokemon_name()),
				"future": true,
				"prerequisite": "pivot_to_bench_attacker",
				"reachable_with_known_resources": after_missing.is_empty(),
				"best_manual_attach_energy": str(after_attach.get("energy", "")),
				"missing_cost_now": current_missing,
				"missing_cost_after_prerequisite": after_missing,
			})


func _append_future_action(refs: Array[Dictionary], seen_ids: Dictionary, ref: Dictionary) -> void:
	if refs.size() >= 12:
		return
	var action_id := str(ref.get("id", ""))
	if action_id == "" or bool(seen_ids.get(action_id, false)):
		return
	refs.append(ref)
	seen_ids[action_id] = true


func _safe_action_token(text: String) -> String:
	var token := text.strip_edges().to_lower().replace(" ", "_")
	if token == "":
		return "unknown"
	return token


func _turn_tactical_facts(
	game_state: GameState,
	player: PlayerState,
	player_index: int,
	legal_actions: Array[Dictionary],
	legal_action_groups: Dictionary,
	future_actions: Array[Dictionary] = []
) -> Dictionary:
	var facts := {
		"deck_count": player.deck.size() if player != null else 0,
		"no_deck_draw_lock": player != null and player.deck.is_empty(),
		"attack_legal_now": not (legal_action_groups.get("attack", []) as Array).is_empty(),
		"attack_reachable_after_manual_attach": false,
		"primary_attack_ready": false,
		"primary_attack_name": "",
		"primary_attack_missing_cost": [],
		"primary_attack_reachable_after_manual_attach": false,
		"primary_attack_reachable_after_search": false,
		"primary_attack_reachable_after_visible_engine": false,
		"primary_attack_route": [],
		"safe_pre_primary_actions": [],
		"productive_engine_actions": [],
		"ready_attacks": [],
		"ready_attack_is_low_value_redraw": false,
		"only_ready_attack_is_low_value_redraw": false,
		"attack_quality_by_action_id": _attack_quality_by_action_id(legal_actions, future_actions),
		"best_manual_attach_energy_for_active_attack": "",
		"best_manual_attach_to_best_active_attack_action_id": "",
		"manual_attach_enables_best_active_attack": false,
		"best_active_attack_after_manual_attach": {},
		"best_manual_attach_to_primary_attack_action_id": "",
		"manual_attach_enables_primary_attack": false,
		"missing_attack_cost_after_best_manual_attach": [],
		"active_attack_options": [],
		"legal_supporter_names": [],
		"supporter_names_in_hand": [],
		"legal_survival_tool_actions": _legal_survival_tool_actions(legal_actions),
		"legal_action_priorities": _non_empty_action_groups(legal_action_groups),
		"gust_ko_opportunities": [],
		"best_gust_ko_route": {},
		"sada_assignment_recommendations": [],
	}
	if game_state == null or player == null:
		return facts
	facts["safe_pre_primary_actions"] = _safe_pre_primary_actions(legal_actions)
	facts["productive_engine_actions"] = _productive_engine_actions(legal_actions)
	facts["legal_supporter_names"] = _legal_supporter_names(legal_actions)
	facts["supporter_names_in_hand"] = _supporter_names_in_hand(player)
	facts["sada_assignment_recommendations"] = _sada_assignment_recommendations(player)
	var active: PokemonSlot = player.active_pokemon
	if active == null or active.get_card_data() == null:
		return facts
	var active_cd: CardData = active.get_card_data()
	var attached_counts: Dictionary = _slot_energy_counts_by_symbol(active)
	var hand_energy_symbols: Array[String] = _basic_energy_symbols_in_hand(player)
	var best_missing: Array[String] = []
	var best_attach := ""
	var best_missing_count := 999
	var best_after_attach_attack: Dictionary = {}
	var best_after_attach_score := -999999
	var primary_option: Dictionary = {}
	var ready_attacks: Array[Dictionary] = []
	var opponent_active: PokemonSlot = _opponent_active_slot(game_state, player_index)
	for i: int in active_cd.attacks.size():
		var attack: Dictionary = active_cd.attacks[i]
		var cost := str(attack.get("cost", ""))
		var missing_now: Array[String] = _missing_attack_cost_symbols(cost, attached_counts)
		var legal_id := _legal_attack_id_for_index(legal_actions, i)
		var quality := _attack_quality_summary_from_attack(attack, i)
		var option := {
			"attack_index": i,
			"attack_name": str(attack.get("name", "")),
			"cost": cost,
			"damage": str(attack.get("damage", "")),
			"attack_quality": quality,
			"ready_now": missing_now.is_empty(),
			"legal_action_id": legal_id,
			"missing_cost_now": missing_now,
			"missing_cost_after_best_manual_attach": missing_now,
			"best_manual_attach_energy": "",
			"estimated_damage_after_best_manual_attach": 0,
			"kos_opponent_active_after_best_manual_attach": false,
		}
		if not bool(game_state.energy_attached_this_turn):
			var best_for_attack: Dictionary = _best_manual_attach_for_cost(cost, attached_counts, hand_energy_symbols)
			option["best_manual_attach_energy"] = str(best_for_attack.get("energy", ""))
			option["missing_cost_after_best_manual_attach"] = best_for_attack.get("missing", missing_now)
			if (option["missing_cost_after_best_manual_attach"] as Array).is_empty():
				var projected_damage := _estimated_active_attack_damage_after_manual_attach(
					active,
					attack,
					player,
					opponent_active,
					str(option.get("best_manual_attach_energy", ""))
				)
				option["estimated_damage_after_best_manual_attach"] = projected_damage
				var opponent_hp := opponent_active.get_remaining_hp() if opponent_active != null else 0
				option["kos_opponent_active_after_best_manual_attach"] = opponent_hp > 0 and projected_damage >= opponent_hp
				var attach_action_id := _legal_manual_attach_id_for_energy(legal_actions, str(option.get("best_manual_attach_energy", "")), "active")
				if attach_action_id != "":
					var route_score := _manual_attach_attack_route_score(option)
					if route_score > best_after_attach_score:
						best_after_attach_score = route_score
						best_after_attach_attack = option.duplicate(true)
						best_after_attach_attack["best_manual_attach_action_id"] = attach_action_id
		var after_missing: Array = option["missing_cost_after_best_manual_attach"]
		if after_missing.size() < best_missing_count:
			best_missing_count = after_missing.size()
			best_missing = []
			for value: Variant in after_missing:
				best_missing.append(str(value))
			best_attach = str(option.get("best_manual_attach_energy", ""))
		if _is_primary_attack_quality(quality) and (primary_option.is_empty() or i > int(primary_option.get("attack_index", -1))):
			primary_option = option
		if missing_now.is_empty() and legal_id != "":
			ready_attacks.append({
				"attack_name": str(attack.get("name", "")),
				"attack_index": i,
				"legal_action_id": legal_id,
				"attack_quality": quality,
			})
		(facts["active_attack_options"] as Array).append(option)
	facts["attack_reachable_after_manual_attach"] = best_missing_count == 0
	facts["best_manual_attach_energy_for_active_attack"] = best_attach
	facts["missing_attack_cost_after_best_manual_attach"] = best_missing
	if not best_after_attach_attack.is_empty():
		facts["manual_attach_enables_best_active_attack"] = true
		facts["best_manual_attach_to_best_active_attack_action_id"] = str(best_after_attach_attack.get("best_manual_attach_action_id", ""))
		facts["best_active_attack_after_manual_attach"] = best_after_attach_attack
	facts["ready_attacks"] = ready_attacks
	if not ready_attacks.is_empty():
		var low_ready_count := 0
		for ready: Dictionary in ready_attacks:
			var ready_quality: Dictionary = ready.get("attack_quality", {})
			if str(ready_quality.get("terminal_priority", "")) == "low":
				low_ready_count += 1
		facts["ready_attack_is_low_value_redraw"] = low_ready_count > 0
		facts["only_ready_attack_is_low_value_redraw"] = low_ready_count == ready_attacks.size()
	if not primary_option.is_empty():
		var primary_missing: Array = primary_option.get("missing_cost_now", [])
		var primary_after_attach: Array = primary_option.get("missing_cost_after_best_manual_attach", primary_missing)
		facts["primary_attack_name"] = str(primary_option.get("attack_name", ""))
		facts["primary_attack_ready"] = bool(primary_option.get("ready_now", false)) and str(primary_option.get("legal_action_id", "")) != ""
		facts["primary_attack_missing_cost"] = primary_missing
		facts["primary_attack_reachable_after_manual_attach"] = primary_after_attach.is_empty()
		if bool(facts.get("primary_attack_reachable_after_manual_attach", false)):
			var attach_energy := str(primary_option.get("best_manual_attach_energy", ""))
			var attach_action_id := _legal_manual_attach_id_for_energy(legal_actions, attach_energy, "active")
			facts["best_manual_attach_to_primary_attack_action_id"] = attach_action_id
			facts["manual_attach_enables_primary_attack"] = attach_action_id != ""
		facts["primary_attack_reachable_after_search"] = _future_actions_include_primary_attack(future_actions, str(primary_option.get("attack_name", "")), "energy_search_then_manual_attach")
		facts["primary_attack_reachable_after_visible_engine"] = _future_actions_include_primary_attack(future_actions, str(primary_option.get("attack_name", "")))
		facts["primary_attack_route"] = _primary_attack_visible_engine_route(future_actions, str(primary_option.get("attack_name", "")))
	facts["gust_ko_opportunities"] = _gust_ko_opportunities(game_state, player, player_index, legal_actions, future_actions)
	var gust_routes: Array = facts.get("gust_ko_opportunities", [])
	if not gust_routes.is_empty():
		facts["best_gust_ko_route"] = (gust_routes[0] as Dictionary).duplicate(true)
	return facts


func _opponent_active_slot(game_state: GameState, player_index: int) -> PokemonSlot:
	if game_state == null:
		return null
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return null
	var opponent: PlayerState = game_state.players[opponent_index]
	return opponent.active_pokemon if opponent != null else null


func _manual_attach_attack_route_score(option: Dictionary) -> int:
	var quality: Dictionary = option.get("attack_quality", {}) if option.get("attack_quality", {}) is Dictionary else {}
	var score := 0
	if bool(option.get("kos_opponent_active_after_best_manual_attach", false)):
		score += 2000
	match str(quality.get("terminal_priority", "")):
		"high":
			score += 700
		"medium":
			score += 450
		"low":
			score -= 600
	match str(quality.get("role", "")):
		"primary_damage":
			score += 500
		"chip_damage":
			score += 250
	score += mini(500, int(option.get("estimated_damage_after_best_manual_attach", 0)))
	score += int(option.get("attack_index", 0)) * 25
	return score


func _estimated_active_attack_damage_after_manual_attach(
	active: PokemonSlot,
	attack: Dictionary,
	player: PlayerState,
	opponent_active: PokemonSlot,
	attach_energy_word: String
) -> int:
	if active == null or active.get_card_data() == null:
		return 0
	var damage_text := str(attack.get("damage", "")).strip_edges()
	var base_damage := _first_int_in_string(damage_text)
	if base_damage <= 0:
		return 0
	var combined := "%s %s %s" % [damage_text, str(attack.get("text", "")), str(attack.get("name", ""))]
	var lower := combined.to_lower()
	var damage := base_damage
	if _looks_like_both_active_energy_bonus(lower):
		damage = base_damage + (_energy_multiplier_from_text(combined, 30) * (_slot_attached_energy_count(active) + 1 + _slot_attached_energy_count(opponent_active)))
	elif lower.contains("x") or lower.contains("×") or lower.contains("脳"):
		if _name_has_any(lower, ["thundering bolt", "raging bolt", "basic energy", "discard"]):
			damage = base_damage * (_count_board_basic_energy(player) + 1)
		else:
			damage = base_damage * maxi(1, _slot_attached_energy_count(active) + 1)
	return _apply_simple_weakness(damage, active.get_card_data(), opponent_active)


func _looks_like_both_active_energy_bonus(lower_text: String) -> bool:
	return (lower_text.contains("both active") or lower_text.contains("双方") or lower_text.contains("战斗宝可梦") or lower_text.contains("戰鬥寶可夢")) \
		and (lower_text.contains("attached energy") or lower_text.contains("energy attached") or lower_text.contains("附着") or lower_text.contains("附著")) \
		and (lower_text.contains("x") or lower_text.contains("×") or lower_text.contains("脳") or lower_text.contains("for each") or lower_text.contains("每"))


func _energy_multiplier_from_text(text: String, fallback: int) -> int:
	var normalized := text.replace("×", "x").replace("脳", "x")
	var x_index := normalized.find("x")
	if x_index <= 0:
		return fallback
	var digits := ""
	var cursor := x_index - 1
	while cursor >= 0:
		var ch := normalized.substr(cursor, 1)
		if ch >= "0" and ch <= "9":
			digits = ch + digits
			cursor -= 1
			continue
		if digits != "":
			break
		cursor -= 1
	return int(digits) if digits.is_valid_int() else fallback


func _slot_attached_energy_count(slot: PokemonSlot) -> int:
	return slot.attached_energy.size() if slot != null else 0


func _apply_simple_weakness(damage: int, attacker_cd: CardData, defender: PokemonSlot) -> int:
	if damage <= 0 or attacker_cd == null or defender == null or defender.get_card_data() == null:
		return damage
	var attacker_symbol := _energy_symbol(str(attacker_cd.energy_type))
	var weakness_symbol := _energy_symbol(str(defender.get_card_data().weakness_energy))
	if attacker_symbol == "" or weakness_symbol == "" or attacker_symbol != weakness_symbol:
		return damage
	var value := str(defender.get_card_data().weakness_value)
	if value.contains("2"):
		return damage * 2
	return damage


func _attack_quality_by_action_id(legal_actions: Array[Dictionary], future_actions: Array[Dictionary]) -> Dictionary:
	var result := {}
	for collection: Array[Dictionary] in [legal_actions, future_actions]:
		for ref: Dictionary in collection:
			if str(ref.get("type", "")) != "attack":
				continue
			var action_id := str(ref.get("id", ""))
			if action_id == "":
				continue
			var quality: Variant = ref.get("attack_quality", {})
			if quality is Dictionary:
				result[action_id] = (quality as Dictionary).duplicate(true)
	return result


func _is_primary_attack_quality(quality: Dictionary) -> bool:
	return str(quality.get("role", "")) == "primary_damage" or str(quality.get("terminal_priority", "")) == "high"


func _future_actions_include_primary_attack(future_actions: Array[Dictionary], primary_attack_name: String, prerequisite_filter: String = "") -> bool:
	for ref: Dictionary in future_actions:
		if str(ref.get("type", "")) != "attack":
			continue
		if prerequisite_filter != "" and str(ref.get("prerequisite", "")) != prerequisite_filter:
			continue
		var quality: Dictionary = ref.get("attack_quality", {}) if ref.get("attack_quality", {}) is Dictionary else {}
		if not _is_primary_attack_quality(quality):
			continue
		if primary_attack_name != "" and str(ref.get("attack_name", "")) != primary_attack_name:
			continue
		if bool(ref.get("reachable_with_known_resources", true)):
			return true
	return false


func _primary_attack_visible_engine_route(future_actions: Array[Dictionary], primary_attack_name: String) -> Array:
	var best_route: Array = []
	for ref: Dictionary in future_actions:
		if str(ref.get("type", "")) != "attack":
			continue
		if primary_attack_name != "" and str(ref.get("attack_name", "")) != primary_attack_name:
			continue
		if not bool(ref.get("reachable_with_known_resources", true)):
			continue
		var prerequisite := str(ref.get("prerequisite", ""))
		if prerequisite == "visible_engine_search_discard_accelerate_attach":
			return [
				"energy_search",
				"discard_energy_engine",
				"discard_energy_acceleration_supporter",
				"manual_attach",
				str(ref.get("attack_name", "")),
			]
		if prerequisite == "energy_search_then_manual_attach":
			best_route = [
				"energy_search",
				"manual_attach",
				str(ref.get("attack_name", "")),
			]
		elif prerequisite == "manual_attach_to_active" and best_route.is_empty():
			best_route = [
				"manual_attach",
				str(ref.get("attack_name", "")),
			]
	return best_route


func _gust_ko_opportunities(
	game_state: GameState,
	player: PlayerState,
	player_index: int,
	legal_actions: Array[Dictionary],
	_future_actions: Array[Dictionary]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if game_state == null or player == null:
		return result
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return result
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null or opponent.bench.is_empty():
		return result
	var gust_actions: Array[Dictionary] = _legal_gust_actions(legal_actions)
	if gust_actions.is_empty():
		return result
	var attacks: Array[Dictionary] = _legal_damage_attacks(legal_actions)
	if attacks.is_empty():
		return result
	for gust_ref: Dictionary in gust_actions:
		for attack_ref: Dictionary in attacks:
			var damage := _estimated_attack_damage_for_ref(attack_ref, player)
			if damage <= 0:
				continue
			for bench_index: int in opponent.bench.size():
				var target: PokemonSlot = opponent.bench[bench_index]
				if target == null or target.get_card_data() == null:
					continue
				var remaining_hp := target.get_remaining_hp()
				if remaining_hp <= 0 or remaining_hp > damage:
					continue
				var prize_count := target.get_prize_count()
				var target_position := "bench_%d" % bench_index
				result.append({
					"gust_action_id": str(gust_ref.get("id", "")),
					"attack_action_id": str(attack_ref.get("id", "")),
					"target_position": target_position,
					"target_name": str(target.get_pokemon_name()),
					"target_hp_remaining": remaining_hp,
					"target_prize_count": prize_count,
					"estimated_damage": damage,
					"attack_name": str(attack_ref.get("attack_name", "")),
					"game_winning": prize_count >= player.prizes.size(),
					"selection_policy": {
						"gust_target": target_position,
						"opponent_bench_target": target_position,
						"opponent_switch_target": target_position,
						"target_position": target_position,
					},
					"why": "gust this bench target because the listed attack can KO it now",
				})
	result.sort_custom(Callable(self, "_sort_gust_ko_desc"))
	if result.size() > 5:
		result.resize(5)
	return result


func _sort_gust_ko_desc(a: Dictionary, b: Dictionary) -> bool:
	var a_win := bool(a.get("game_winning", false))
	var b_win := bool(b.get("game_winning", false))
	if a_win != b_win:
		return a_win
	var a_prizes := int(a.get("target_prize_count", 0))
	var b_prizes := int(b.get("target_prize_count", 0))
	if a_prizes != b_prizes:
		return a_prizes > b_prizes
	var a_hp := int(a.get("target_hp_remaining", 9999))
	var b_hp := int(b.get("target_hp_remaining", 9999))
	if a_hp != b_hp:
		return a_hp < b_hp
	return str(a.get("target_position", "")) < str(b.get("target_position", ""))


func _legal_gust_actions(legal_actions: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ref: Dictionary in legal_actions:
		if str(ref.get("type", "")) not in ["play_trainer", "play_stadium"]:
			continue
		var tags: Array[String] = _ref_rule_tags(ref)
		var combined := _ref_combined_name(ref)
		if tags.has("gust") or _name_has_any(combined, ["boss", "catcher"]):
			result.append(ref)
	return result


func _legal_damage_attacks(legal_actions: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ref: Dictionary in legal_actions:
		if str(ref.get("type", "")) not in ["attack", "granted_attack"]:
			continue
		var quality: Dictionary = ref.get("attack_quality", {}) if ref.get("attack_quality", {}) is Dictionary else {}
		if str(quality.get("terminal_priority", "")) == "low":
			continue
		if _estimated_attack_damage_for_ref(ref, null) <= 0:
			continue
		result.append(ref)
	return result


func _estimated_attack_damage_for_ref(ref: Dictionary, player: PlayerState) -> int:
	var rules: Dictionary = ref.get("attack_rules", {}) if ref.get("attack_rules", {}) is Dictionary else {}
	var damage_text := str(rules.get("damage", ""))
	if damage_text == "":
		damage_text = str(ref.get("damage", ""))
	var base_damage := _first_int_in_string(damage_text)
	if base_damage <= 0:
		return 0
	var combined := "%s %s %s" % [damage_text, str(rules.get("text", "")), str(ref.get("attack_name", ""))]
	var lower := combined.to_lower()
	if lower.contains("x") or lower.contains("×"):
		if player != null and _name_has_any(lower, ["thundering bolt", "raging bolt", "basic energy", "discard"]):
			return base_damage * _count_board_basic_energy(player)
		if player != null and player.active_pokemon != null:
			return base_damage * maxi(1, player.active_pokemon.attached_energy.size())
		return base_damage
	return base_damage


func _sada_assignment_recommendations(player: PlayerState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if player == null:
		return result
	var discard_symbols := _discard_basic_energy_symbols(player)
	if discard_symbols.is_empty():
		return result
	for slot: PokemonSlot in _player_slots(player):
		if slot == null or slot.get_card_data() == null or not slot.get_card_data().is_ancient_pokemon():
			continue
		var position := _slot_position_for_player(player, slot)
		for symbol: String in discard_symbols:
			var recommendation := _sada_recommendation_for_symbol(slot, position, symbol)
			if not recommendation.is_empty():
				result.append(recommendation)
	result.sort_custom(Callable(self, "_sort_sada_recommendation_desc"))
	if result.size() > 6:
		result.resize(6)
	return result


func _sada_recommendation_for_symbol(slot: PokemonSlot, position: String, symbol: String) -> Dictionary:
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return {}
	var attached_counts := _slot_energy_counts_by_symbol(slot)
	var best: Dictionary = {}
	var best_score := -1
	for attack_index: int in cd.attacks.size():
		var attack: Dictionary = cd.attacks[attack_index]
		var missing_symbols := _missing_attack_cost_symbol_codes(str(attack.get("cost", "")), attached_counts)
		if not missing_symbols.has(symbol):
			continue
		var score := 1000
		if position == "active":
			score += 300
		if attack_index > 0:
			score += 250
		if _name_has_any("%s %s" % [str(cd.name), str(cd.name_en)], ["Raging Bolt", "猛雷鼓"]):
			score += 200
		if score <= best_score:
			continue
		best_score = score
		best = {
			"energy_type": _energy_word(symbol),
			"target_position": position,
			"target_name": str(slot.get_pokemon_name()),
			"attack_name": str(attack.get("name", "")),
			"missing_cost_before": _energy_words_from_symbols(missing_symbols),
			"reason": "fills_missing_attack_cost",
			"priority": score,
		}
	return best


func _sort_sada_recommendation_desc(a: Dictionary, b: Dictionary) -> bool:
	var left := int(a.get("priority", 0))
	var right := int(b.get("priority", 0))
	if left == right:
		return str(a.get("target_position", "")) < str(b.get("target_position", ""))
	return left > right


func _discard_basic_energy_symbols(player: PlayerState) -> Array[String]:
	var result: Array[String] = []
	if player == null:
		return result
	for card: CardInstance in player.discard_pile:
		if card == null or card.card_data == null or str(card.card_data.card_type) != "Basic Energy":
			continue
		var symbol := _energy_symbol(str(card.card_data.energy_provides))
		if symbol != "" and not result.has(symbol):
			result.append(symbol)
	return result


func _slot_position_for_player(player: PlayerState, slot: PokemonSlot) -> String:
	if player == null or slot == null:
		return ""
	if slot == player.active_pokemon:
		return "active"
	for i: int in player.bench.size():
		if slot == player.bench[i]:
			return "bench_%d" % i
	return ""


func _first_int_in_string(text: String) -> int:
	var digits := ""
	for i: int in text.length():
		var ch := text.substr(i, 1)
		if ch >= "0" and ch <= "9":
			digits += ch
		elif digits != "":
			break
	return int(digits) if digits.is_valid_int() else 0


func _safe_pre_primary_actions(legal_actions: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ref: Dictionary in legal_actions:
		if result.size() >= 6:
			break
		var action_type := str(ref.get("type", ""))
		var tags: Array[String] = _ref_rule_tags(ref)
		var reason := ""
		if action_type == "attach_tool":
			reason = "improves_survival_without_consuming_attack"
		elif _is_safe_charge_draw_ability_ref(ref, tags):
			reason = "adds_basic_energy_and_draws_without_consuming_manual_attach"
		else:
			continue
		result.append({
			"id": str(ref.get("id", "")),
			"type": action_type,
			"card": str(ref.get("card", ref.get("pokemon", ""))),
			"position": str(ref.get("position", "")),
			"reason": reason,
			"interactions": _default_interactions_for_ref(ref),
		})
	return result


func _productive_engine_actions(legal_actions: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ref: Dictionary in legal_actions:
		if result.size() >= 10:
			break
		var action_type := str(ref.get("type", ""))
		var tags: Array[String] = _ref_rule_tags(ref)
		var priority := ""
		var role := ""
		var reason := ""
		if _is_safe_charge_draw_ability_ref(ref, tags):
			priority = "high"
			role = "charge_and_draw"
			reason = "adds board Energy and draws before attack without using manual attach"
		elif action_type == "play_trainer" and tags.has("filter_engine"):
			priority = "medium_high"
			role = "draw_filter"
			reason = "filters hand for missing attack pieces before ending or low-pressure attack"
		elif action_type == "play_trainer" and tags.has("draw") and tags.has("discard") and not tags.has("supporter_related"):
			priority = "medium_high"
			role = "draw_filter"
			reason = "draw/discard Item can find missing resources when the primary route is incomplete"
		elif action_type == "play_trainer" and tags.has("search_deck") and tags.has("energy_related"):
			priority = "high"
			role = "energy_search"
			reason = "creates missing Energy pieces for primary attack routes"
		elif action_type == "play_trainer" and _ref_combined_name(ref).contains("professor sada"):
			priority = "high"
			role = "supporter_acceleration"
			reason = "accelerates discard Energy to Ancient attackers and draws into follow-up actions"
		elif action_type == "use_ability" and tags.has("draw") and tags.has("discard"):
			priority = "medium_high"
			role = "draw_filter"
			reason = "ability converts expendable Energy into new cards for attack construction"
		elif _is_draw_engine_ability_ref(ref, tags):
			priority = "medium_high"
			role = "draw_ability"
			reason = "draw ability should be used before ending when it can reveal more playable resources"
		elif action_type == "play_trainer" and tags.has("recover_to_hand"):
			priority = "medium_high"
			role = "resource_recovery"
			reason = "recovers visible discard resources so the next attack chain does not run out of Energy or attackers"
		else:
			continue
		result.append({
			"id": str(ref.get("id", "")),
			"type": action_type,
			"card": str(ref.get("card", ref.get("pokemon", ""))),
			"position": str(ref.get("position", "")),
			"priority": priority,
			"role": role,
			"reason": reason,
			"resource_conflicts": ref.get("resource_conflicts", []),
			"interactions": _default_interactions_for_ref(ref),
		})
	return result


func _is_safe_charge_draw_ability_ref(ref: Dictionary, tags: Array[String]) -> bool:
	if str(ref.get("type", "")) != "use_ability":
		return false
	if tags.has("energy_related") and tags.has("draw") and not tags.has("discard"):
		return true
	var pokemon_name := str(ref.get("pokemon", ref.get("card", "")))
	if pokemon_name.to_lower().contains("ogerpon"):
		return true
	var rules: Dictionary = ref.get("card_rules", {}) if ref.get("card_rules", {}) is Dictionary else {}
	return str(rules.get("effect_id", "")) == "409898a79b38fe8ca279e7bdaf4fd52e"


func _is_draw_engine_ability_ref(ref: Dictionary, tags: Array[String]) -> bool:
	if str(ref.get("type", "")) != "use_ability":
		return false
	if tags.has("draw") and not tags.has("discard") and not tags.has("energy_related"):
		return true
	var combined := _ref_combined_name(ref)
	if combined.contains("fezandipiti"):
		return true
	var rules: Dictionary = ref.get("card_rules", {}) if ref.get("card_rules", {}) is Dictionary else {}
	return str(rules.get("effect_id", "")) == "ab6c3357e2b8a8385a68da738f41e0c1"


func _ref_combined_name(ref: Dictionary) -> String:
	var parts: Array[String] = [
		str(ref.get("card", "")),
		str(ref.get("pokemon", "")),
		str(ref.get("ability", "")),
	]
	var card_rules: Variant = ref.get("card_rules", {})
	if card_rules is Dictionary:
		var rules: Dictionary = card_rules
		parts.append(str(rules.get("name", "")))
		parts.append(str(rules.get("name_en", "")))
		parts.append(str(rules.get("effect_id", "")))
	var ability_rules: Variant = ref.get("ability_rules", {})
	if ability_rules is Dictionary:
		var rules: Dictionary = ability_rules
		parts.append(str(rules.get("name", "")))
		parts.append(str(rules.get("text", "")))
	return " ".join(parts).to_lower()


func _default_interactions_for_ref(ref: Dictionary) -> Dictionary:
	var schema: Dictionary = ref.get("interaction_schema", {}) if ref.get("interaction_schema", {}) is Dictionary else {}
	if schema.has("basic_energy_from_hand"):
		var basic_energy: Dictionary = schema.get("basic_energy_from_hand", {}) if schema.get("basic_energy_from_hand", {}) is Dictionary else {}
		var examples: Array = basic_energy.get("examples", []) if basic_energy.get("examples", []) is Array else []
		if not examples.is_empty():
			return {"basic_energy_from_hand": str(examples[0])}
		return {"basic_energy_from_hand": "Grass Energy"}
	if schema.has("recover_energy"):
		return {"recover_energy": ["Lightning Energy", "Fighting Energy", "Grass Energy"]}
	if schema.has("night_stretcher_choice") or schema.has("recover_target") or schema.has("recover_card"):
		return {"recover_target": "basic_attack_energy_or_core_basic_pokemon"}
	return {}


func _legal_survival_tool_actions(legal_actions: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ref: Dictionary in legal_actions:
		if str(ref.get("type", "")) != "attach_tool":
			continue
		var rules: Dictionary = ref.get("card_rules", {}) if ref.get("card_rules", {}) is Dictionary else {}
		var tags: Array = rules.get("tags", ref.get("tags", [])) if rules is Dictionary else ref.get("tags", [])
		if not tags.has("hp_boost"):
			continue
		result.append({
			"id": str(ref.get("id", "")),
			"card": str(ref.get("card", "")),
			"target": str(ref.get("target", "")),
			"position": str(ref.get("position", "")),
			"why": "safe survival tool before attack/end_turn",
		})
	return result


func _non_empty_action_groups(legal_action_groups: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key: String in legal_action_groups.keys():
		var values: Variant = legal_action_groups.get(key, [])
		if values is Array and not (values as Array).is_empty():
			result.append(key)
	return result


func _legal_supporter_names(legal_actions: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for ref: Dictionary in legal_actions:
		if str(ref.get("type", "")) != "play_trainer":
			continue
		if str(ref.get("card_type", "")) != "Supporter":
			continue
		var name := str(ref.get("card", ""))
		if name != "" and not result.has(name):
			result.append(name)
	return result


func _supporter_names_in_hand(player: PlayerState) -> Array[String]:
	var result: Array[String] = []
	if player == null:
		return result
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		if str(card.card_data.card_type) != "Supporter":
			continue
		var name := _best_card_name(card.card_data)
		if name != "" and not result.has(name):
			result.append(name)
	return result


func _slot_energy_counts_by_symbol(slot: PokemonSlot) -> Dictionary:
	var counts := {}
	if slot == null:
		return counts
	for card: CardInstance in slot.attached_energy:
		if card == null or card.card_data == null:
			continue
		var symbol := _energy_symbol(str(card.card_data.energy_provides))
		if symbol == "":
			continue
		counts[symbol] = int(counts.get(symbol, 0)) + 1
	return counts


func _basic_energy_symbols_in_hand(player: PlayerState) -> Array[String]:
	var result: Array[String] = []
	if player == null:
		return result
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		if str(card.card_data.card_type) != "Basic Energy":
			continue
		var symbol := _energy_symbol(str(card.card_data.energy_provides))
		if symbol != "":
			result.append(symbol)
	return result


func _legal_attack_id_for_index(legal_actions: Array[Dictionary], attack_index: int) -> String:
	for ref: Dictionary in legal_actions:
		if str(ref.get("type", "")) in ["attack", "granted_attack"] and int(ref.get("attack_index", -1)) == attack_index:
			return str(ref.get("id", ""))
	return ""


func _legal_manual_attach_id_for_energy(legal_actions: Array[Dictionary], energy_word: String, position: String = "active") -> String:
	var requested_symbol := _energy_symbol(energy_word)
	if requested_symbol == "":
		return ""
	for ref: Dictionary in legal_actions:
		if str(ref.get("type", "")) != "attach_energy":
			continue
		if position != "" and str(ref.get("position", "")) != position:
			continue
		var ref_symbol := _energy_symbol(str(ref.get("energy_type", "")))
		if ref_symbol == "":
			ref_symbol = _energy_symbol(str(ref.get("card", "")))
		if ref_symbol == requested_symbol:
			return str(ref.get("id", ""))
	return ""


func _best_manual_attach_for_cost(cost: String, attached_counts: Dictionary, hand_energy_symbols: Array[String]) -> Dictionary:
	var best_energy := ""
	var best_missing: Array[String] = _missing_attack_cost_symbols(cost, attached_counts)
	var best_count := best_missing.size()
	for symbol: String in hand_energy_symbols:
		var simulated := attached_counts.duplicate()
		simulated[symbol] = int(simulated.get(symbol, 0)) + 1
		var missing: Array[String] = _missing_attack_cost_symbols(cost, simulated)
		if missing.size() < best_count:
			best_count = missing.size()
			best_missing = missing
			best_energy = _energy_word(symbol)
	return {"energy": best_energy, "missing": best_missing}


func _missing_attack_cost_symbols(cost: String, attached_counts: Dictionary) -> Array[String]:
	var remaining := {}
	var total_attached := 0
	for raw_key: Variant in attached_counts.keys():
		var key := str(raw_key)
		var count := int(attached_counts.get(key, 0))
		remaining[key] = count
		total_attached += count
	var missing: Array[String] = []
	var colorless_needed := 0
	for i: int in cost.length():
		var symbol := _energy_symbol(cost.substr(i, 1))
		if symbol == "":
			continue
		if symbol == "C":
			colorless_needed += 1
			continue
		var count := int(remaining.get(symbol, 0))
		if count > 0:
			remaining[symbol] = count - 1
			total_attached -= 1
		else:
			missing.append(_energy_word(symbol))
	if colorless_needed > total_attached:
		for i: int in colorless_needed - total_attached:
			missing.append("Colorless")
	return missing


func _missing_attack_cost_symbol_codes(cost: String, attached_counts: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for word: String in _missing_attack_cost_symbols(cost, attached_counts):
		var symbol := _energy_symbol(word)
		if symbol != "" and symbol != "C":
			result.append(symbol)
	return result


func _energy_words_from_symbols(symbols: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for symbol: String in symbols:
		result.append(_energy_word(symbol))
	return result


func _energy_symbol(value: String) -> String:
	var normalized := value.strip_edges().to_upper()
	match normalized:
		"LIGHTNING":
			return "L"
		"FIGHTING":
			return "F"
		"GRASS":
			return "G"
		"FIRE":
			return "R"
		"WATER":
			return "W"
		"PSYCHIC":
			return "P"
		"DARKNESS", "DARK":
			return "D"
		"METAL":
			return "M"
		"COLORLESS":
			return "C"
	if normalized in ["L", "F", "G", "R", "W", "P", "D", "M", "C"]:
		return normalized
	return ""


func _actions_schema() -> Dictionary:
	return {
		"type": "array",
		"maxItems": 8,
		"items": {
			"type": "object",
			"required": ["type", "card", "energy_type", "target", "position", "pokemon", "ability", "bench_target", "bench_position", "attack_name", "discard_energy_type", "search_target", "discard_choice", "interactions"],
			"additionalProperties": false,
			"properties": {
				"type": {"type": "string"},
				"card": {"type": "string"},
				"energy_type": {"type": "string"},
				"target": {"type": "string"},
				"position": {"type": "string"},
				"pokemon": {"type": "string"},
				"ability": {"type": "string"},
				"bench_target": {"type": "string"},
				"bench_position": {"type": "string"},
				"attack_name": {"type": "string"},
				"discard_energy_type": {"type": "string"},
				"search_target": {"type": "string"},
				"discard_choice": {"type": "string"},
				"interactions": {"type": "object", "additionalProperties": true},
			},
		},
	}


func _serialize_compact_game_state(game_state: GameState, player: PlayerState, opponent: PlayerState, player_index: int) -> Dictionary:
	var opponent_index: int = 1 - player_index
	var is_first_turn: bool = game_state.is_first_turn_for_player(player_index)
	var is_going_first: bool = player_index == game_state.first_player_index
	var data := {
		"battle_context_schema": "battle_context_compact_v1",
		"turn_number": int(game_state.turn_number),
		"player_index": player_index,
		"opponent_player_index": opponent_index,
		"phase": _phase_name(int(game_state.phase)),
		"can_attack": not (is_first_turn and is_going_first),
		"can_use_supporter": not game_state.supporter_used_this_turn and not (is_first_turn and is_going_first),
		"energy_attached_this_turn": game_state.energy_attached_this_turn,
		"supporter_used_this_turn": game_state.supporter_used_this_turn,
		"retreat_used_this_turn": game_state.retreat_used_this_turn,
		"hidden_information_policy": "own hand and all public board card rules are visible; opponent hand/deck/prizes hidden except counts; choose only legal_actions",
		"my": _compact_player(player, true),
	}
	if opponent != null:
		data["opponent"] = _compact_player(opponent, false)
	data["tactical_summary"] = _compact_tactical_summary(game_state, player, opponent, player_index)
	if game_state.stadium_card != null and game_state.stadium_card.card_data != null:
		data["stadium"] = _compact_card_rule_entry(game_state.stadium_card.card_data)
	else:
		data["stadium"] = {}
	return data


func _compact_tactical_summary(game_state: GameState, player: PlayerState, opponent: PlayerState, player_index: int) -> Dictionary:
	var summary := {
		"combo_hints": _compact_combo_hints(player),
		"hand_resources": _compact_hand_resource_summary(player),
		"discard_energy": _compact_discard_energy_summary(player),
		"prize_race": _compact_prize_race(player, opponent),
		"attack_pressure": _compact_attack_pressure(player, opponent),
	}
	return summary


func _compact_combo_hints(player: PlayerState) -> PackedStringArray:
	return PackedStringArray([
		"Prefer immediate KO or actions that create next-turn prize pressure.",
		"Do not spend draw/discard resources after the attack line is already available.",
		"Use card_rules and deck_strategy_hints to decide which visible engines matter for this deck.",
	])


func _compact_hand_resource_summary(player: PlayerState) -> Dictionary:
	var summary := {
		"energy": {},
		"supporters": [],
		"search_or_ball": [],
		"switch_or_gust": [],
		"draw_or_churn": [],
	}
	if player == null:
		return summary
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		var cd: CardData = card.card_data
		var name := _best_card_name(cd)
		if cd.is_energy():
			var energy_type := str(cd.energy_provides)
			(summary["energy"] as Dictionary)[energy_type] = int((summary["energy"] as Dictionary).get(energy_type, 0)) + 1
			continue
		var card_type := str(cd.card_type)
		if card_type == "Supporter":
			_append_limited_unique(summary["supporters"] as Array, name, 5)
		if _name_has_any(name, ["Ball", "Poffin", "Vessel", "Pokegear", "Artazon", "Candy"]):
			_append_limited_unique(summary["search_or_ball"] as Array, name, 6)
		if _name_has_any(name, ["Switch", "Catcher", "Boss"]):
			_append_limited_unique(summary["switch_or_gust"] as Array, name, 5)
		if _name_has_any(name, ["Iono", "Research", "Shoes", "Squawkabilly", "Greninja", "Retrieval"]):
			_append_limited_unique(summary["draw_or_churn"] as Array, name, 6)
	return summary


func _compact_discard_energy_summary(player: PlayerState) -> Dictionary:
	var result := {}
	if player == null:
		return result
	for card: CardInstance in player.discard_pile:
		if card == null or card.card_data == null or not card.card_data.is_energy():
			continue
		var energy_type := str(card.card_data.energy_provides)
		result[energy_type] = int(result.get(energy_type, 0)) + 1
	return result


func _compact_prize_race(player: PlayerState, opponent: PlayerState) -> Dictionary:
	var my_remaining := player.prizes.size() if player != null else 0
	var opp_remaining := opponent.prizes.size() if opponent != null else 0
	return {
		"my_remaining": my_remaining,
		"opponent_remaining": opp_remaining,
		"my_taken": maxi(0, 6 - my_remaining),
		"opponent_taken": maxi(0, 6 - opp_remaining),
	}


func _compact_attack_pressure(player: PlayerState, opponent: PlayerState) -> Dictionary:
	var pressure := {
		"opponent_active_remaining_hp": 0,
		"my_active_attack_names": [],
		"raging_bolt_board_basic_energy": 0,
		"raging_bolt_burst_damage_if_all_basic_discarded": 0,
		"raging_bolt_burst_kos_opponent_active": false,
	}
	if player == null:
		return pressure
	var opponent_hp := 0
	if opponent != null and opponent.active_pokemon != null:
		opponent_hp = opponent.active_pokemon.get_remaining_hp()
	pressure["opponent_active_remaining_hp"] = opponent_hp
	if player.active_pokemon != null and player.active_pokemon.get_card_data() != null:
		var attacks: Array = player.active_pokemon.get_card_data().attacks
		var names: Array[String] = []
		for attack: Dictionary in attacks:
			names.append(str(attack.get("name", "")))
		pressure["my_active_attack_names"] = names
	var board_basic_energy := _count_board_basic_energy(player)
	pressure["raging_bolt_board_basic_energy"] = board_basic_energy
	pressure["raging_bolt_burst_damage_if_all_basic_discarded"] = board_basic_energy * 70
	pressure["raging_bolt_burst_kos_opponent_active"] = opponent_hp > 0 and board_basic_energy * 70 >= opponent_hp
	return pressure


func _count_board_basic_energy(player: PlayerState) -> int:
	if player == null:
		return 0
	var total := 0
	var slots: Array[PokemonSlot] = []
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	for slot: PokemonSlot in slots:
		for energy: CardInstance in slot.attached_energy:
			if energy != null and energy.card_data != null and energy.card_data.is_energy():
				total += 1
	return total


func _compact_player(player: PlayerState, include_hand: bool) -> Dictionary:
	var data := {
		"prizes_remaining": player.prizes.size(),
		"hand_count": player.hand.size(),
		"deck_count": player.deck.size(),
		"discard": _compact_card_counts(player.discard_pile, 12),
		"active": _compact_slot(player.active_pokemon, "active"),
		"bench": [],
	}
	for i: int in player.bench.size():
		var slot_data: Dictionary = _compact_slot(player.bench[i], "bench_%d" % i)
		if not slot_data.is_empty():
			(data["bench"] as Array).append(slot_data)
	if include_hand:
		data["hand"] = _compact_card_counts(player.hand)
		data["energy_in_hand"] = _count_hand_energy(player)
	return data


func _compact_slot(slot: PokemonSlot, position: String) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {}
	var cd: CardData = slot.get_card_data()
	var data := {
		"position": position,
		"name": str(slot.get_pokemon_name()),
		"name_en": str(cd.name_en),
		"card_type": str(cd.card_type),
		"stage": str(cd.stage),
		"mechanic": str(cd.mechanic),
		"tags": Array(cd.is_tags),
		"energy_type": str(cd.energy_type),
		"retreat_cost": int(cd.retreat_cost),
		"hp_remaining": slot.get_remaining_hp(),
		"max_hp": int(cd.hp),
		"damage_counters": int(slot.damage_counters),
		"attached_energy": _serialize_energy_counts(slot),
		"attached_tool": _best_card_name(slot.attached_tool.card_data) if slot.attached_tool != null and slot.attached_tool.card_data != null else "",
		"status": _active_statuses(slot.status_conditions),
	}
	data["attacks"] = _compact_attack_rules(cd)
	data["abilities"] = _compact_ability_rules(cd)
	return data


func _compact_deck_strategy_prompt() -> PackedStringArray:
	var lines := PackedStringArray()
	for i: int in mini(_deck_strategy_prompt.size(), 3):
		var line: String = str(_deck_strategy_prompt[i]).strip_edges()
		if line != "":
			lines.append(line)
	for i: int in _deck_strategy_prompt.size():
		if lines.size() >= 8:
			break
		var line: String = str(_deck_strategy_prompt[i]).strip_edges()
		if line == "":
			continue
		if not (
			line.contains("执行边界")
			or line.contains("决策树形状")
			or line.contains("兜底")
			or line.contains("工具")
			or line.contains("护符")
		):
			continue
		if not (line in lines):
			lines.append(line)
	return lines


func _compact_card_counts(cards: Array[CardInstance], max_groups: int = -1) -> Array[Dictionary]:
	var groups := {}
	for card: CardInstance in cards:
		if card == null or card.card_data == null:
			continue
		var cd: CardData = card.card_data
		var key: String = _card_group_key(cd)
		if groups.has(key):
			groups[key]["count"] = int(groups[key]["count"]) + 1
			continue
		var entry := {
			"name": _best_card_name(cd),
			"name_en": str(cd.name_en),
			"type": str(cd.card_type),
			"count": 1,
			"card_rules": _compact_card_rule_entry(cd),
		}
		if cd.is_energy():
			entry["energy"] = str(cd.energy_provides)
		groups[key] = entry
	var result: Array[Dictionary] = []
	for key: String in groups.keys():
		result.append(groups[key])
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ac := int(a.get("count", 0))
		var bc := int(b.get("count", 0))
		if ac == bc:
			return str(a.get("name", "")) < str(b.get("name", ""))
		return ac > bc
	)
	if max_groups > 0 and result.size() > max_groups:
		var omitted_cards := 0
		for i: int in range(max_groups, result.size()):
			omitted_cards += int((result[i] as Dictionary).get("count", 0))
		result = result.slice(0, max_groups)
		result.append({
			"name": "__omitted_visible_discard_cards__",
			"type": "summary",
			"count": omitted_cards,
		})
	return result


func _compact_card_rule_entry(cd: CardData) -> Dictionary:
	if cd == null:
		return {}
	var entry := {
		"name": _best_card_name(cd),
		"name_en": str(cd.name_en),
		"card_type": str(cd.card_type),
		"mechanic": str(cd.mechanic),
		"effect_id": str(cd.effect_id),
		"tags": Array(cd.is_tags),
	}
	if cd.description != "":
		entry["description"] = str(cd.description)
	if cd.is_pokemon():
		entry["stage"] = str(cd.stage)
		entry["energy_type"] = str(cd.energy_type)
		entry["hp"] = int(cd.hp)
		entry["retreat_cost"] = int(cd.retreat_cost)
		entry["attacks"] = _compact_attack_rules(cd)
		entry["abilities"] = _compact_ability_rules(cd)
	if cd.is_energy():
		entry["energy_provides"] = str(cd.energy_provides)
	return entry


func _compact_attack_rules(cd: CardData) -> Array[Dictionary]:
	var attacks: Array[Dictionary] = []
	if cd == null:
		return attacks
	for i: int in cd.attacks.size():
		var attack: Dictionary = cd.attacks[i]
		attacks.append({
			"index": i,
			"name": str(attack.get("name", "")),
			"cost": str(attack.get("cost", "")),
			"damage": str(attack.get("damage", "")),
			"text": str(attack.get("text", "")),
			"is_vstar_power": bool(attack.get("is_vstar_power", false)),
		})
	return attacks


func _compact_ability_rules(cd: CardData) -> Array[Dictionary]:
	var abilities: Array[Dictionary] = []
	if cd == null:
		return abilities
	for i: int in cd.abilities.size():
		var ability: Dictionary = cd.abilities[i]
		abilities.append({
			"index": i,
			"name": str(ability.get("name", "")),
			"text": str(ability.get("text", "")),
		})
	return abilities


func _legal_action_summary(ref: Dictionary) -> String:
	var kind: String = str(ref.get("type", ""))
	match kind:
		"attach_energy":
			return "attach %s to %s %s" % [str(ref.get("energy_type", ref.get("card", ""))), str(ref.get("position", "")), str(ref.get("target", ""))]
		"attach_tool":
			return "attach tool %s to %s %s" % [str(ref.get("card", "")), str(ref.get("position", "")), str(ref.get("target", ""))]
		"play_basic_to_bench":
			return "bench %s" % str(ref.get("card", ""))
		"evolve":
			return "evolve %s %s into %s" % [str(ref.get("position", "")), str(ref.get("target", "")), str(ref.get("card", ""))]
		"play_trainer", "play_stadium":
			return "play %s" % str(ref.get("card", ""))
		"use_ability":
			return "use %s ability %s from %s" % [str(ref.get("pokemon", "")), str(ref.get("ability", "")), str(ref.get("position", ""))]
		"retreat":
			return "retreat to %s %s" % [str(ref.get("bench_position", "")), str(ref.get("bench_target", ""))]
		"attack", "granted_attack":
			return "attack with %s" % str(ref.get("attack_name", ""))
		"end_turn":
			return "end turn"
	return kind


func _card_rule_summary(cd: CardData, action_kind: String) -> Dictionary:
	if cd == null:
		return {}
	var text: String = _compact_rule_text(str(cd.description), 220)
	var tags: Array[String] = _infer_rule_tags(cd, action_kind, text)
	return {
		"name": _best_card_name(cd),
		"card_type": str(cd.card_type),
		"effect_id": str(cd.effect_id),
		"text": text,
		"tags": tags,
		"interaction_hints": _interaction_hints_for_tags(tags),
	}


func _ability_rule_summary(action: Dictionary) -> Dictionary:
	var source_slot: Variant = action.get("source_slot")
	var ability_index: int = int(action.get("ability_index", -1))
	if not (source_slot is PokemonSlot):
		return {}
	var cd: CardData = (source_slot as PokemonSlot).get_card_data()
	if cd == null or ability_index < 0 or ability_index >= cd.abilities.size():
		return {}
	var ability: Dictionary = cd.abilities[ability_index]
	var text: String = _compact_rule_text(str(ability.get("text", "")), 180)
	var combined_text := "%s %s" % [str(ability.get("name", "")), text]
	var tags: Array[String] = _infer_text_tags(combined_text)
	return {
		"name": str(ability.get("name", "")),
		"text": text,
		"tags": tags,
		"interaction_hints": _interaction_hints_for_tags(tags),
	}


func _attack_rule_summary(action: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	var attack_data: Dictionary = {}
	if str(action.get("kind", "")) == "granted_attack":
		var granted: Variant = action.get("granted_attack_data", {})
		if granted is Dictionary:
			attack_data = granted
	else:
		if game_state == null or player_index < 0 or player_index >= game_state.players.size():
			return {}
		var active: PokemonSlot = game_state.players[player_index].active_pokemon
		if active == null or active.get_card_data() == null:
			return {}
		var attack_index: int = int(action.get("attack_index", -1))
		if attack_index < 0 or attack_index >= active.get_card_data().attacks.size():
			return {}
		attack_data = active.get_card_data().attacks[attack_index]
	var text: String = _compact_rule_text(str(attack_data.get("text", "")), 180)
	var combined_text := "%s %s %s" % [str(attack_data.get("name", "")), str(attack_data.get("damage", "")), text]
	var tags: Array[String] = _infer_text_tags(combined_text)
	return {
		"name": str(attack_data.get("name", "")),
		"cost": str(attack_data.get("cost", "")),
		"damage": str(attack_data.get("damage", "")),
		"text": text,
		"tags": tags,
		"interaction_hints": _interaction_hints_for_tags(tags),
	}


func _attack_quality_summary_from_attack(attack: Dictionary, attack_index: int) -> Dictionary:
	var text := _compact_rule_text(str(attack.get("text", "")), 180)
	var combined_text := "%s %s %s" % [str(attack.get("name", "")), str(attack.get("damage", "")), text]
	return _attack_quality_summary({
		"name": str(attack.get("name", "")),
		"cost": str(attack.get("cost", "")),
		"damage": str(attack.get("damage", "")),
		"text": text,
		"tags": _infer_text_tags(combined_text),
	}, attack_index)


func _attack_quality_summary(raw_rules: Variant, attack_index: int) -> Dictionary:
	var rules: Dictionary = raw_rules if raw_rules is Dictionary else {}
	var damage := str(rules.get("damage", "")).strip_edges()
	var text := str(rules.get("text", "")).to_lower()
	var name := str(rules.get("name", ""))
	var tags: Array = rules.get("tags", []) if rules.get("tags", []) is Array else []
	var has_damage := damage != ""
	var is_draw_or_search := tags.has("draw") or tags.has("search_deck")
	var is_discard := tags.has("discard")
	var discards_entire_hand := is_discard and (text.contains("hand") or text.contains("手牌") or text.contains("全部"))
	if not has_damage and (is_draw_or_search or is_discard or attack_index == 0):
		return {
			"role": "desperation_redraw" if is_discard else "setup_draw",
			"terminal_priority": "low",
			"discard_entire_hand": discards_entire_hand,
			"takes_prize": false,
			"reason": "non-damage setup/redraw attack; use only when no productive setup or primary damage route exists",
		}
	if has_damage:
		var role := "primary_damage" if attack_index > 0 else "chip_damage"
		var priority := "high" if attack_index > 0 else "medium"
		return {
			"role": role,
			"terminal_priority": priority,
			"discard_entire_hand": false,
			"takes_prize": true,
			"reason": "damage attack",
		}
	return {
		"role": "utility_attack",
		"terminal_priority": "medium",
		"discard_entire_hand": false,
		"takes_prize": false,
		"reason": "utility attack",
		"name": name,
	}


func _compact_rule_text(text: String, limit: int) -> String:
	var cleaned: String = text.replace("\r", " ").replace("\n", " ").strip_edges()
	while cleaned.contains("  "):
		cleaned = cleaned.replace("  ", " ")
	if limit > 0 and cleaned.length() > limit:
		return cleaned.substr(0, limit - 3) + "..."
	return cleaned


func _infer_rule_tags(cd: CardData, action_kind: String, text: String) -> Array[String]:
	var tags: Array[String] = _infer_text_tags(text)
	for tag: String in EFFECT_ID_RULE_TAGS.get(str(cd.effect_id), []):
		_append_tag(tags, tag)
	match action_kind:
		"play_basic_to_bench":
			_append_tag(tags, "bench_basic")
		"evolve":
			_append_tag(tags, "evolution")
		"attach_energy":
			_append_tag(tags, "manual_energy")
		"attach_tool":
			_append_tag(tags, "tool_modifier")
		"play_stadium":
			_append_tag(tags, "stadium_modifier")
		"use_ability":
			_append_tag(tags, "ability")
		"attack", "granted_attack":
			_append_tag(tags, "attack")
	if cd.is_pokemon():
		_append_tag(tags, "pokemon")
		if cd.stage == "Basic":
			_append_tag(tags, "basic_pokemon")
		elif cd.stage != "":
			_append_tag(tags, "evolution_pokemon")
		if not cd.abilities.is_empty():
			_append_tag(tags, "has_ability")
		if not cd.attacks.is_empty():
			_append_tag(tags, "attacker_candidate")
	if cd.is_energy():
		_append_tag(tags, "energy_resource")
	return tags


func _infer_text_tags(text: String) -> Array[String]:
	var lower: String = text.to_lower()
	var tags: Array[String] = []
	if _contains_any(lower, ["牌库", "deck", "search", "选择自己牌库"]):
		_append_tag(tags, "search_deck")
	if _contains_any(lower, ["宝可梦", "pokemon"]):
		_append_tag(tags, "pokemon_related")
	if _contains_any(lower, ["基本能量", "energy", "能量"]):
		_append_tag(tags, "energy_related")
	if _contains_any(lower, ["弃牌", "discard", "放于弃牌区"]):
		_append_tag(tags, "discard")
	if _contains_any(lower, ["抽取", "draw", "抽", "查看", "牌库上方"]):
		_append_tag(tags, "draw")
	if _contains_any(lower, ["备战区", "bench"]):
		_append_tag(tags, "bench_related")
	if _contains_any(lower, ["互换", "switch", "撤退", "retreat"]):
		_append_tag(tags, "switch_or_retreat")
	if _contains_any(lower, ["对手的1只备战", "gust", "抓", "将其与战斗宝可梦互换"]):
		_append_tag(tags, "gust")
	if _contains_any(lower, ["伤害指示物", "damage counter"]):
		_append_tag(tags, "damage_counters")
	if _contains_any(lower, ["昏厥", "knock out", "knocked out"]):
		_append_tag(tags, "ko_related")
	if _contains_any(lower, ["回复", "加入手牌", "recover", "put into your hand"]):
		_append_tag(tags, "recover_to_hand")
	if _contains_any(lower, ["进化", "evolve"]):
		_append_tag(tags, "evolution")
	if _contains_any(lower, ["支援者", "supporter"]):
		_append_tag(tags, "supporter_related")
	if _contains_any(lower, ["物品", "item"]):
		_append_tag(tags, "item_related")
	if _contains_any(lower, ["宝可梦道具", "tool"]):
		_append_tag(tags, "tool_related")
	if _contains_any(lower, ["竞技场", "stadium"]):
		_append_tag(tags, "stadium_related")
	return tags


func _interaction_hints_for_tags(tags: Array[String]) -> Dictionary:
	var hints := {}
	if "search_deck" in tags:
		hints["search"] = "name the exact missing card type or card names for this route"
	if "discard" in tags:
		hints["discard"] = "discard expendable cards or fuel only when it improves the route"
	if "energy_related" in tags:
		hints["energy"] = "specify energy type and target when the effect asks"
	if "gust" in tags:
		hints["gust_target"] = "pick a target that can be KO'd or disrupts the opponent plan"
	if "switch_or_retreat" in tags:
		hints["switch_target"] = "pick the attacker or safest pivot by board position"
	if "damage_counters" in tags:
		hints["damage_target"] = "choose bench/active targets by prize map and remaining HP"
	return hints


func _interaction_schema_for_ref(ref: Dictionary) -> Dictionary:
	var tags: Array[String] = _ref_rule_tags(ref)
	var schema := {}
	if _is_hand_energy_attach_ability_ref(ref, tags):
		schema["basic_energy_from_hand"] = {
			"type": "string",
			"item": "exact hand card id such as c21, or exact visible Grass Energy name",
			"examples": _hand_energy_examples_for_ref(ref, "G"),
			"max_select": 1,
			"note": "This is not a deck search. Choose one Basic Grass Energy currently in hand to attach to this Pokemon.",
		}
		schema["energy_card_id"] = {
			"type": "string",
			"item": "exact hand card id for the Basic Grass Energy to attach",
		}
		return schema
	if tags.has("discard"):
		if tags.has("energy_related"):
			schema["discard_cards"] = {
				"type": "array",
				"items": "exact hand card id or visible card name",
				"prefer": ["Grass Energy", "Lightning Energy", "Fighting Energy"],
				"max_select": 1,
			}
			schema["discard_card"] = {
				"type": "string",
				"item": "exact hand card id or visible card name",
				"prefer": "expendable Energy when it fuels the route",
			}
		else:
			schema["discard_cards"] = {"type": "array", "items": "exact hand card id or visible card name"}
	if tags.has("search_deck"):
		if tags.has("energy_related"):
			schema["search_energy"] = {
				"type": "array",
				"items": "exact Energy names copied from visible card data",
				"examples": ["Lightning Energy", "Fighting Energy", "Grass Energy"],
				"max_select": 2,
			}
			schema["search_targets"] = {
				"type": "array",
				"items": "exact Energy names copied from visible card data",
				"max_select": 2,
			}
		else:
			schema["search_targets"] = {"type": "array", "items": "exact card names copied from visible card data"}
	if tags.has("recover_to_hand"):
		if tags.has("energy_related") and not tags.has("pokemon_related"):
			schema["recover_energy"] = {
				"type": "array",
				"items": "exact Basic Energy names or discard card ids copied from visible discard",
				"examples": ["Lightning Energy", "Fighting Energy", "Grass Energy"],
				"max_select": 2,
			}
		else:
			schema["night_stretcher_choice"] = {
				"type": "string",
				"item": "exact discard card id or visible card name for one Pokemon or Basic Energy",
				"examples": ["Raging Bolt ex", "Lightning Energy", "Fighting Energy", "Grass Energy"],
				"max_select": 1,
			}
			schema["recover_target"] = {
				"type": "string",
				"item": "exact discard card id or visible card name",
			}
			schema["recover_card"] = {
				"type": "string",
				"item": "exact discard card id or visible card name",
			}
	if tags.has("gust"):
		schema["gust_target"] = {"type": "string", "items": "opponent slot position such as bench_0"}
		schema["opponent_bench_target"] = {"type": "string", "items": "opponent bench slot position such as bench_0"}
		schema["opponent_switch_target"] = {"type": "string", "items": "opponent bench slot position such as bench_0"}
	if tags.has("switch_or_retreat"):
		schema["switch_target"] = {"type": "string", "items": "own slot position such as bench_0"}
		schema["own_bench_target"] = {"type": "string", "items": "own bench slot position such as bench_0"}
	if tags.has("damage_counters"):
		schema["damage_target"] = {"type": "string or array", "items": "target slot positions and counter counts"}
	if str(ref.get("card", "")).contains("Professor Sada") or str(ref.get("card", "")).contains("奥琳"):
		schema["sada_assignments"] = {
			"type": "array",
			"items": {"energy_type": "exact Energy name", "target_position": "active/bench_N"},
			"max_select": 2,
		}
	return schema


func _is_hand_energy_attach_ability_ref(ref: Dictionary, tags: Array[String]) -> bool:
	if str(ref.get("type", "")) != "use_ability":
		return false
	if tags.has("charge_engine") and tags.has("energy_related") and tags.has("draw") and not tags.has("search_deck"):
		return true
	var pokemon_name := str(ref.get("pokemon", ref.get("card", ""))).to_lower()
	if pokemon_name.contains("ogerpon"):
		return true
	var rules: Dictionary = ref.get("card_rules", {}) if ref.get("card_rules", {}) is Dictionary else {}
	return str(rules.get("effect_id", "")) == "409898a79b38fe8ca279e7bdaf4fd52e"


func _hand_energy_examples_for_ref(ref: Dictionary, fallback_symbol: String) -> Array[String]:
	var examples: Array[String] = []
	var raw_consumes: Variant = ref.get("may_consume_hand_energy_symbols", [])
	if raw_consumes is Array:
		for raw_symbol: Variant in raw_consumes:
			var symbol := str(raw_symbol)
			if symbol == "G":
				_append_unique_string(examples, "Grass Energy")
			elif symbol != "":
				_append_unique_string(examples, _energy_word(symbol))
	if examples.is_empty():
		_append_unique_string(examples, _energy_word(fallback_symbol))
	return examples


func _append_tag(tags: Array[String], tag: String) -> void:
	if tag != "" and not tags.has(tag):
		tags.append(tag)


func _contains_any(text: String, needles: Array[String]) -> bool:
	for needle: String in needles:
		if text.contains(needle.to_lower()):
			return true
	return false


func _best_card_name(cd: CardData) -> String:
	if cd == null:
		return ""
	if str(cd.name_en).strip_edges() != "":
		return str(cd.name_en)
	return str(cd.name)


func _player_has_card_named(player: PlayerState, needle: String) -> bool:
	if player == null:
		return false
	var lower := needle.to_lower()
	var cards: Array[CardInstance] = []
	cards.append_array(player.hand)
	cards.append_array(player.discard_pile)
	for slot: PokemonSlot in _player_slots(player):
		for card: CardInstance in slot.pokemon_stack:
			cards.append(card)
	for card: CardInstance in cards:
		if card == null or card.card_data == null:
			continue
		if str(card.card_data.name_en).to_lower().contains(lower) or str(card.card_data.name).to_lower().contains(lower):
			return true
	return false


func _player_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player == null:
		return slots
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


func _name_has_any(name: String, needles: Array[String]) -> bool:
	var lower := name.to_lower()
	for needle: String in needles:
		if lower.contains(needle.to_lower()):
			return true
	return false


func _append_limited_unique(target: Array, value: String, limit: int) -> void:
	if value == "" or target.has(value) or target.size() >= limit:
		return
	target.append(value)


func _card_instance_token(value: Variant) -> String:
	if value is CardInstance:
		return "c%d" % int((value as CardInstance).instance_id)
	return "c-1"


func _card_list_token(value: Variant) -> String:
	if not (value is Array):
		return "none"
	var parts: Array[String] = []
	for card: Variant in value:
		if card is CardInstance:
			parts.append(_card_instance_token(card))
	parts.sort()
	return "-".join(parts) if not parts.is_empty() else "none"


func _slot_token(value: Variant, game_state: GameState, player_index: int) -> String:
	if not (value is PokemonSlot):
		return "none"
	var position: String = _resolve_slot_position(value as PokemonSlot, game_state, player_index)
	if position != "":
		return position
	var slot: PokemonSlot = value as PokemonSlot
	return "slot:%s" % str(slot.get_pokemon_name()).to_lower()


func _resolve_slot_position(slot: PokemonSlot, game_state: GameState, player_index: int) -> String:
	if slot == null or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return ""
	var player: PlayerState = game_state.players[player_index]
	if slot == player.active_pokemon:
		return "active"
	for i: int in player.bench.size():
		if slot == player.bench[i]:
			return "bench_%d" % i
	return ""


func _energy_word(code: String) -> String:
	match code:
		"L":
			return "Lightning"
		"F":
			return "Fighting"
		"G":
			return "Grass"
		"R":
			return "Fire"
		"W":
			return "Water"
		"P":
			return "Psychic"
		"D":
			return "Dark"
		"M":
			return "Metal"
	return code


func _ability_name_for_action(action: Dictionary) -> String:
	var source_slot: Variant = action.get("source_slot")
	var ability_index: int = int(action.get("ability_index", -1))
	if not (source_slot is PokemonSlot):
		return ""
	var cd: CardData = (source_slot as PokemonSlot).get_card_data()
	if cd == null or ability_index < 0 or ability_index >= cd.abilities.size():
		return ""
	return str((cd.abilities[ability_index] as Dictionary).get("name", ""))


func _attack_name_for_action(action: Dictionary, game_state: GameState, player_index: int) -> String:
	var kind: String = str(action.get("kind", ""))
	if kind == "granted_attack":
		var ga: Variant = action.get("granted_attack_data", {})
		if ga is Dictionary:
			return str((ga as Dictionary).get("name", ""))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return ""
	var active: PokemonSlot = game_state.players[player_index].active_pokemon
	if active == null or active.get_card_data() == null:
		return ""
	var attack_index: int = int(action.get("attack_index", -1))
	if attack_index < 0 or attack_index >= active.get_card_data().attacks.size():
		return ""
	return str((active.get_card_data().attacks[attack_index] as Dictionary).get("name", ""))


func _serialize_game_state(game_state: GameState, player: PlayerState, opponent: PlayerState, player_index: int) -> Dictionary:
	var is_first_turn: bool = game_state.is_first_turn_for_player(player_index)
	var is_going_first: bool = (player_index == game_state.first_player_index)
	var opponent_index: int = 1 - player_index
	var data := {
		"battle_context_schema": "battle_context_v2",
		"turn_number": int(game_state.turn_number),
		"player_index": player_index,
		"current_player_index": int(game_state.current_player_index),
		"opponent_player_index": opponent_index,
		"first_player_index": int(game_state.first_player_index),
		"phase": _phase_name(int(game_state.phase)),
		"is_first_turn": is_first_turn,
		"going_first": is_going_first,
		"can_use_supporter": not game_state.supporter_used_this_turn and not (is_first_turn and is_going_first),
		"can_attack": not (is_first_turn and is_going_first),
		"energy_attached_this_turn": game_state.energy_attached_this_turn,
		"supporter_used_this_turn": game_state.supporter_used_this_turn,
		"stadium_played_this_turn": game_state.stadium_played_this_turn,
		"retreat_used_this_turn": game_state.retreat_used_this_turn,
		"turn_flags": _serialize_turn_flags(game_state, player_index, opponent_index),
		"my_field": _serialize_player_field(player, true),
	}
	if opponent != null:
		data["opponent_field"] = _serialize_player_field(opponent, false)
	if game_state.stadium_card != null and game_state.stadium_card.card_data != null:
		data["stadium_in_play"] = str(game_state.stadium_card.card_data.name)
		data["stadium"] = _serialize_card_instance(game_state.stadium_card)
		data["stadium"]["owner_index"] = int(game_state.stadium_owner_index)
	else:
		data["stadium"] = {}
	return data


func _serialize_player_field(player: PlayerState, include_hand: bool) -> Dictionary:
	var field := {
		"prize_count": player.prizes.size(),
		"prizes_remaining": player.prizes.size(),
		"prizes_taken": maxi(0, 6 - player.prizes.size()),
		"hand_count": player.hand.size(),
		"deck_count": player.deck.size(),
		"discard_count": player.discard_pile.size(),
		"lost_zone_count": player.lost_zone.size(),
		"bench_count": player.bench.size(),
		"bench_space": maxi(0, 5 - player.bench.size()),
		"active": _serialize_slot(player.active_pokemon, "active"),
		"bench": _serialize_bench(player.bench),
		"discard_pile": _serialize_card_counts(player.discard_pile),
		"lost_zone": _serialize_card_counts(player.lost_zone),
	}
	if include_hand:
		field["hand"] = _serialize_hand(player)
		field["energy_in_hand"] = _count_hand_energy(player)
	return field


func _serialize_hand(player: PlayerState) -> Array[Dictionary]:
	return _serialize_card_counts(player.hand)


func _count_hand_energy(player: PlayerState) -> Dictionary:
	var counts := {}
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		if card.card_data.is_energy():
			var etype: String = str(card.card_data.energy_provides)
			counts[etype] = int(counts.get(etype, 0)) + 1
	return counts


func _serialize_slot(slot: PokemonSlot, position: String = "") -> Dictionary:
	if slot == null or slot.get_top_card() == null:
		return {}
	var cd: CardData = slot.get_card_data()
	var data := {
		"name": str(slot.get_pokemon_name()),
		"name_en": str(cd.name_en) if cd != null else "",
		"card_type": str(cd.card_type) if cd != null else "",
		"stage": str(cd.stage) if cd != null else "",
		"mechanic": str(cd.mechanic) if cd != null else "",
		"tags": Array(cd.is_tags) if cd != null else [],
		"energy_type": str(cd.energy_type) if cd != null else "",
		"evolves_from": str(cd.evolves_from) if cd != null else "",
		"hp": slot.get_remaining_hp(),
		"hp_remaining": slot.get_remaining_hp(),
		"max_hp": int(cd.hp) if cd != null else 0,
		"damage_counters": int(slot.damage_counters),
		"prize_count_if_knocked_out": slot.get_prize_count(),
		"attached_energy": _serialize_energy_counts(slot),
		"attached_energy_cards": _serialize_energy_cards(slot),
		"attached_tool": _serialize_card_instance(slot.attached_tool),
		"retreat_cost": int(cd.retreat_cost) if cd != null else 0,
		"weakness": {
			"energy": str(cd.weakness_energy) if cd != null else "",
			"value": str(cd.weakness_value) if cd != null else "",
		},
		"resistance": {
			"energy": str(cd.resistance_energy) if cd != null else "",
			"value": str(cd.resistance_value) if cd != null else "",
		},
		"status_conditions": slot.status_conditions.duplicate(true),
		"active_statuses": _active_statuses(slot.status_conditions),
		"effects": _serialize_effects(slot.effects),
		"turn_played": int(slot.turn_played),
		"turn_evolved": int(slot.turn_evolved),
	}
	if position != "":
		data["position"] = position
	if cd != null:
		if not cd.attacks.is_empty():
			var attacks: Array[Dictionary] = []
			for attack: Dictionary in cd.attacks:
				attacks.append({
					"name": str(attack.get("name", "")),
					"damage": str(attack.get("damage", "0")),
					"cost": str(attack.get("cost", "")),
					"text": str(attack.get("text", "")),
					"is_vstar_power": bool(attack.get("is_vstar_power", false)),
				})
			data["attacks"] = attacks
		if not cd.abilities.is_empty():
			var abilities: Array[Dictionary] = []
			for ability: Dictionary in cd.abilities:
				abilities.append({
					"name": str(ability.get("name", "")),
					"text": str(ability.get("text", "")),
				})
			data["abilities"] = abilities
	return data


func _serialize_energy_counts(slot: PokemonSlot) -> Dictionary:
	var counts := {}
	for card: CardInstance in slot.attached_energy:
		if card == null or card.card_data == null:
			continue
		var energy_type: String = str(card.card_data.energy_provides)
		counts[energy_type] = int(counts.get(energy_type, 0)) + 1
	return counts


func _serialize_energy_cards(slot: PokemonSlot) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card: CardInstance in slot.attached_energy:
		var entry := _serialize_card_instance(card)
		if not entry.is_empty():
			result.append(entry)
	return result


func _serialize_bench(slots: Array[PokemonSlot]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i: int in slots.size():
		var serialized := _serialize_slot(slots[i], "bench_%d" % i)
		if not serialized.is_empty():
			result.append(serialized)
	return result


func _serialize_card_counts(cards: Array[CardInstance]) -> Array[Dictionary]:
	var groups := {}
	for card: CardInstance in cards:
		if card == null or card.card_data == null:
			continue
		var key: String = _card_group_key(card.card_data)
		if groups.has(key):
			groups[key]["count"] = int(groups[key]["count"]) + 1
			continue
		var entry := _serialize_card_data(card.card_data)
		entry["count"] = 1
		groups[key] = entry
	var result: Array[Dictionary] = []
	for key: String in groups:
		result.append(groups[key])
	return result


func _serialize_turn_flags(game_state: GameState, player_index: int, opponent_index: int) -> Dictionary:
	return {
		"energy_attached_this_turn": bool(game_state.energy_attached_this_turn),
		"supporter_used_this_turn": bool(game_state.supporter_used_this_turn),
		"stadium_played_this_turn": bool(game_state.stadium_played_this_turn),
		"retreat_used_this_turn": bool(game_state.retreat_used_this_turn),
		"stadium_effect_used_turn": int(game_state.stadium_effect_used_turn),
		"stadium_effect_used_player": int(game_state.stadium_effect_used_player),
		"stadium_effect_used_effect_id": str(game_state.stadium_effect_used_effect_id),
		"my_vstar_power_used": bool(game_state.vstar_power_used[player_index]) if player_index >= 0 and player_index < game_state.vstar_power_used.size() else false,
		"opponent_vstar_power_used": bool(game_state.vstar_power_used[opponent_index]) if opponent_index >= 0 and opponent_index < game_state.vstar_power_used.size() else false,
		"my_last_knockout_turn_against": int(game_state.last_knockout_turn_against[player_index]) if player_index >= 0 and player_index < game_state.last_knockout_turn_against.size() else -999,
		"opponent_last_knockout_turn_against": int(game_state.last_knockout_turn_against[opponent_index]) if opponent_index >= 0 and opponent_index < game_state.last_knockout_turn_against.size() else -999,
		"shared_turn_flags": game_state.shared_turn_flags.duplicate(true),
	}


func _serialize_card_instance(card: CardInstance) -> Dictionary:
	if card == null or card.card_data == null:
		return {}
	var entry := _serialize_card_data(card.card_data)
	entry["instance_id"] = int(card.instance_id)
	entry["owner_index"] = int(card.owner_index)
	entry["face_up"] = bool(card.face_up)
	return entry


func _serialize_card_data(cd: CardData) -> Dictionary:
	if cd == null:
		return {}
	var entry := {
		"name": str(cd.name),
		"name_en": str(cd.name_en),
		"card_type": str(cd.card_type),
		"type": str(cd.card_type),
		"mechanic": str(cd.mechanic),
		"label": str(cd.label),
		"effect_id": str(cd.effect_id),
		"set_code": str(cd.set_code),
		"card_index": str(cd.card_index),
		"tags": Array(cd.is_tags),
	}
	if cd.is_pokemon():
		entry["stage"] = str(cd.stage)
		entry["energy_type"] = str(cd.energy_type)
		entry["hp"] = int(cd.hp)
		entry["evolves_from"] = str(cd.evolves_from)
		entry["retreat_cost"] = int(cd.retreat_cost)
		entry["weakness"] = {"energy": str(cd.weakness_energy), "value": str(cd.weakness_value)}
		entry["resistance"] = {"energy": str(cd.resistance_energy), "value": str(cd.resistance_value)}
		entry["prize_count_if_knocked_out"] = int(cd.get_prize_count())
		if not cd.attacks.is_empty():
			entry["attacks"] = cd.attacks.duplicate(true)
		if not cd.abilities.is_empty():
			entry["abilities"] = cd.abilities.duplicate(true)
	if cd.is_energy():
		entry["energy_provides"] = str(cd.energy_provides)
	if cd.description != "":
		entry["description"] = str(cd.description)
	return entry


func _serialize_effects(effects: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for effect_data: Dictionary in effects:
		result.append(effect_data.duplicate(true))
	return result


func _active_statuses(status_conditions: Dictionary) -> Array[String]:
	var statuses: Array[String] = []
	for status_name: String in status_conditions:
		if bool(status_conditions.get(status_name, false)):
			statuses.append(status_name)
	return statuses


func _card_group_key(cd: CardData) -> String:
	if cd == null:
		return ""
	return "%s|%s|%s" % [str(cd.name), str(cd.set_code), str(cd.card_index)]


func _phase_name(phase_value: int) -> String:
	match phase_value:
		GameState.GamePhase.SETUP:
			return "SETUP"
		GameState.GamePhase.MULLIGAN:
			return "MULLIGAN"
		GameState.GamePhase.SETUP_PLACE:
			return "SETUP_PLACE"
		GameState.GamePhase.DRAW:
			return "DRAW"
		GameState.GamePhase.MAIN:
			return "MAIN"
		GameState.GamePhase.ATTACK:
			return "ATTACK"
		GameState.GamePhase.POKEMON_CHECK:
			return "POKEMON_CHECK"
		GameState.GamePhase.BETWEEN_TURNS:
			return "BETWEEN_TURNS"
		GameState.GamePhase.KNOCKOUT_REPLACE:
			return "KNOCKOUT_REPLACE"
		GameState.GamePhase.GAME_OVER:
			return "GAME_OVER"
		_:
			return str(phase_value)
