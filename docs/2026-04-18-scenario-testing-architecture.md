# PTCG Train 场景驱动测试框架设计与实施文档

版本：v1.1
日期：2026-04-18
状态：已锁定边界，待实现
负责人：Master Agent

---

## 0. 文档目的

本文档定义一套新的 AI 能力升级基础设施：

1. 从双人对战的真实录像中抽取高价值回合。
2. 把这些回合固化为可重复执行的 `scenario`。
3. 让 AI 在同一起点状态下重打该回合。
4. 对比 AI 回合末态与人类回合末态。
5. 把通过、分歧、失败沉淀为可持续扩展的训练与验证资产。

这不是 benchmark 的替代品，而是 benchmark 之前的高信噪比中间层。

---

## 1. 本次锁定的产品边界

以下边界已经由产品方确认，后续实现必须以此为准，不再沿用旧草案中的默认值。

### 1.1 对局来源

- 只使用双人对战产生的 `match_records` 数据。
- 一场对局同时抽取双方回合。
- 不区分胜负，双方回合都有学习价值。

### 1.2 学习入口

- 在对战结束界面新增 `让AI学习` 按钮。
- 该按钮只做整场 `match` 级标记，不做即时 case 提取。
- 被标记的对局进入“学习池”。
- 后续由“统一大学习”脚本批量扫描学习池并提取 case。

### 1.3 回合筛选

- 具体哪些回合值得学，由 LLM 在已标记的 match 内分析判定。
- 不因为输赢过滤回合。
- 不预先过滤“合法动作很多的大回合”，先保留并打 tag。
- setup、纯 forced、纯 end_turn 之类的低价值回合，允许在提取阶段过滤。

### 1.4 比对原则

- 过程宽松：不要求 AI 与人类走同一动作顺序。
- 末态严格：回合结束后的结果必须按契约比较。
- 回合截点：tracked player 本回合所有强制结算完成，但尚未进入对手下一回合。

### 1.5 运行模式

- 第一版 scenario runner 固定使用 `rules_only`。
- 不允许默认混入 learned overlay。
- 后续如果要支持其他 mode，必须作为显式可选参数，不得影响第一版基线。

### 1.6 结果判定

- `bench` 采用无序比较。
- 能量采用“数量 + 类型”严格比较。
- 伤害采用精确比较，不做 bucket。
- `tool` 只比较名称，不比较实例 id。
- `hand` 严格纳入结果比较。
- 允许 `PASS(dominant)`，但只在机械规则能明确证明 AI 更优时触发。
- `approved_divergent_end_states` 由 LLM 提建议，人工确认后写回。

### 1.7 统一大学习入口

- 第一版只提供脚本入口。
- 不要求第一版先做菜单按钮或 BattleSetup 入口。

---

## 2. 为什么需要这套框架

现有能力升级主要依赖两类信号：

1. 局部规则测试
2. 100 局 benchmark

这两类信号都不够：

- 规则测试只能证明“不再犯已知错误”，不能证明整回合更强。
- benchmark 噪声较大，而且失败定位太慢。

场景驱动测试要补的是中间层：

- 比 benchmark 更可解释
- 比单步 score 测试更接近真实决策
- 比人工看 replay 更可重复

这套框架的目标不是“模仿动作顺序”，而是“约束回合结果质量”。

---

## 3. 核心设计原则

### 3.1 整回合末态比对

同一回合起点 `S0`：

- 人类打完得到 `HumanEnd`
- AI 打完得到 `AIEnd`

系统只比较 `HumanEnd` 和 `AIEnd`。

如下两类情况都应允许通过：

- 人类：`Poffin -> 贴能 -> TM -> 攻击`
- AI：`贴能 -> Poffin -> TM -> 攻击`

只要最终手牌、场面、能量、伤害、奖赏等契约一致，即视为通过。

### 3.2 手牌必须严格纳入

这是与旧草案最大的差异之一。

本项目里很多 AI 不是“场面差”，而是：

- 为了当回合场面最优，把后续轮次资源打空
- 当回合看着成立，下一轮直接断线

因此第一版必须把 `hand` 纳入严格比较，否则会放过大量真实策略问题。

### 3.3 学习池与批量提取解耦

不要在每场对局结束后立刻抽 case。

正确流程是：

1. 人工判断这场值得学
2. 点击 `让AI学习`
3. 累积若干场后统一提取

这样能避免：

- 学习池被噪声对局污染
- 一边打牌一边触发重型处理
- 过早把不想保留的对局写成长期资产

### 3.4 双边都学

同一场双人对战不是“一个人类老师，一个对手背景板”。

双方每个高价值回合都可能包含：

- 优秀的 shell 构建
- 优秀的 handoff
- 错误的资源消耗
- 可迁移的 closeout

因此 scenario 提取默认对双方都开放。

---

## 4. 总体流程

### 4.1 录制阶段

玩家进行双人对战，系统已生成：

- `match.json`
- `turns.json`
- `detail.jsonl`

### 4.2 标记阶段

对战结束界面：

- `AI复盘`
- `让AI学习`

点击 `让AI学习` 后：

- 不做提取
- 只记录该 `match_id` 进入学习池

### 4.3 批量提取阶段

运行脚本：

- 扫描学习池中的 match
- 读取 `detail.jsonl`
- 用 LLM 识别双方的高价值回合
- 生成 `scenario`

### 4.4 回放验证阶段

scenario runner：

1. 恢复回合起点状态
2. 用 `rules_only` 让 AI 打完整个回合
3. 捕获 AI 末态
4. 与 `expected_end_state` 比对
5. 输出 `PASS / DIVERGE / FAIL`

### 4.5 审查沉淀阶段

若 `DIVERGE`：

1. 进入 review queue
2. LLM 给出“等价 / 更优 / 更差”的建议
3. 人工确认
4. 若等价或更优，则写回 `approved_divergent_end_states`

---

## 5. 结果判定模型

### 5.1 三态定义

- `PASS`
  - 严格维度全部匹配
  - 或命中已批准的替代末态
  - 或满足非常严格的 `dominant` 规则

- `DIVERGE`
  - 与人类末态不一致
  - 但不属于“显著更差到可直接失败”
  - 进入 review queue

- `FAIL`
  - 严重缺失关键战略结果
  - 例如少一个关键进化、少一个关键攻击手、关键奖赏线断裂

### 5.2 primary 维度

以下维度第一版全部严格比较：

- 我方 active 宝可梦名称与进化栈
- 我方 bench 宝可梦集合与进化栈
- 对手 active 宝可梦名称与进化栈
- 对手 bench 宝可梦集合与进化栈
- 双方每个场上宝可梦的：
  - 能量总数
  - 能量类型分布
  - tool 名称
  - damage counters 精确值
- 我方手牌完整内容
- 对手手牌完整内容
- 双方 prize 数量

说明：

- `bench` 为无序比较
- `tool` 只比较名称
- `hand` 比较完整卡名多重集，不比较实例 id

### 5.3 secondary 维度

以下维度用于 `dominant` 或 review 辅助解释：

- 我方剩余总 HP
- 对手剩余总 HP
- 我方弃牌堆资源质量
- 对手弃牌堆资源质量
- 我方场上总能量
- 对手场上总能量

说明：

- secondary 不是第一版的主要 pass 条件
- 主要用于判定“AI 明显更优时是否允许机械 PASS(dominant)”

### 5.4 忽略维度

第一版明确忽略：

- 牌库顺序
- stadium
- 任何中间动作顺序
- 中间 prompt 的选项路径

---

## 6. 数据模型与契约

本节是 4-agent 并发开发的硬契约。

### 6.1 学习池记录

新文件建议：

- `user://learning_pool/learning_matches.json`

结构建议：

```json
{
  "schema_version": 1,
  "matches": [
    {
      "match_id": "match_20260418_abcdef",
      "marked_at": "2026-04-18T21:35:10+08:00",
      "source_dir": "user://match_records/match_20260418_abcdef",
      "status": "pending_extraction"
    }
  ]
}
```

说明：

- 第一版整场标记
- 默认双方都学，不需要额外 side 字段

### 6.2 state_snapshot schema

状态快照必须能无损支撑：

- 回合中间恢复
- 双方手牌严格比较
- 能量和 tool 精确恢复

最低要求：

```jsonc
{
  "turn_number": 3,
  "current_player_index": 0,
  "first_player_index": 0,
  "phase": "main",
  "winner_index": -1,
  "win_reason": "",
  "energy_attached_this_turn": false,
  "supporter_used_this_turn": false,
  "stadium_played_this_turn": false,
  "retreat_used_this_turn": false,
  "vstar_power_used": [false, false],
  "players": [
    {
      "player_index": 0,
      "active": {},
      "bench": [],
      "hand": [],
      "deck": [],
      "discard": [],
      "prizes": [],
      "lost_zone": []
    }
  ]
}
```

必须满足：

1. 所有 `CardInstance` 保留 `instance_id`
2. `deck` 保留顺序
3. `hand` 保留完整内容
4. `attached_energy` / `attached_tool` 可无歧义恢复

### 6.3 scenario schema

建议路径：

- `tests/scenarios/<deck_id>/match_<match_id>_turn<N>_p<player_index>.json`

建议结构：

```jsonc
{
  "scenario_id": "match_20260418_abcdef_turn3_p0",
  "schema_version": 1,
  "deck_id": 578647,
  "tracked_player_index": 0,
  "source_match_id": "match_20260418_abcdef",
  "source_turn_number": 3,
  "tags": ["opening", "bridge", "search_attach"],
  "notes": "LLM 识别为高价值回合",
  "state_at_turn_start": {},
  "expected_end_state": {
    "primary": {},
    "secondary": {}
  },
  "approved_divergent_end_states": []
}
```

### 6.4 verdict schema

```jsonc
{
  "scenario_id": "...",
  "status": "PASS",
  "reason": "",
  "matched_alternative_id": "",
  "dominant": false,
  "diff": [],
  "ai_end_state": {}
}
```

### 6.5 review queue schema

```jsonc
{
  "scenario_id": "...",
  "status": "pending_review",
  "expected_end_state": {},
  "ai_end_state": {},
  "diff": [],
  "llm_suggestion": {
    "resolution": "equivalent",
    "confidence": 0.89,
    "reason": ""
  },
  "human_resolution": ""
}
```

---

## 7. 核心接口

以下接口是跨 agent 协作的稳定边界。

### 7.1 W1 提供

文件：

- `scripts/engine/scenario/ScenarioStateSnapshot.gd`
- `scripts/engine/scenario/ScenarioStateRestorer.gd`

接口：

```gdscript
class_name ScenarioStateSnapshot
extends RefCounted

static func capture(game_state: GameState) -> Dictionary
static func validate(snapshot: Dictionary) -> Array[String]
```

```gdscript
class_name ScenarioStateRestorer
extends RefCounted

static func restore(snapshot: Dictionary) -> Dictionary
# {"gsm": GameStateMachine, "errors": Array[String]}
```

### 7.2 W3 提供

文件：

- `scripts/ai/scenario_comparator/ScenarioEquivalenceRegistry.gd`
- `scripts/ai/scenario_comparator/ScenarioEndStateComparator.gd`

接口：

```gdscript
class_name ScenarioEquivalenceRegistry
extends RefCounted

static func extract_primary(game_state: GameState, player_index: int) -> Dictionary
static func extract_secondary(game_state: GameState, player_index: int) -> Dictionary
```

```gdscript
class_name ScenarioEndStateComparator
extends RefCounted

static func compare(
    ai_end_state: Dictionary,
    expected_end_state: Dictionary,
    approved_alternatives: Array
) -> Dictionary
```

### 7.3 Master 提供

文件：

- `tests/scenarios/ScenarioRunner.gd`

接口：

```gdscript
class_name ScenarioRunner
extends RefCounted

func run_scenario(scenario_path: String, runtime_mode: String = "rules_only") -> Dictionary
func run_all(scenarios_dir: String, runtime_mode: String = "rules_only") -> Dictionary
```

### 7.4 W2 提供

脚本：

- `scripts/tools/extract_learning_pool_scenarios.py`

入口：

```bash
python scripts/tools/extract_learning_pool_scenarios.py \
  --match-records-root user://match_records \
  --learning-pool <optional-manifest.json> \
  --output-dir tests/scenarios/
```

---

## 8. 4-Agent 分工

### 8.1 Master Agent

职责：

- 更新和维护总设计文档
- 冻结契约
- 推进整体里程碑
- 编写 `ScenarioRunner`
- 做端到端集成、回归、仲裁
- review 三个 worker 的输出是否符合契约

可修改文件：

- `docs/2026-04-18-scenario-testing-architecture.md`
- `tests/scenarios/ScenarioRunner.gd`
- `tests/scenarios/ScenarioCatalog.gd`
- `tests/scenarios/test_scenario_runner_smoke.gd`
- `tests/scenarios/test_scenario_runner_e2e.gd`
- `tests/scenarios/fixtures/`
- `tests/scenarios/schemas/README.md`
- `tests/TestSuiteCatalog.gd`

不可修改：

- W1 own
- W2 own
- W3 own

### 8.2 Worker 1：快照基建

职责：

- 审计现有 recorder / replay snapshot 完整性
- 实现完整 capture
- 实现可靠 restore
- 保证手牌、能量、tool、实例 id 全量恢复

可修改文件：

- `scripts/engine/scenario/ScenarioStateSnapshot.gd`
- `scripts/engine/scenario/ScenarioStateRestorer.gd`
- 必要时少量补 `BattleRecorder` / `BattleReplayStateRestorer`
- `tests/scenarios/schemas/state_snapshot.md`
- `tests/test_scenario_state_roundtrip.gd`
- `tests/test_scenario_recorder_completeness.gd`

### 8.3 Worker 2：场景提取器

职责：

- 从学习池扫描 match
- 读取 `detail.jsonl`
- 对双方回合做 LLM 价值筛选
- 生成 scenario 文件
- 生成 `expected_end_state`

可修改文件：

- `scripts/tools/scenario_extractor/extract_scenarios.py`
- `scripts/tools/scenario_extractor/scenario_extractor_lib.py`
- `scripts/tools/scenario_extractor/turn_filters.py`
- `scripts/tools/scenario_extractor/README.md`
- `scripts/tools/scenario_extractor/tests/`
- `tests/scenarios/schemas/scenario.md`

约束：

- W2 生成的 `expected_end_state` schema 必须和 W3 输出对齐
- 如有歧义，以 W3 的抽取结构为事实标准，由 master 仲裁

### 8.4 Worker 3：比对与审查

职责：

- 定义 primary/secondary 抽取逻辑
- 实现 comparator
- 实现 approved alternatives 命中逻辑
- 实现 review queue 生成
- 提供 LLM 审查建议与写回工具

可修改文件：

- `scripts/ai/scenario_comparator/ScenarioEndStateComparator.gd`
- `scripts/ai/scenario_comparator/ScenarioEquivalenceRegistry.gd`
- `scripts/tools/scenario_review/llm_judge.py`
- `scripts/tools/hydrate_scenario_review_queue.gd`
- `scripts/tools/scenario_review/ScenarioReviewQueueHydrator.gd`
- `scripts/tools/scenario_review/export_review_packets.py`
- `scripts/tools/scenario_review/import_review_judgments.py`
- `scripts/tools/scenario_review/apply_approvals.py`
- `scripts/tools/scenario_review/tests/`
- `tests/scenarios/schemas/verdict.md`
- `tests/scenarios/schemas/review_queue.md`
- `tests/test_scenario_comparator.gd`

---

## 9. 里程碑计划

### M1：文档与契约冻结

目标：

- 所有边界写入文档
- 4-agent own 文件锁定
- 核心接口冻结

完成标准：

- 本文档更新完毕
- 三个 worker 能只看本文档开工

### M2：快照与比对基建并行

W1：

- 完成 capture / restore / roundtrip

W3：

- 完成 primary/secondary 提取与 compare

Master：

- 用 mock 完成 ScenarioRunner 骨架

### M3：学习池与标记链路

目标：

- 新增 `让AI学习` 按钮
- 完成 match 级学习池打标

说明：

- 这一阶段不要求马上提取 scenario

### M4：提取器接入真实 match

目标：

- W2 能从学习池中的真实对局生成双方 scenario
- 至少跑通 1 场真实双人对局

### M5：首个端到端闭环

目标：

- 学习池中某场对局
- 提取 scenario
- runner 恢复并回放 AI
- comparator 出 verdict
- review queue 正常落盘

### M6：批量大学习脚本

目标：

- 脚本能一键处理学习池
- 输出 scenario 集合
- 输出 summary 报告

---

## 10. 研发规范与编码安全

本项目历史上发生过多次编码污染，本次文档和实现必须显式加载以下研发规范：

- `CLAUDE.md`
- `DEVELOPMENT_SPEC.md`
- `tests/test_source_encoding_audit.gd`

### 10.1 硬规则

- 所有文本文件必须是 UTF-8
- 不允许把终端乱码直接写回源码或文档
- 不允许在乱码文本上局部拼接修补
- 一旦发现疑似乱码，优先整段或整文件重写
- 脚本写盘必须显式使用 UTF-8

### 10.2 对本项目特别重要的执行规则

- 文档重写后必须重新读取抽查
- 涉及中文 UI 文本新增时必须抽查 Godot 实际显示
- schema 文档、脚本 README、计划文档都属于编码高风险文件
- 任何大块文本改动后，必须跑 `SourceEncodingAudit`

### 10.3 本文档写作规范

- 使用简体中文
- 使用英文标识符
- 避免从终端复制乱码日志进入文档
- 不使用 box drawing、圈号等高风险字符

---

## 11. 验收标准

### 11.1 功能验收

- 可以从双人对战中标记“让AI学习”
- 学习池脚本能扫描已标记 match
- 可从一场 match 中抽取双方 scenario
- runner 能在 `rules_only` 下重打单回合
- comparator 能输出 `PASS / DIVERGE / FAIL`
- review queue 与 approved alternative 可闭环

### 11.2 工程验收

- 4-agent own 文件边界无冲突
- 所有新增文本文件为 UTF-8
- `SourceEncodingAudit` 通过
- 相关功能测试通过

### 11.3 文档验收

- 本文档与实现一致
- 每个 schema 文档独立存在且被 review
- 契约变更必须先更新本文档再改实现

---

## 12. 本版本相对旧草案的关键修正

以下是 v1.1 相对旧草案的关键修正，后续不得回退为旧口径：

1. `hand` 不再忽略，改为严格比较。
2. 比较来源不再是“单边人类教学”，而是双人对战双方都抽取。
3. 新增“学习池”概念，先标整场，再批量提取。
4. 第一版 runner 固定 `rules_only`。
5. `bench` 改为无序比较。
6. 能量比较从“数量优先”改为“数量 + 类型”都严格。
7. `tool` 只比名称，不比实例。
8. LLM 不直接写回批准结果，必须人工确认。

---

## 13. 开工前 Checklist

Master 发起并行开发前，每个 agent 必须确认：

- 已读本文档全文
- 已读自己的职责章节
- 已理解 own 文件边界
- 已理解 UTF-8 / SourceEncodingAudit 约束
- 遇到契约歧义时先停下，由 master 仲裁

建议 ack 模板：

```text
[W1/W2/W3] 已阅读 v1.1 文档与数据契约。
[W1/W2/W3] 已确认 own 文件范围。
[W1/W2/W3] 已确认 UTF-8 与 SourceEncodingAudit 约束。
[W1/W2/W3] 无阻塞 / 有阻塞如下：...
```

### 13.1 Master Kickoff 模板

Master 启动并发开发时，建议直接发送如下文本：

```text
[Master] 场景驱动测试框架 v1.1 开工。

硬要求：
1. 先读 docs/2026-04-18-scenario-testing-architecture.md
2. 再读第4节数据契约和自己的第8.X节职责段
3. 只改 own 文件
4. 所有文本文件 UTF-8
5. 遇到契约歧义先停下，由 Master 仲裁

本轮目标：
- W1：交付 snapshot capture / restore / roundtrip
- W2：交付 learning pool -> scenario extractor CLI
- W3：交付 end-state comparator / review queue / approval writeback

提交要求：
- 每完成一个小里程碑立即提交，不攒批
- 提交时附：改了什么、验证了什么、还有什么阻塞
```

### 13.2 Worker 回复模板

```text
[W1/W2/W3] 已阅 v1.1 文档、第4节契约、本人职责章节。
[W1/W2/W3] 已确认 own 文件范围，不会跨界修改。
[W1/W2/W3] 已确认 UTF-8 与 SourceEncodingAudit 约束。
[W1/W2/W3] 当前阻塞：无 / 如下...
[W1/W2/W3] 本轮先做：...
```

---

文档结束。
---

## 14. 2026-04-18 Clarification: Developer-Side LLM Review

- `让AI学习` only marks a match into the learning pool.
- Unified learning must not require player-side API setup.
- The required repository outputs are:
- extracted scenarios
- expected end states
- review packets
- LLM review is a developer-side assistive step.
- `scripts/tools/scenario_review/llm_judge.py` should read explicit CLI args, developer config, or developer env vars.
- Do not depend on `user://battle_review_api.json` for the scenario-learning pipeline.
- The pipeline must remain valid when it stops after packet export and a developer reviews packets manually or with Codex sub-agents.
