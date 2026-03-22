# PtcgDeckDojo

一个基于 Godot 4.6 与 GDScript 的 PTCG 本地练牌项目。

这个仓库的目标不是做官方替代品，也不是做商业化产品，而是尽可能把 PTCG 的练牌、规则验证、卡牌效果实现和测试流程做成一个可持续演进的开源项目。

<p align="center">
  <img src="assets/demo1.png" alt="PtcgDeckDojo battle demo 1" width="49%" />
  <img src="assets/demo3.png" alt="PtcgDeckDojo battle demo 2" width="49%" />
</p>

## 项目一句话

`PtcgDeckDojo` 是一个面向中文玩家的 PTCG 本地练牌与规则实验项目，支持导入卡组、本地缓存卡牌与卡图、进入战斗场景，并通过效果系统逐步补齐具体卡牌行为。

## 当前状态

这个项目已经能跑，也已经有比较完整的项目骨架，但它还远远不是“完成品”。

当前版本请务必按下面的预期理解：

- 已经有主菜单、卡组管理、对战设置、战斗主场景
- 已经有规则引擎、效果系统、批量审核和自动化测试
- 已经实现了很多卡牌脚本，但仍然有不少卡牌效果存在 bug、缺交互、边界条件不完整的问题
- 很多卡牌目前是“可以部分工作”，不是“完全符合正式对战细则”
- 这个仓库会继续以“发现问题 -> 补测试 -> 修效果 -> 再验证”的方式逐步修正

如果你是来找一个严肃可用的成品客户端，这个仓库现在并不适合。

如果你是来找一个可运行、可读、可继续补完的 PTCG 练牌代码库，那它是合适的。

## 项目特点

- 卡组导入：支持从 `tcg.mik.moe` 的卡组链接或 deck ID 导入
- 本地缓存：卡牌 JSON、卡图、卡组数据保存在 `user://`
- 战斗界面：已经具备完整主流程 UI
- 规则引擎：包含回合、伤害、状态、奖赏卡、撤退等核心流程
- 效果系统：通过 `effect_id` 将卡牌行为映射到可复用脚本
- 测试体系：包含语义回归、批量卡牌审核、编码审计、UI 回归等

## 项目结构

```text
assets/      UI 资源、图标、演示截图
docs/        设计文档、效果框架、开发说明、阶段记录
scenes/      Godot 场景与界面脚本
scripts/     数据模型、规则引擎、效果系统、网络和工具脚本
tests/       自动化测试、回归测试和批量审核入口
```

更细一点的逻辑分层大致是这样：

1. `scenes/` 负责界面和玩家交互。
2. `scripts/data/` 负责卡牌、卡组、玩家和槽位等数据模型。
3. `scripts/engine/` 负责规则校验、状态推进、伤害结算和效果调度。
4. `scripts/effects/` 负责把具体卡牌能力拆成可复用或专用脚本。
5. `scripts/network/` 负责卡组导入和卡图同步。
6. `tests/` 负责确保补卡和重构不会把已有行为搞坏。

## 当前开发逻辑

这个项目现在的主要开发循环不是“堆新功能”，而是下面这条线：

1. 先把游戏主流程和规则底座搭起来。
2. 用统一的效果框架承接越来越多的卡牌实现。
3. 用批量审核和语义回归测试找出缺卡、错卡和交互漏洞。
4. 逐张卡、逐类效果把 bug 修到可验证状态。

所以仓库里你会看到两类内容同时存在：

- 一类是已经比较稳定的底层结构和测试
- 一类是仍在逐步补完的具体卡牌实现

这不是矛盾，而是这个项目当前阶段的真实状态。

## 运行方式

### 环境要求

- Godot `4.6.x`
- Windows 环境已验证
- 首次导入卡组或同步卡图时需要能访问 `tcg.mik.moe`

### 本地运行

1. 用 Godot 打开仓库根目录中的 `project.godot`
2. 运行主场景 `res://scenes/main_menu/MainMenu.tscn`
3. 进入“卡组管理”导入卡组
4. 回到“开始对战”选择卡组并启动

### 运行测试

项目内置了 Godot 头less 测试入口：

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' 'res://tests/TestRunner.tscn'
```

如果你本机的 Godot 路径不同，只需要替换可执行文件路径。

## 文档入口

- [docs/README.md](docs/README.md)：文档导航
- [docs/development_setup.md](docs/development_setup.md)：开发环境、运行方式、测试入口
- [docs/project_status.md](docs/project_status.md)：当前能力边界、已知限制、协作建议
- [design_document.md](design_document.md)：整体设计文档
- [DEVELOPMENT_SPEC.md](DEVELOPMENT_SPEC.md)：研发规范与编码要求

## 关于实现质量

这个仓库会尽量严肃对待规则一致性、编码质量和测试覆盖，但请不要误解它的出身。

- 这是一个 `100% AI coding` 项目
- 作者本人主要是 PTCG 爱好者，最好成绩是城市赛冠军
- 作者并不是职业游戏程序员
- 所以这个项目更适合被看作“高投入的学习型和实验型练牌工程”，而不是传统商业团队产物

换句话说：

- 欢迎认真提 issue 和 PR
- 欢迎指出规则 bug、交互问题和架构问题
- 但也请不要拿商业游戏成品的标准去苛责这个项目的阶段性粗糙之处

## 版权与用途说明

这个项目涉及宝可梦卡牌相关名称、图像和规则表达，因此必须明确边界：

- 本仓库不附带用户本地缓存的卡牌数据与卡图
- 运行时使用的卡牌数据与卡图来源于 `tcg.mik.moe`
- Pokemon、PTCG 及相关卡牌内容的知识产权归各自权利人所有
- 本项目仅作为学习、研究与交流用途
- 不用于商业化
- 不提供任何官方授权背书

如果你 fork 本仓库或继续二次开发，也建议保留这条边界。

## 贡献

欢迎通过 Issue 和 Pull Request 参与。

提交前建议先阅读：

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [DEVELOPMENT_SPEC.md](DEVELOPMENT_SPEC.md)

这个仓库对 UTF-8 编码、中文文案、规则正确性和回归验证要求比较严格。

## 安全

安全问题请先看 [SECURITY.md](SECURITY.md)。

## 许可证

本项目采用 [Apache License 2.0](LICENSE)。
