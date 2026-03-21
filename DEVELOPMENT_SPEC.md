# PTCG Train 研发规范

本规范是本项目的强制开发约束。所有功能开发、重构、修复都必须遵守。

## 1. 开发流程

统一流程：

```text
理解现状 -> 明确改动范围 -> 补测试/补设计 -> 实现 -> 运行验证 -> 手动回归
```

禁止直接跳到 UI 层硬改而不核对规则、数据流和状态流。

## 2. 编码与乱码治理规范

这是最高优先级规则。

### 2.1 统一编码

- 所有文本文件统一使用 UTF-8
- 包括但不限于：`.gd`、`.tscn`、`.md`、`.json`、`.txt`
- 不允许混用 ANSI、GBK、UTF-8 with BOM 等不受控编码

### 2.2 禁止引入乱码

- 不允许把终端乱码、日志乱码、错误解码后的文本直接写回源码
- 不允许在已有乱码文本上做局部拼接修补
- 一旦发现文件已有乱码，应优先整段或整文件重写为干净文本
- 批量替换前必须先抽查原文件内容与编码状态

### 2.3 写盘与脚本修改规则

- 使用脚本批量修改文件时，必须显式指定输出编码为 UTF-8
- 写回后必须重新读取文件抽查，确认中文、引号、格式化字符串、注释均正常
- 对 Godot 脚本的自动改写后，必须至少再做一次语法或测试验证

### 2.4 编码问题回归检查

提交前至少确认：
- 中文标题、注释、日志文本可正常显示
- 没有私有区字符、替代字符、问号占位符
- 没有因为编码损坏导致的引号缺失、缩进错乱、注释吞代码

## 3. GDScript 规范

### 3.1 类型安全

- `Dictionary.get()` 取得的数组先接成普通 `Array`，再显式过滤写入 `Array[T]`
- 不要把无类型数组直接赋值给强类型数组

示例：

```gdscript
var raw_items: Array = data.get("items", [])
var items: Array[CardInstance] = []
for item: Variant in raw_items:
	if item is CardInstance:
		items.append(item)
```

### 3.2 状态与交互

- 不要依赖隐式状态覆盖
- 对话框、选择步骤、特性交互统一通过显式参数和上下文传递
- 不要先写成员变量再调用一个会重置该成员变量的方法

### 3.3 信号与流程

- 避免同步信号嵌套驱动整条业务链
- 复杂流程优先由 UI 显式推进
- 若必须跨帧切换，使用清晰的状态变量或 `call_deferred`

## 4. UI 与场景规范

### 4.1 交互控件

- 纯展示子控件应设置为输入穿透
- 真正接收点击的节点必须唯一明确
- 不允许父节点和子节点同时拦截同一层交互而无明确意图

### 4.2 自适应布局

- 不允许把核心对战布局完全写死为固定像素
- 卡牌尺寸、弹窗尺寸、侧栏宽度应基于视口尺寸动态调整
- 新增 UI 元素时，优先验证 `1600x900` 与更小窗口下是否仍可操作

### 4.3 场景引用

- 所有通过 `%NodeName` 引用的节点必须启用 `unique_name_in_owner`
- 可点击容器内的纯展示文本控件必须开启输入穿透

## 5. 效果系统规范

- 优先复用现有 `BaseEffect` 交互框架
- 需要玩家选择目标、卡牌、弃牌、检索结果的效果，必须提供 `get_interaction_steps()`
- 不应把“应该由玩家选择”的效果静默自动执行
- 无交互效果至少要有明确成功或失败反馈

## 6. 测试规范

以下改动必须跑测试：
- 规则引擎
- 效果脚本
- 战斗主场景脚本
- 卡牌导入与本地缓存
- 任何批量改写后的核心文件
- 任何编码修复、文档重写、文本批量替换

最少要求：
- 正常路径
- 失败路径
- 边界条件

专项要求：
- 编码相关改动必须通过 `SourceEncodingAudit`

## 7. 提交前检查清单

- 没有乱码
- 没有解析错误
- 没有注释吞代码
- 没有坏掉的字符串格式化
- 相关测试通过
- 关键交互做过一次手动回归

## 8. 当前专项红线

由于本项目曾发生多次编码污染，以下文件后续修改时必须额外谨慎：
- `BattleScene.gd`
- `BattleCardView.gd`
- `EffectRegistry.gd`
- `CLAUDE.md`
- `DEVELOPMENT_SPEC.md`
- `scripts/effects/pokemon_effects/`
- `scripts/effects/trainer_effects/`

## 9. Card Validation Standard

- Bulk verification must run through `scripts/run_card_audit.ps1`.
- Check both generated reports:
  - `user://logs/card_audit_latest.txt`
  - `user://logs/card_status_matrix_latest.txt`
- New or changed card logic must add explicit semantic regression coverage, not only smoke coverage.
- Prefer reusable family tests in `tests/test_card_semantic_matrix.gd`.
- A cached scripted card is only considered done when:
  - `registry=ok`
  - `implementation=ok`
  - `interaction` is correct for the card's rules
  - `verification=covered`
