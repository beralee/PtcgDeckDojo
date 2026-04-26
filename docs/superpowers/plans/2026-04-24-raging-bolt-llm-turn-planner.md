# Raging Bolt LLM Turn Planner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a new "猛雷鼓 LLM版" AI strategy that calls an LLM each turn to decide the turn intent, then feeds it into the existing turn-contract scoring pipeline — selectable in-game alongside the rule-based version.

**Architecture:** `DeckStrategyRagingBoltLLM` extends the rule-based `DeckStrategyRagingBoltOgerpon`. It overrides `build_turn_plan()` to return a cached LLM plan when available, falling back to the rule-based plan while the LLM call is in flight. A separate `LLMTurnPlanPromptBuilder` serializes game state to a compact prompt and defines a strict JSON response schema that maps directly to the existing turn-contract format. The strategy is registered in `DeckStrategyRegistry` and wired through `BattleScene` for game selection.

**Tech Stack:** GDScript (Godot 4.x), ZenMuxClient (OpenAI-compatible HTTP), existing turn-contract pipeline

---

### File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `scripts/ai/LLMTurnPlanPromptBuilder.gd` | Create | Serialize game state → prompt, define response JSON schema, parse LLM response into turn-contract dict |
| `scripts/ai/DeckStrategyRagingBoltLLM.gd` | Create | Extend rule-based strategy, override `build_turn_plan()` with LLM cache + fallback, manage async LLM lifecycle |
| `scripts/ai/DeckStrategyRegistry.gd` | Modify | Register `raging_bolt_ogerpon_llm` strategy ID |
| `scenes/battle/BattleScene.gd` | Modify | Pass host node to LLM strategy after construction |
| `tests/test_future_ancient_strategies.gd` | Modify | Add unit tests for prompt builder and LLM strategy |

---

### Task 1: LLMTurnPlanPromptBuilder — prompt construction and response parsing

**Files:**
- Create: `scripts/ai/LLMTurnPlanPromptBuilder.gd`
- Test: `tests/test_future_ancient_strategies.gd`

- [ ] **Step 1: Write failing tests for the prompt builder**

Append to `tests/test_future_ancient_strategies.gd`:

```gdscript
const LLM_PROMPT_BUILDER_SCRIPT_PATH := "res://scripts/ai/LLMTurnPlanPromptBuilder.gd"


func test_llm_prompt_builder_builds_payload_with_game_state() -> String:
	var script := _load_script(LLM_PROMPT_BUILDER_SCRIPT_PATH)
	if script == null:
		return "LLMTurnPlanPromptBuilder.gd should exist"
	var builder: RefCounted = script.new()
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.hand.append(CardInstance.create(_make_trainer_cd("Professor Sada's Vitality", "Supporter"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var payload: Dictionary = builder.call("build_request_payload", gs, 0)
	return run_checks([
		assert_true(payload.has("instructions"), "payload应包含instructions"),
		assert_true(payload.has("response_format"), "payload应包含response_format"),
		assert_true(str(payload.get("system_prompt_version", "")).begins_with("llm_turn_plan"),
			"system_prompt_version应以llm_turn_plan开头"),
	])


func test_llm_prompt_builder_parses_valid_response() -> String:
	var script := _load_script(LLM_PROMPT_BUILDER_SCRIPT_PATH)
	if script == null:
		return "LLMTurnPlanPromptBuilder.gd should exist"
	var builder: RefCounted = script.new()
	var response := {
		"intent": "charge_bolt",
		"primary_target": "Raging Bolt ex",
		"priority_actions": ["play Sada", "attach energy to Bolt"],
		"suppress_supporters": ["Iono"],
		"reasoning": "弃牌堆有2能量，手有Sada",
	}
	var plan: Dictionary = builder.call("parse_llm_response_to_turn_plan", response)
	return run_checks([
		assert_eq(str(plan.get("intent", "")), "charge_bolt", "intent应映射"),
		assert_true(plan.has("flags"), "plan应包含flags"),
		assert_true(plan.has("targets"), "plan应包含targets"),
		assert_eq(str(plan.get("targets", {}).get("primary_attacker_name", "")),
			"Raging Bolt ex", "primary_target应映射到targets"),
	])


func test_llm_prompt_builder_rejects_invalid_intent() -> String:
	var script := _load_script(LLM_PROMPT_BUILDER_SCRIPT_PATH)
	if script == null:
		return "LLMTurnPlanPromptBuilder.gd should exist"
	var builder: RefCounted = script.new()
	var response := {
		"intent": "invalid_intent_name",
		"primary_target": "",
		"priority_actions": [],
		"suppress_supporters": [],
		"reasoning": "",
	}
	var plan: Dictionary = builder.call("parse_llm_response_to_turn_plan", response)
	return run_checks([
		assert_true(plan.is_empty(), "无效intent应返回空plan（触发fallback）"),
	])
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/FunctionalTestRunner.gd -- --suite=FutureAncientStrategies --filter=llm_prompt`
Expected: FAIL (script not found)

- [ ] **Step 3: Implement LLMTurnPlanPromptBuilder**

Create `scripts/ai/LLMTurnPlanPromptBuilder.gd`:

```gdscript
class_name LLMTurnPlanPromptBuilder
extends RefCounted

const SCHEMA_VERSION := "llm_turn_plan_v1"

const VALID_INTENTS: Array[String] = [
	"setup_board", "fuel_discard", "charge_bolt",
	"pressure_expand", "convert_attack", "emergency_retreat",
]


func build_request_payload(game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	var opponent_index: int = 1 - player_index
	var opponent: PlayerState = game_state.players[opponent_index] if opponent_index >= 0 and opponent_index < game_state.players.size() else null
	return {
		"system_prompt_version": SCHEMA_VERSION,
		"response_format": response_schema(),
		"instructions": instructions(),
		"game_state": _serialize_game_state(game_state, player, opponent, player_index),
	}


func parse_llm_response_to_turn_plan(response: Dictionary) -> Dictionary:
	var intent: String = str(response.get("intent", "")).strip_edges()
	if intent not in VALID_INTENTS:
		return {}
	var primary_target: String = str(response.get("primary_target", "")).strip_edges()
	var suppress_supporters: Array = response.get("suppress_supporters", []) if response.get("suppress_supporters", []) is Array else []
	var flags := {
		"llm_driven": true,
		"hand_has_sada": false,
		"hand_has_earthen_vessel": false,
		"hand_has_energy_retrieval": false,
		"discard_has_fuel": false,
		"active_is_stuck": intent == "emergency_retreat",
		"suppress_supporters": suppress_supporters,
	}
	return {
		"intent": intent,
		"phase": "",
		"flags": flags,
		"targets": {
			"primary_attacker_name": primary_target,
			"bridge_target_name": primary_target if intent in ["charge_bolt", "fuel_discard"] else "",
			"pivot_target_name": "",
		},
		"constraints": _constraints_for_intent(intent),
		"context": {"source": "llm"},
	}


func instructions() -> PackedStringArray:
	return PackedStringArray([
		"你是猛雷鼓(Raging Bolt)卡组的策略AI。",
		"猛雷鼓卡组的核心链路：大地容器弃基础能量填弃牌堆 → 奥琳博士(Sada)从弃牌堆贴能量到猛雷鼓 → 猛雷鼓攻击。",
		"每回合只能使用一张支援者卡。如果手上有奥琳博士且弃牌堆有≥2基础能量，绝不能浪费支援者位给抽牌支援者。",
		"分析提供的场面状态，返回本回合最佳意图(intent)。",
		"可用intent: setup_board（无攻击手在场）, fuel_discard（弃牌堆能量不足需要填充）, charge_bolt（弃牌堆就绪+手有Sada可充能）, pressure_expand（一只就绪需要展开后备）, convert_attack（多只就绪应集中攻击）, emergency_retreat（前场被困需要换人）",
		"primary_target应为场上能量缺口最小的猛雷鼓ex的名字。",
		"suppress_supporters列出本回合不应使用的支援者卡名。",
		"priority_actions列出3-5步具体操作顺序。",
		"reasoning用一句话解释为什么选这个intent。",
	])


func response_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": false,
		"required": ["intent", "primary_target", "priority_actions", "suppress_supporters", "reasoning"],
		"properties": {
			"intent": {
				"type": "string",
				"enum": VALID_INTENTS,
			},
			"primary_target": {"type": "string", "maxLength": 60},
			"priority_actions": {
				"type": "array",
				"maxItems": 5,
				"items": {"type": "string", "maxLength": 120},
			},
			"suppress_supporters": {
				"type": "array",
				"maxItems": 4,
				"items": {"type": "string", "maxLength": 40},
			},
			"reasoning": {"type": "string", "maxLength": 200},
		},
	}


func _serialize_game_state(game_state: GameState, player: PlayerState, opponent: PlayerState, player_index: int) -> Dictionary:
	var data := {
		"turn_number": int(game_state.turn_number),
		"player_index": player_index,
		"my_field": _serialize_player_field(player, true),
	}
	if opponent != null:
		data["opponent_field"] = _serialize_player_field(opponent, false)
	return data


func _serialize_player_field(player: PlayerState, include_hand: bool) -> Dictionary:
	var field := {
		"prize_count": player.prizes.size(),
		"deck_count": player.deck.size(),
		"active": _serialize_slot(player.active_pokemon),
		"bench": _serialize_slot_array(player.bench),
		"discard_pile": _serialize_card_names(player.discard_pile),
	}
	if include_hand:
		field["hand"] = _serialize_hand(player)
	return field


func _serialize_hand(player: PlayerState) -> Array[Dictionary]:
	var hand: Array[Dictionary] = []
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		var entry := {"name": str(card.card_data.name), "type": str(card.card_data.card_type)}
		if card.card_data.card_type == "Pokemon":
			entry["stage"] = str(card.card_data.stage)
		hand.append(entry)
	return hand


func _serialize_slot(slot: PokemonSlot) -> Dictionary:
	if slot == null or slot.get_top_card() == null:
		return {}
	var data := {
		"name": str(slot.get_pokemon_name()),
		"hp": slot.remaining_hp,
		"max_hp": int(slot.get_card_data().hp) if slot.get_card_data() != null else 0,
		"attached_energy": _serialize_energy_counts(slot),
		"retreat_cost": int(slot.get_card_data().retreat_cost) if slot.get_card_data() != null else 0,
	}
	if slot.get_card_data() != null and not slot.get_card_data().attacks.is_empty():
		var attacks: Array[Dictionary] = []
		for attack: Dictionary in slot.get_card_data().attacks:
			attacks.append({
				"name": str(attack.get("name", "")),
				"damage": str(attack.get("damage", "0")),
				"cost": str(attack.get("cost", "")),
			})
		data["attacks"] = attacks
	return data


func _serialize_energy_counts(slot: PokemonSlot) -> Dictionary:
	var counts := {}
	for card: CardInstance in slot.attached_energy:
		if card == null or card.card_data == null:
			continue
		var energy_type: String = str(card.card_data.energy_provides)
		counts[energy_type] = int(counts.get(energy_type, 0)) + 1
	return counts


func _serialize_slot_array(slots: Array[PokemonSlot]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: PokemonSlot in slots:
		var serialized := _serialize_slot(slot)
		if not serialized.is_empty():
			result.append(serialized)
	return result


func _serialize_card_names(cards: Array[CardInstance]) -> Array[String]:
	var names: Array[String] = []
	for card: CardInstance in cards:
		if card != null and card.card_data != null:
			names.append(str(card.card_data.name))
	return names


func _constraints_for_intent(intent: String) -> Dictionary:
	match intent:
		"charge_bolt":
			return {"forbid_draw_supporter_waste": true}
		"convert_attack":
			return {"forbid_engine_churn": true}
	return {}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/FunctionalTestRunner.gd -- --suite=FutureAncientStrategies --filter=llm_prompt`
Expected: 3 PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/ai/LLMTurnPlanPromptBuilder.gd tests/test_future_ancient_strategies.gd
git commit -m "feat: add LLMTurnPlanPromptBuilder for turn intent via LLM"
```

---

### Task 2: DeckStrategyRagingBoltLLM — strategy with LLM cache + fallback

**Files:**
- Create: `scripts/ai/DeckStrategyRagingBoltLLM.gd`
- Test: `tests/test_future_ancient_strategies.gd`

- [ ] **Step 1: Write failing tests for the LLM strategy**

Append to `tests/test_future_ancient_strategies.gd`:

```gdscript
const RAGING_BOLT_LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategyRagingBoltLLM.gd"


func test_raging_bolt_llm_strategy_exists_and_extends_rule_based() -> String:
	var script := _load_script(RAGING_BOLT_LLM_SCRIPT_PATH)
	if script == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var strategy: RefCounted = script.new()
	return run_checks([
		assert_eq(str(strategy.call("get_strategy_id")), "raging_bolt_ogerpon_llm",
			"strategy_id应为raging_bolt_ogerpon_llm"),
		assert_true(strategy.call("get_signature_names").size() > 0,
			"签名名应继承自规则版"),
	])


func test_raging_bolt_llm_falls_back_to_rule_plan_when_no_cache() -> String:
	var script := _load_script(RAGING_BOLT_LLM_SCRIPT_PATH)
	if script == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var strategy: RefCounted = script.new()
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_ogerpon_cd(), 0)
	player.bench.append(_make_bolt_slot_with_energy(0, 0, 1))
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var plan: Dictionary = strategy.call("build_turn_plan", gs, 0, {})
	return run_checks([
		assert_eq(str(plan.get("intent", "")), "fuel_discard",
			"无LLM缓存时应fallback到规则版plan"),
	])


func test_raging_bolt_llm_returns_cached_plan_when_available() -> String:
	var script := _load_script(RAGING_BOLT_LLM_SCRIPT_PATH)
	if script == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var strategy: RefCounted = script.new()
	# 手动注入缓存
	var fake_plan := {
		"intent": "charge_bolt",
		"phase": "",
		"flags": {"llm_driven": true, "hand_has_sada": false, "hand_has_earthen_vessel": false,
			"hand_has_energy_retrieval": false, "discard_has_fuel": false, "active_is_stuck": false},
		"targets": {"primary_attacker_name": "Raging Bolt ex", "bridge_target_name": "Raging Bolt ex", "pivot_target_name": ""},
		"constraints": {"forbid_draw_supporter_waste": true},
		"context": {"source": "llm"},
	}
	strategy.set("_cached_llm_plan", fake_plan)
	strategy.set("_cached_turn_number", 3)
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_ogerpon_cd(), 0)
	player.bench.append(_make_bolt_slot_with_energy(0, 0, 1))
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var plan: Dictionary = strategy.call("build_turn_plan", gs, 0, {})
	return run_checks([
		assert_eq(str(plan.get("intent", "")), "charge_bolt",
			"有LLM缓存时应返回LLM plan"),
		assert_true(bool(plan.get("flags", {}).get("llm_driven", false)),
			"plan应标记为llm_driven"),
	])


func test_raging_bolt_llm_invalidates_cache_on_new_turn() -> String:
	var script := _load_script(RAGING_BOLT_LLM_SCRIPT_PATH)
	if script == null:
		return "DeckStrategyRagingBoltLLM.gd should exist"
	var strategy: RefCounted = script.new()
	var fake_plan := {
		"intent": "charge_bolt",
		"phase": "",
		"flags": {"llm_driven": true, "hand_has_sada": false, "hand_has_earthen_vessel": false,
			"hand_has_energy_retrieval": false, "discard_has_fuel": false, "active_is_stuck": false},
		"targets": {"primary_attacker_name": "Raging Bolt ex", "bridge_target_name": "Raging Bolt ex", "pivot_target_name": ""},
		"constraints": {},
		"context": {"source": "llm"},
	}
	strategy.set("_cached_llm_plan", fake_plan)
	strategy.set("_cached_turn_number", 2)  # 缓存的是回合2
	var gs := _make_game_state(3)  # 当前回合3
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_ogerpon_cd(), 0)
	player.bench.append(_make_bolt_slot_with_energy(0, 0, 1))
	for _i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0))
	var plan: Dictionary = strategy.call("build_turn_plan", gs, 0, {})
	return run_checks([
		assert_eq(str(plan.get("intent", "")), "fuel_discard",
			"回合号变化时应fallback到规则版（旧缓存失效）"),
	])
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/FunctionalTestRunner.gd -- --suite=FutureAncientStrategies --filter=raging_bolt_llm`
Expected: FAIL

- [ ] **Step 3: Implement DeckStrategyRagingBoltLLM**

Create `scripts/ai/DeckStrategyRagingBoltLLM.gd`:

```gdscript
extends "res://scripts/ai/DeckStrategyRagingBoltOgerpon.gd"

const ZenMuxClientScript = preload("res://scripts/network/ZenMuxClient.gd")
const LLMTurnPlanPromptBuilderScript = preload("res://scripts/ai/LLMTurnPlanPromptBuilder.gd")
const AutoloadResolverScript = preload("res://scripts/engine/AutoloadResolver.gd")

var _llm_host_node: Node = null
var _cached_llm_plan: Dictionary = {}
var _cached_turn_number: int = -1
var _llm_pending: bool = false
var _client: RefCounted = ZenMuxClientScript.new()
var _prompt_builder: RefCounted = LLMTurnPlanPromptBuilderScript.new()
var _llm_request_count: int = 0
var _llm_success_count: int = 0
var _llm_fail_count: int = 0


func get_strategy_id() -> String:
	return "raging_bolt_ogerpon_llm"


func set_llm_host_node(node: Node) -> void:
	_llm_host_node = node


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var turn: int = int(game_state.turn_number)
	if _cached_turn_number == turn and not _cached_llm_plan.is_empty():
		return _cached_llm_plan
	if turn != _cached_turn_number:
		_cached_llm_plan.clear()
		_cached_turn_number = turn
		if not _llm_pending:
			_fire_llm_request(game_state, player_index)
	return super.build_turn_plan(game_state, player_index, context)


func _fire_llm_request(game_state: GameState, player_index: int) -> void:
	if _llm_host_node == null or not is_instance_valid(_llm_host_node):
		return
	var game_manager: Variant = AutoloadResolverScript.resolve("GameManager")
	if game_manager == null:
		return
	var api_config: Dictionary = game_manager.call("get_battle_review_api_config")
	var endpoint: String = str(api_config.get("endpoint", ""))
	var api_key: String = str(api_config.get("api_key", ""))
	if endpoint == "" or api_key == "":
		return
	_llm_pending = true
	_llm_request_count += 1
	var payload: Dictionary = _prompt_builder.build_request_payload(game_state, player_index)
	payload["model"] = str(api_config.get("model", ""))
	_client.set_timeout_seconds(float(api_config.get("timeout_seconds", 15.0)))
	var turn_at_request: int = int(game_state.turn_number)
	var err: int = _client.request_json(
		_llm_host_node,
		endpoint,
		api_key,
		payload,
		_on_llm_response.bind(turn_at_request)
	)
	if err != OK:
		_llm_pending = false
		_llm_fail_count += 1
		print("[LLM策略] 请求发送失败: error=%d" % err)


func _on_llm_response(response: Dictionary, turn_at_request: int) -> void:
	_llm_pending = false
	if String(response.get("status", "")) == "error":
		_llm_fail_count += 1
		print("[LLM策略] 请求失败: %s" % str(response.get("message", "unknown")))
		return
	var plan: Dictionary = _prompt_builder.parse_llm_response_to_turn_plan(response)
	if plan.is_empty():
		_llm_fail_count += 1
		print("[LLM策略] LLM返回了无效intent: %s" % str(response.get("intent", "")))
		return
	_llm_success_count += 1
	if turn_at_request == _cached_turn_number:
		_cached_llm_plan = plan
		print("[LLM策略] 回合%d: intent=%s target=%s" % [
			turn_at_request,
			str(plan.get("intent", "")),
			str(plan.get("targets", {}).get("primary_attacker_name", "")),
		])
	else:
		print("[LLM策略] 回合%d的响应已过期（当前回合%d）" % [turn_at_request, _cached_turn_number])


func get_llm_stats() -> Dictionary:
	return {
		"requests": _llm_request_count,
		"successes": _llm_success_count,
		"failures": _llm_fail_count,
	}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/FunctionalTestRunner.gd -- --suite=FutureAncientStrategies --filter=raging_bolt_llm`
Expected: 4 PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/ai/DeckStrategyRagingBoltLLM.gd tests/test_future_ancient_strategies.gd
git commit -m "feat: add DeckStrategyRagingBoltLLM with LLM turn planner + rule fallback"
```

---

### Task 3: Register LLM strategy in DeckStrategyRegistry

**Files:**
- Modify: `scripts/ai/DeckStrategyRegistry.gd:1-67`

- [ ] **Step 1: Write failing test**

Append to `tests/test_future_ancient_strategies.gd`:

```gdscript
func test_registry_creates_raging_bolt_llm_strategy() -> String:
	var registry_script := load("res://scripts/ai/DeckStrategyRegistry.gd")
	if registry_script == null:
		return "DeckStrategyRegistry.gd should exist"
	var registry: RefCounted = registry_script.new()
	var strategy: RefCounted = registry.call("create_strategy_by_id", "raging_bolt_ogerpon_llm")
	return run_checks([
		assert_true(strategy != null, "registry应能创建raging_bolt_ogerpon_llm策略"),
		assert_eq(str(strategy.call("get_strategy_id")), "raging_bolt_ogerpon_llm",
			"创建的策略id应正确") if strategy != null else "",
	])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/FunctionalTestRunner.gd -- --suite=FutureAncientStrategies --filter=registry_creates_raging_bolt_llm`
Expected: FAIL

- [ ] **Step 3: Register the LLM strategy in DeckStrategyRegistry.gd**

Add the preload after line 20 (the RagingBoltOgerpon preload):

```gdscript
const DeckStrategyRagingBoltLLMScript = preload("res://scripts/ai/DeckStrategyRagingBoltLLM.gd")
```

Add to `_STRATEGY_SCRIPTS` dict after the `raging_bolt_ogerpon` entry:

```gdscript
"raging_bolt_ogerpon_llm": DeckStrategyRagingBoltLLMScript,
```

**Do NOT add to `_STRATEGY_ORDER`.** The LLM version shares the same signature names as the rule version. Since `_best_strategy_id_for_visible_names` uses strict `>` for tie-breaking, two strategies with equal match counts would always pick the first one. The LLM version should only be selected explicitly via `create_strategy_by_id("raging_bolt_ogerpon_llm")`, not by auto-detection.

- [ ] **Step 4: Run test to verify it passes**

Run: `"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/FunctionalTestRunner.gd -- --suite=FutureAncientStrategies --filter=registry_creates_raging_bolt_llm`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/ai/DeckStrategyRegistry.gd tests/test_future_ancient_strategies.gd
git commit -m "feat: register raging_bolt_ogerpon_llm in DeckStrategyRegistry"
```

---

### Task 4: Wire LLM strategy into BattleScene — auto-upgrade when API is configured

**Files:**
- Modify: `scenes/battle/BattleScene.gd:3165-3280`

The selection logic: when the registry auto-detects `raging_bolt_ogerpon` and the user has a valid ZenMux API config (endpoint + api_key both non-empty), automatically upgrade to the LLM version. This is opt-in by API configuration — no UI toggle needed for v1.

- [ ] **Step 1: Add LLM upgrade logic in `_build_default_ai_opponent()`**

After the line `ai.set_deck_strategy(deck_strategy)` at approximately line 3179, add:

```gdscript
		deck_strategy = _maybe_upgrade_to_llm_strategy(deck_strategy)
		if deck_strategy != ai._deck_strategy:
			ai.set_deck_strategy(deck_strategy)
```

Then add a new helper method in BattleScene:

```gdscript
func _maybe_upgrade_to_llm_strategy(strategy: RefCounted) -> RefCounted:
	if strategy == null or not strategy.has_method("get_strategy_id"):
		return strategy
	var strategy_id: String = str(strategy.call("get_strategy_id"))
	if strategy_id != "raging_bolt_ogerpon":
		return strategy
	var api_config: Dictionary = GameManager.get_battle_review_api_config()
	if str(api_config.get("endpoint", "")).strip_edges() == "":
		return strategy
	if str(api_config.get("api_key", "")).strip_edges() == "":
		return strategy
	var llm_strategy: RefCounted = _deck_strategy_registry.call("create_strategy_by_id", "raging_bolt_ogerpon_llm") if _deck_strategy_registry != null else null
	if llm_strategy == null:
		return strategy
	if llm_strategy.has_method("set_llm_host_node"):
		llm_strategy.call("set_llm_host_node", self)
	return llm_strategy
```

Also apply the same `_maybe_upgrade_to_llm_strategy` call in `_build_selected_ai_opponent()` after any strategy is set.

The upgrade is transparent: if API isn't configured → rule-based version is used unchanged. If API is configured → LLM version is used, with rule-based fallback for every turn where the LLM response hasn't arrived yet.

- [ ] **Step 2: Verify existing AI still works**

Run: `"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/FunctionalTestRunner.gd -- --suite=FutureAncientStrategies`
Expected: All existing tests still PASS (upgrade only fires when API is configured)

- [ ] **Step 3: Commit**

```bash
git add scenes/battle/BattleScene.gd
git commit -m "feat: auto-upgrade Raging Bolt to LLM strategy when API is configured"
```

---

### Task 5: Integration verification — run full test suite and manual smoke test

- [ ] **Step 1: Run the full FutureAncientStrategies test suite**

Run: `"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/FunctionalTestRunner.gd -- --suite=FutureAncientStrategies`
Expected: All tests PASS (existing + new LLM tests)

- [ ] **Step 2: Run broader functional tests to check for regressions**

Run: `"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/FunctionalTestRunner.gd`
Expected: No new failures

- [ ] **Step 3: Manual smoke test in the game (if API is configured)**

1. Launch the game
2. Go to 设置 (Settings), verify endpoint/api_key/model are configured
3. Go to 对战设置 (BattleSetup), select 猛雷鼓 deck for AI opponent
4. Start a battle, observe console output for `[LLM策略]` log lines
5. Verify the AI plays normally (rule-based fallback) even if the LLM call fails or is slow
6. If the LLM call succeeds, you should see `[LLM策略] 回合N: intent=... target=...`
7. The first action each turn may use the rule-based plan (LLM still in flight), subsequent actions use the LLM plan

- [ ] **Step 4: Final commit with any smoke-test fixes**

```bash
git add -A
git commit -m "feat: raging bolt LLM turn planner — integration complete"
```
