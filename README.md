# PTCG Deck Agent

<p align="center">
  <a href="https://ptcg.skillserver.cn/">
    <img src="assets/ui/title.png" alt="PTCG Deck Agent - 宝可梦卡牌智能练牌器" width="100%" />
  </a>
</p>

<p align="center">
  <strong>宝可梦卡牌智能练牌器：把卡组编辑、规则对战、AI 策略分析、比赛练习和复盘迭代放到一个本地客户端里。</strong>
</p>

<p align="center">
  <a href="https://ptcg.skillserver.cn/">游戏官网</a>
  ·
  <a href="README_EN.md">English</a>
  ·
  <a href="docs/README.md">开发文档</a>
  ·
  <a href="CONTRIBUTING.md">参与贡献</a>
</p>

## 这是什么

`PTCG Deck Agent` 是一个基于 Godot 4.6 的 PTCG 本地练牌与 AI 策略实验项目。它不只是一个能打牌的模拟器，而是围绕“如何把一套卡组练强”设计的智能练牌工具：你可以导入卡组、和规则 AI 或 LLM AI 对战、在牌局中询问 AI 当前局面、复盘关键回合，并通过自动化测试持续修正规则和策略。

项目现在的重点已经从早期的“规则引擎验证”升级为“AI 辅助练牌产品”：让玩家更快理解卡组、找到错误决策、打出更稳定的展开路线。

## 核心亮点

- **AI 卡组教练**：在卡组编辑页直接和 AI 讨论当前卡组，询问起手稳定性、关键牌上手率、对局思路、换牌方向和具体单卡取舍。
- **牌局中实时建议**：对战过程中可以让 AI 基于当前可见场面给出下一步建议，包括是否进攻、撤退、贴能、找牌、拿奖路线和风险点。
- **公开信息边界**：对战建议默认只使用当前玩家视角能看到的信息，不把对手手牌、牌库顺序、奖赏卡内容直接泄露给 AI。
- **LLM 对手实验**：内置 LLM 版猛雷鼓等实验性对手，支持把大模型接入实际回合决策，而不是只做赛后聊天。
- **规则 AI 卡组**：内置多套独立 AI 卡组，覆盖密勒顿、喷火龙大比鸟、沙奈朵、阿尔宙斯骑拉帝纳、多龙等主流练习对象。
- **瑞士轮比赛模式**：支持 16 / 32 / 64 / 128 人比赛，自动生成选手、随机 AI 卡组、积分榜、配对和最终排名。
- **本地化资源打包**：卡组、卡牌数据、卡图、音乐、AI 卡组和配置文件支持随游戏内置，降低首次安装后的缺资源问题。
- **自动化规则验证**：大量卡牌效果、战斗流程、AI 策略和 UI 行为都有测试入口，适合持续补卡、修规则和做策略迭代。

## AI 能做什么

### 1. 卡组理解

打开一套牌后，AI 会拿到压缩后的完整卡表和关键卡牌文本，可以回答：

- 这套牌的核心赢法是什么？
- 起手应该优先找哪些基础宝可梦？
- 某张卡能不能换成另一张卡？
- 对密勒顿、沙奈朵、喷火龙这类卡组应该怎么打？
- 这套牌缺什么资源，哪些牌是冗余的？

### 2. 对战建议

在战斗中，AI 会结合当前回合、阶段、行动方、场上宝可梦、HP、能量、手牌、弃牌、奖赏卡剩余数量和双方卡组信息，给出更接近实战的建议。提示词中特别说明了 PTCG 的奖赏卡规则：奖赏卡是“剩余数量”，先拿完到 0 的玩家获胜。

### 3. 复盘与学习

项目保留了对局日志、决策 trace、场面快照和自动化 benchmark 的基础设施，可以把失败局拆开看，定位 AI 或规则模型在哪个细节上偏离了预期打法。

## 画面预览

<p align="center">
  <img src="assets/demo_menu.png" alt="Main menu" width="49%" />
  <img src="assets/demo_ai_card.png" alt="AI deck discussion" width="49%" />
</p>

<p align="center">
  <img src="assets/demo1.png" alt="Battle scene" width="49%" />
  <img src="assets/demo3.png" alt="Battle overview" width="49%" />
</p>

## 当前模式

- **开始对战**：选择玩家卡组和 AI 卡组，进行普通练习。
- **双人对战**：本地双人模式，用于人工验证规则和测试卡组展开。
- **卡组管理 / 卡组编辑**：导入、编辑、查看卡组，并与 AI 讨论构筑。
- **比赛模式**：瑞士轮赛事流程，自动配对、记录积分和展示最终排名。
- **AI 设置**：配置 ZenMux API、选择模型、测试连接，并设置 AI 性格风格。

## 技术结构

```text
assets/      UI 图片、背景、音效、演示截图
data/        内置卡组、卡牌、卡图、AI 固定起手与用户初始资源
docs/        架构文档、开发计划、策略迭代记录
scenes/      Godot 场景和界面脚本
scripts/     规则引擎、AI 策略、效果系统、网络请求、比赛系统
tests/       功能回归、卡牌效果、AI 策略和场景测试
```

核心实现分层：

1. `scripts/engine/` 负责规则推进、状态机、效果调度和场面快照。
2. `scripts/effects/` 负责具体卡牌、道具、支援者、竞技场和攻击效果。
3. `scripts/ai/` 负责规则 AI、卡组策略、LLM 决策桥接和策略 trace。
4. `scripts/network/` 负责 ZenMux / OpenAI 兼容接口调用。
5. `scripts/tournament/` 负责瑞士轮比赛组织。

## 本地运行

### 环境

- Godot `4.6.x`
- Windows 环境已重点验证
- macOS 打包正在逐步补齐兼容性
- 如需 AI 对话，需要可用的 ZenMux API Key

### 启动

1. 用 Godot 打开仓库根目录下的 `project.godot`
2. 运行主场景 `res://scenes/main_menu/MainMenu.tscn`
3. 在 `AI 设置` 中选择模型并测试连接
4. 进入卡组管理、普通对战或比赛模式开始练习

### 常用测试

```powershell
# 功能回归
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FunctionalTestRunner.gd'

# AI / 策略相关测试
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/AITrainingTestRunner.gd'
```

## 项目状态

这是一个高速迭代中的开源项目。当前已经可以进行卡组导入、编辑、对战、AI 对话、比赛模式和大量自动化测试，但仍不应该被理解为官方级完整裁判程序。

更准确的定位是：

- 对玩家：一个可以实际练牌、问 AI、复盘和试构筑的智能练习客户端。
- 对开发者：一个把 PTCG 规则、AI 策略、LLM 决策和自动化测试放在一起的实验平台。
- 对贡献者：一个可以通过补卡、修规则、加测试、优化 AI 策略持续变强的项目。

## 免责声明

本项目是非官方、非商业的学习与研究项目。Pokemon、宝可梦、PTCG 及相关卡牌名称、图片、规则文本和知识产权归各自权利人所有。本项目不提供任何官方授权背书，也不用于替代官方产品或商业化发行。

如果你 fork 或二次开发本项目，也建议保留这一边界。

## 贡献

欢迎提交 Issue 和 Pull Request，尤其欢迎：

- 规则 bug 和卡牌效果错误
- AI 对战中的明显错误决策
- 卡组策略和测试用例
- UI / 交互体验改进
- macOS / Windows 打包兼容性反馈

提交前建议阅读：

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [DEVELOPMENT_SPEC.md](DEVELOPMENT_SPEC.md)
- [docs/README.md](docs/README.md)

## License

[Apache License 2.0](LICENSE)
