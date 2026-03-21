# PtcgDeckDojo

一个基于 Godot 4.6 与 GDScript 的 PTCG 练牌项目，目标是提供可验证、可扩展、以中文玩家为中心的本地练牌体验。

当前仓库重点公开的是三部分能力：

- 本地卡组导入、卡牌缓存与卡图同步流程
- 以规则引擎和效果系统为核心的对战逻辑
- 持续演进中的自动化测试、批量卡牌审核与编码审计流程

## 项目定位

`PtcgDeckDojo` 不是线上对战平台，也不是官方客户端替代品。它更像一个面向开发与练牌的实验型桌面项目：

- 用 `tcg.mik.moe` 的卡组链接导入卡组
- 在本地缓存卡牌 JSON 与卡图资源
- 运行双人本地对战流程
- 通过效果脚本持续补齐具体卡牌行为
- 依赖测试与批量审核脚本控制回归风险

## 当前状态

项目目前仍处于活跃开发阶段，适合：

- 阅读代码和文档，理解 PTCG 规则引擎与效果建模方式
- 本地运行已有界面与对战流程
- 基于现有测试体系继续补卡、补交互、补规则

项目目前不应被表述为“完整成品”，主要原因包括：

- AI 对战模式在界面和全局状态中已有入口，但当前核心完成度仍以本地双人和规则/效果实现为主
- 部分卡牌效果仍保留 `TODO` 形式的交互占位，尚未完全迁移到统一交互框架
- 设置界面、发布打包、外部贡献流程仍在完善

## 功能概览

- 卡组管理：支持输入 `tcg.mik.moe` 卡组链接或 deck ID 导入
- 本地缓存：卡牌元数据、卡组 JSON、卡图都写入 `user://` 持久化目录
- 对战界面：主菜单、卡组管理、对战设置、战斗主场景已经打通
- 规则引擎：包含回合流程、伤害结算、状态、奖赏卡、撤退等基础机制
- 效果系统：按 `effect_id` 将卡牌行为映射到可复用脚本
- 回归验证：包含编码审计、效果注册、语义回归、界面回归等测试

按当前仓库内容统计：

- `pokemon_effects` 目录下已有 100+ 个宝可梦相关效果脚本
- `trainer_effects` 目录下已有 40+ 个训练家相关效果脚本
- `tests/` 下已有 30+ 个测试脚本

## 技术栈

- 引擎：Godot 4.6
- 语言：GDScript
- 数据格式：JSON
- 运行模式：本地桌面项目
- 外部数据源：`tcg.mik.moe`

## 仓库结构

```text
scenes/      Godot 场景与界面脚本
scripts/     数据模型、规则引擎、效果系统、网络与工具脚本
tests/       自动化测试与批量审核入口
docs/        架构、效果框架、UI 设计与开发说明
```

更详细的文档导航见 [docs/README.md](docs/README.md)。

## 快速开始

### 1. 环境要求

- Godot `4.6.x`
- 建议使用与当前项目一致的桌面版本运行
- 首次导入卡组或同步卡图时需要可访问 `tcg.mik.moe`

### 2. 本地运行

1. 用 Godot 打开仓库根目录中的 `project.godot`
2. 运行主场景 `res://scenes/main_menu/MainMenu.tscn`
3. 进入“卡组管理”导入卡组
4. 回到“开始对战”选择卡组并启动

### 3. 运行测试

项目内置了一个 Godot 测试入口场景：

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' 'res://tests/TestRunner.tscn'
```

如果你使用不同路径的 Godot，可替换为本机安装路径。更多开发与测试说明见 [docs/development_setup.md](docs/development_setup.md)。

## 文档索引

- [docs/README.md](docs/README.md)：文档导航
- [docs/development_setup.md](docs/development_setup.md)：开发环境、运行方式、测试入口
- [docs/project_status.md](docs/project_status.md)：当前能力边界、已知限制与协作建议
- [design_document.md](design_document.md)：整体设计文档
- [DEVELOPMENT_SPEC.md](DEVELOPMENT_SPEC.md)：研发规范与编码约束

## 贡献方式

欢迎通过 Issue 或 Pull Request 参与，但提交前请先阅读：

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [DEVELOPMENT_SPEC.md](DEVELOPMENT_SPEC.md)

这个仓库对 UTF-8 编码、中文文案质量、规则一致性和回归测试要求比较严格，提交前需要自查。

## 数据与版权说明

- 本仓库不附带官方卡图缓存与用户本地卡组缓存
- 运行时下载的卡牌数据与卡图来源于 `tcg.mik.moe`
- Pokemon、PTCG 及相关名称、图像与卡牌内容的知识产权归各自权利人所有
- 本项目是非官方、非商业的学习与开发用途项目

如果后续公开发布时需要更严格的素材边界，建议继续保持“代码开源、缓存资源不入库”的方式。

## 安全说明

如需反馈漏洞或潜在滥用问题，请先阅读 [SECURITY.md](SECURITY.md)。

## 许可证

本项目采用 [Apache License 2.0](LICENSE)。
