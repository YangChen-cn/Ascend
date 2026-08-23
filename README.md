<div align="center">

# 知境录 · Ascend

### 面向 macOS 的本地优先个人学习监控与境界成长系统

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2015.0+-black?style=for-the-badge&logo=apple&logoColor=white" alt="Platform" />
  <img src="https://img.shields.io/badge/Swift-6.0%20Strict%20Concurrency-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 6" />
  <img src="https://img.shields.io/badge/Architecture-Local--First%20%7C%20SwiftData-388E3C?style=for-the-badge" alt="Local-First" />
  <img src="https://img.shields.io/badge/Memory%20Model-FSRS%20v4-4A148C?style=for-the-badge" alt="FSRS" />
  <img src="https://img.shields.io/badge/AI-OpenAI%20Compatible-00838F?style=for-the-badge" alt="AI Compatible" />
</p>

*以真实实践为墨，以认知境界为卷。将碎片化的编码、阅读与笔记，淬炼为系统化的星宿知识图谱与修为进阶。*

---

</div>

## 🌌 什么是知境录？

**知境录（Ascend）** 是一款专为 macOS 设计的**本地优先（Local-First）**学习监控与认知成长系统。

传统的学习记录软件往往依赖繁琐的人工手动打卡，或仅给出单薄的打卡天数。知境录打破这一模式——它静默常驻于 macOS 菜单栏，自动捕捉你在本地 Markdown 笔记库中的思考沉淀与 Git 仓库中的真实代码实践；借助大语言模型（LLM）从活动增量中提炼核心认知，构建**五维掌握度模型**与**星宿知识图谱**，并依托现代 **FSRS（Free Spaced Repetition Scheduler）** 算法科学管理记忆衰退，驱动你从「初窥门径」逐步迈向「通达化境」。

```
  ┌────────────────────────────────────────────────────────────────────────┐
  │                           知 境 录 · 运 作 流                           │
  └────────────────────────────────────────────────────────────────────────┘
     [ 本地 Markdown ]       [ 本地/远端 Git ]          [ 快捷复习 / 手动 ]
      (FSEvents 监听)         (Commit 增量差分)          (FSRS 评分与挑战)
             │                       │                         │
             └───────────────┬───────┴─────────────────────────┘
                             ▼
                 [ Activity 资料流与去重 ]
                             │
                             ▼
                 [ AI 语义分析与证据提取 ]
                   (提取 Evidence & 关系)
                             │
                             ▼
        ┌────────────────────┴────────────────────┐
        ▼                                         ▼
   [ 五维评分引擎 ]                          [ FSRS 记忆调度 ]
  接触 / 理解 / 实践 / 自主                  记忆保持率 (Retrievability)
        │                                         │
        └────────────────────┬────────────────────┘
                             ▼
                 [ 知识图谱 · 领域境界 · 每日战报 ]
```

---

## ✨ 核心特性

### 1. ⚡️ 全自动常驻采集 · 零打扰沉浸
- **Markdown 实时感知**：通过 macOS `FSEvents` 监听本地知识库（如 Obsidian、Logseq、纯文本目录），智能防抖，文件变更无感采集。
- **Git 语义增量追踪**：自动拉取并差分本地与远端 Git 仓库的新提交，智能过滤低信息琐碎变更，识别实质性代码与架构演进。
- **严格规范化去重**：`eventFingerprint` 与 `contentChangeHash` 双重校验，重命名或多源合并绝不重复计分。

### 2. 🧠 真实证据驱动（Evidence-Based）认知模型
- **五维掌握度矩阵**：
  $$\text{综合掌握度} = 10\% \times \text{接触} + 25\% \times \text{理解} + 25\% \times \text{实践} + 20\% \times \text{记忆} + 20\% \times \text{自主}$$
- **六重修真境界**：
  $$\text{初窥} \longrightarrow \text{入门} \longrightarrow \text{通晓} \longrightarrow \text{融会} \longrightarrow \text{化用} \longrightarrow \text{通达}$$
- **坚守求真原则**：XP 仅来源于**真实已验证**的学习证据；遗忘只动态影响当前记忆可提取率（Retrievability），**绝不回退历史最高境界与既得 XP**。

### 3. 🌌 星宿天球知识图谱（Celestial Constellation）
- **典雅东方星宿美学**：在太虚玄渊与素绢温玉间流转，同心天球星轨环与发光灵脉连线生动映射知识点的前置与衍生关系。
- **力导向智能布局**：内置防重叠排斥算法与 `@MainActor` 布局记忆缓存，支持自由缩放、拖拽与高亮溯源，交互如丝般顺滑。

### 4. ⏳ 科学 FSRS 记忆调度与精准提醒
- **现代间隔重复算法**：接入完整 FSRS 模型（Difficulty、Stability、Retrievability），比传统 SM-2 更加契合真实遗忘规律。
- **原生系统级温故通知**：根据记忆衰退临界点，通过 macOS 原生通知中心于设定时段推送每日温故提醒。

### 5. 📜 典雅研习长卷导出（Celestial Study Scroll）
- 将今日所学、境界突破、XP 增量与核心感悟一键渲染生成极具东方雅致美感的长卷图片，便于复盘分享。

### 6. 🔒 隐私至上与本地优先（Local-First & Private）
- **数据完全自主**：所有学习记录、图谱结构与统计数据存储于本地 SwiftData SQLite 数据库。
- **硬件级密钥安全**：LLM API Key 仅保存在 macOS Keychain，绝不写入数据库、日志或导出文件。
- **模型自由接入**：兼容任何 OpenAI API 规范的本地（Ollama / LocalAI / LM Studio）或云端模型（DeepSeek / Claude / OpenAI / Qwen 等）。

---

## 🎨 视觉风格 ·「玄墨 / 清境」

知境录采用极具辨识度的东方古典工效学配色方案，完美适配 macOS 明亮与深色模式：

| 语义色彩 | 色彩意象 | 界面角色 |
| :--- | :--- | :--- |
| **玄墨 (Soot Black)** | 徽墨凝香，沉稳坚实 | 窗口基底、边框架构与主体排版 |
| **素绢 (Silk White)** | 羊脂温玉，淡雅柔和 | 浅色模式宣纸质感底色与卡片背景 |
| **青玉 (Jade Green)** | 碧玉生辉，生机盎然 | 掌握度增长、已验证状态与学习活动 |
| **暖金 (Amber Gold)** | 丹炉初温，金芒璀璨 | 修为突破、主修境界与核心行动操作 |
| **朱砂 (Cinnabar)** | 灵符朱印，警醒专注 | 记忆濒临衰退预警与待温故状态 |

---

## 🚀 快速上手

### 环境要求
- **macOS 15.0 (Sequoia)** 或更高版本
- **Xcode 16.0+**
- **XcodeGen**（推荐通过 Homebrew 安装：`brew install xcodegen`）

### 编译与运行

1. **克隆仓库**
   ```bash
   git clone https://github.com/YangChen-cn/Ascend.git
   cd Ascend
   ```

2. **生成 Xcode 工程**
   ```bash
   xcodegen generate
   ```

3. **运行完整测试套件**
   ```bash
   xcodebuild test \
     -project Ascend.xcodeproj \
     -scheme Ascend \
     -destination 'platform=macOS' \
     -derivedDataPath .build/DerivedData
   ```

4. **一键构建与验证**
   ```bash
   ./script/build_and_run.sh --verify
   ```

---

## 🏗️ 架构设计

知境录遵循 Swift 6 严格并发范式，代码组织清晰解耦：

```
Ascend/
├── App/                  # 应用入口、MenuBarExtra 状态机与原生快捷指令
├── Models/               # SwiftData 持久化模型与纯值领域实体 (Sendable)
│   ├── AscendSchema.swift        # VersionedSchema 与无损迁移方案
│   └── ExportBundle.swift        # 完整无损数据备份模型
├── Stores/               # 主线程状态机与业务扩展
│   ├── AppState.swift            # 核心 @Observable @MainActor 状态入口
│   ├── AppState+AIAnalysis.swift # 智能分析与端点调度
│   ├── AppState+ActivityTracking.swift # 目录与 Git 监听
│   ├── AppState+Automation.swift # TriggerEngine 与周期简报
│   ├── AppState+ImportExport.swift # 备份恢复与数据清理
│   ├── AppState+Scoring.swift    # 五维评分与 FSRS 记忆重放
│   └── AppState+Taxonomy.swift   # 领域管理与知识合并
├── Services/             # Actor 隔离的后台引擎与系统连接器
│   ├── AI/                       # OpenAI 兼容协议客户端与流式解析
│   ├── Connectors/               # FSEvents 监听、Git 管道与 Markdown 差异分析器
│   ├── Memory/                   # FSRS 记忆模型与遗忘计算
│   └── Trigger/                  # 幂等触发器引擎与挑战评估器
├── Views/                # SwiftUI 响应式页面与组件
│   ├── Dashboard/                # 研习大盘与今日知得
│   ├── Knowledge/                # 星宿知识图谱与五维维度分析
│   ├── MenuBar/                  # 紧凑型菜单栏驾舱
│   ├── Settings/                 # 数据源、AI 端点与通知偏好
│   └── Export/                   # 研习长卷导出渲染视图
└── Support/              # 主题调色板、结构化日志与通用扩展
```

---

## 🧭 进阶配置与技巧

### 接入本地开源模型（以 Ollama 为例）
1. 启动本地 Ollama 服务（默认端口 `11434`）。
2. 在知境录「设置 > AI 接口」中点击「添加端点」：
   - **名称**：`Ollama Local`
   - **Base URL**：`http://localhost:11434/v1`
   - **API Key**：可留空或输入任意占位符
3. 点击「获取模型列表」，选择你的本地模型（如 `qwen2.5-coder:14b`、`deepseek-r1` 等）并点击设为活跃接口。

---

## 📜 许可证与致谢

- 本项目遵循 [MIT 许可证](LICENSE)。
- 记忆曲线调度依托 [swift-fsrs](https://github.com/open-spaced-repetition/swift-fsrs) 开源实现。

<div align="center">
  <sub>大道至简，知行合一。愿知境录伴你在求知之路上踏实精进，终登化境。</sub>
</div>
