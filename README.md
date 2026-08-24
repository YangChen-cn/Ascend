<div align="center">

<br />

<img src="assets/logo.png" width="128" height="128" style="border-radius: 28px; box-shadow: 0 12px 36px rgba(0,0,0,0.18);" alt="知境录 · Ascend" />

# 知 境 录 · Ascend

### 东方意境 · 本地优先 · 个人研习监控与境界成长系统

<br />

[![Release](https://img.shields.io/github/v/release/YangChen-cn/Ascend?style=flat-square&color=D4AF37&label=最新发布)](https://github.com/YangChen-cn/Ascend/releases/latest)
[![Download DMG](https://img.shields.io/badge/下载-v0.99.0%20DMG%20(Apple%20芯片)-2E7D32?style=flat-square&logo=apple&logoColor=white)](https://github.com/YangChen-cn/Ascend/releases/download/v0.99.0/Ascend-v0.99.0-arm64.dmg)
[![macOS 15.0+](https://img.shields.io/badge/平台-macOS%2015.0%20Sequoia-1C1C1E?style=flat-square&logo=apple&logoColor=white)](https://apple.com)
[![Swift 6.0](https://img.shields.io/badge/语言-Swift%206%20严格并发-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![Local-First](https://img.shields.io/badge/架构-本地优先%20%7C%20SwiftData-2E7D32?style=flat-square)](https://developer.apple.com/xcode/swiftdata/)
[![FSRS v4](https://img.shields.io/badge/记忆模型-FSRS%20科学调度-6A1B9A?style=flat-square)](https://github.com/open-spaced-repetition/fsrs4anki)
[![OpenAI Compatible](https://img.shields.io/badge/智核-兼容%20OpenAI%20规范-00838F?style=flat-square)](https://platform.openai.com)
[![Author](https://img.shields.io/badge/作者-YangChen-blue?style=flat-square)](https://github.com/YangChen-cn)
[![License](https://img.shields.io/badge/许可-MIT%20License-D4AF37?style=flat-square)](LICENSE)

<br />

> *「格物致知，循序渐进；以行践言，终入化境。」*  
> *知境录将你在终端编码、阅读钻研与 Markdown 笔记中的每一次心力倾注，*  
> *淬炼为触手可及的五维认知心印、先修脉络星宿图谱与修真境界跃迁。*

<br />

[📥 **直接下载 v0.99.0 (Apple 芯片 DMG)**](https://github.com/YangChen-cn/Ascend/releases/download/v0.99.0/Ascend-v0.99.0-arm64.dmg) · [📖 **查看更新日志 (Release Notes)**](https://github.com/YangChen-cn/Ascend/releases/tag/v0.99.0)

<br />

---

</div>

<br />

## 📜 缘起 · 研习之道

古之学者必有师，今之行者当自明。

在快节奏的信息洪流与多任务开发中，我们的学习碎片化散落于各处——代码仓库的 Commits、知识库中的 Markdown 笔记、解决技术难点时的灵光一闪。然而，缺乏系统性的沉淀，常使人陷入「学而即忘、零落断层、不知何去何从」的迷茫。

**知境录（Ascend）** 诞生于对「真实研习」的敬畏。它摒弃了形式主义的简单打卡与虚妄积分，静默常驻于 macOS 菜单栏，如同随身司业掌书记，隐式洞察你的实践轨迹，借大语言模型（LLM）提炼真实认知实据，以科学抗遗忘算法抚平遗忘曲线，并借助 **Concept Lineage（先导依赖知识脉络）** 构建会自动生长的学习图谱，助你在知识的浩瀚天穹中，循序渐进，勘破迷障，筑基化境。

<br />

---

## 🪶 核心卷轴 · 六大心法

<br />

### 卷一 · 隐式感知，见微知著
> *「善闭无关楗而不可开，善结无绳约而不可解。」*

- **笔记灵韵感知（FSEvents）**：实时聆听本地知识库（Obsidian、Logseq 等 Markdown 目录）的呼吸，毫秒级智能防抖，文件修润无感收录。
- **研习代码溯源（Git Diff Engine）**：自动拉取并差分本地与远端 Git 仓库的代码增量，智能过滤格式化与琐碎变动，唯取架构与算法演进之精华。
- **去伪存真（Canonical Deduplication）**：双重哈希指纹校验，跨来源与重命名文件精准去重，确保每一分修为皆有据可查。

<br />

### 卷二 · 实据定鼎，五维心印
> *「知者行之始，行者知之成。」*

知境录坚守「真实证据驱动（Evidence-Based）」原则：**平时学习负责自然成长，主动验证只负责提高可信度和突破融会，Production 证据决定化用与通达，FSRS 只负责记忆保持与温故调度。**

每个知识点皆独立维系五维认知心印：

| 认知维度 | 权重 | 释义 | 实据侧重 |
| :---: | :---: | :--- | :--- |
| **接触 (Exposure)** | 10% | 初识概念，见其轮廓 | 技术文档浏览、概念笔记收录 |
| **理解 (Comprehension)** | 25% | 明晰机理，融会贯通 | 原理推导、深入剖析、架构注释 |
| **实践 (Practice)** | 25% | 执斧操斤，学以致用 | 代码实操、工程落地、单元测试 |
| **记忆 (Memory)** | 20% | 刻心镂骨，温故知新 | 基于 FSRS 算法计算的当前即时可提取率 |
| **自主 (Autonomy)** | 20% | 独断破局，化为己用 | 独立解决疑难、自研组件、重构攻坚 |

$$\text{综合掌握度} = 10\% \cdot \text{接触} + 25\% \cdot \text{理解} + 25\% \cdot \text{实践} + 20\% \cdot \text{记忆} + 20\% \cdot \text{自主}$$

#### 六重修真境界阶梯与守卫门槛

```
   初窥门径 ─────────► 入门探索 ─────────► 通晓原理
   (0 - 19 分)         (20 - 39 分)        (40 - 59 分)
   [自然学习即可成长]   [自然学习即可成长]   [接近融会候选验证]
                                                 │
                                                 ▼
   通达化境 ◄───────── 化用自如 ◄───────── 融会贯通
   (90 - 100 分)       (80 - 89 分)        (60 - 79 分)
   [7天间隔双实作]      [独立生产实作]      [主动轻量验证]
```

- **自然学习推动低阶段成长**：笔记与代码分析出的 Artifact 弱证据直接促进初窥与入门成长，无需先做强制考试或审核即可收获掌握度与 XP。
- **高阶 Production 严密守卫**：
  - **融会（60 分）**：至少 1 次独立主动验证或生产实作认证；
  - **化用（80 分）**：必须至少 1 次可靠的独立无辅助生产实作；
  - **通达（90-100 分）**：必须至少 2 次不同情境、间隔 $\ge 7$ 天的独立生产实作；
  - 选择题测评最高只能认证至融会，杜绝刷题虚高。
- **隐藏题包与 0 AI 主动研习**：
  - 分析时内嵌生成的题包持久化为隐藏缓存题库，低境界节点**不产生待验证债务与红点负债**；
  - 用户随时可自愿点击「主动研习」，优先命中缓存题包，**实现 0 次 AI API 调用**；
  - 答题按 BKT 步长温和加速，完成后即刻退出缓存，防止重复刷分。

<br />

### 卷三 · 诸天星宿，脉络通达 (Concept Lineage)
> *「观天之道，执天之行，尽矣。」*

参考 Exercism 与 Roadmap 知识脉络理念，知境录将离散知识升级为具备严格先导依赖与动态解锁机制的立体知识脉络：

- **六大灵脉关联**：
  - **先修先导 (`prerequisite`)**：严格有向 DAG 依赖，$A \xrightarrow{\text{prerequisite}} B$，学 $B$ 前需先掌握 $A$（掌握度 $\ge 60$ 融会起点）。
  - **横向关联 (`related`)**、**包含所属 (`partOf`)**、**辨析对照 (`contrasts`)**、**实战应用 (`applies`)**、**衍生推导 (`derivedFrom`)**。
- **成环检测防御**：关系生成与人工审核时实施严格环路检测（Cycle Detection），坚决阻断循环前置依赖。
- **FSRS 实时 Readiness 动态衰减**：前置状态随遗忘曲线动态演进。当前置知识遗忘导致掌握度跌落时，下游概念自动重新转为「受阻（Blocked）」，但绝不回退历史成就。
- **「下一境」智能推演**：前置全部就绪后，推荐引擎自动点亮「下一境 · 待修探索」；AI 提炼生成克制的下一境候选，经用户确认后方才纳入图谱。
- **天球星宿图谱（Celestial Constellation）**：各领域知识节点化为漫天星宿。核心主星居中，同心天轨环绕，各星依修为高低与解锁状态绽放金青华彩。

<br />

### 卷四 · 晨昏温故，心神警醒 (Flashcards & FSRS)
> *「学而时习之，不亦说乎。」*

知境录将「**主动印证**（判断会不会）」与「**晨昏温故**（防止遗忘）」彻底拆分：

- **温故 0 AI 调用**：打开温故、翻看要点、提交复习反馈绝对不产生任何 AI API 请求，极致轻量快速。
- **快速回忆知识卡（Flashcard Deck）**：
  - 默认展示知识点名称与回忆启示，点击「查看要点」后展开富文本核心总结；
  - **可信本地笔记呼出预览**：在温故卡片中可直接弹窗预览该知识点已验证的 Markdown 笔记与代码上下文，加深回忆；
  - **四档科学 FSRS 评级**：遗忘 (Again)、困难 (Hard)、良好 (Good)、容易 (Easy)，科学更新稳定性、难度与下次复习计划。
- **智能免打扰通知（Delivery Policy）**：
  - 同一时间窗口到期的温故计划聚合为单条通知，避免横幅轰炸；
  - 每日战报前后 15 分钟内的温故提醒由战报自动合并吸收；
  - 30 分钟静默冷却期，守护深度工作专注。

<br />

### 卷五 · 研习长卷，水墨留痕
> *「翰墨流光，寸阴可惜。」*

- **每日知得长卷（Celestial Study Scroll）**：将每日研习心得、掌握度跃迁、XP 增量与参悟摘要，一键凝练为东方水墨长卷，便于留存、复盘与雅鉴。

<br />

### 卷六 · 洞府清修，私密无虞
> *「万物并作，吾以观复。」*

- **纯粹本地优先（Local-First）**：所有修行数据安居于本地 SwiftData 数据库，离线亦可运转如常。
- **关系溯源与无损归档（Full Provenance & Lossless Export）**：知识边完整记录 `origin`（AI 推导 / 人工确认 / 归档导入）、`rationale` 与时间戳；JSON 备份与恢复实现 100% 往返无损。
- **硬件级玄关密锁（Keychain Isolation）**：大模型 API Key 专存于 Apple Keychain 硬件安全区域，绝不写入数据库、代码库或日志。
- **开源心核自由兼容**：支持接入本地部署的开源大模型（如 Ollama、LM Studio、LocalAI 中的 Qwen、DeepSeek），亦可接入 OpenAI、Claude、DeepSeek 等云端接口。

<br />

---

## 🎨 视觉心境 ·「玄墨 / 清境」

知境录的视觉设计融入了中国古典文人书房的器物美学，同时兼顾 macOS 现代工效学：

```
  ┌─────────────────────────────────────────────────────────────┐
  │  玄 墨 (Soot Black)    ── 徽墨凝香，沉稳内敛，铸就结构筋骨   │
  │  素 绢 (Silk White)    ── 宣纸温润，澄怀观道，浅色模式基底   │
  │  青 玉 (Jade Green)    ── 碧玉生辉，灵动生发，象征成长进阶   │
  │  暖 金 (Amber Gold)    ── 丹炉金芒，璀璨夺目，映照修真境界   │
  │  朱 砂 (Cinnabar Red)  ── 朱批警策，明艳醒目，预警遗忘临界   │
  └─────────────────────────────────────────────────────────────┘
```

<br />

---

## ⚡️ 快速启程

### 研习环境
- **操作系统**：macOS 15.0 (Sequoia) 或更高版本
- **编译工具**：Xcode 16.0+
- **工程构建器**：XcodeGen（推荐通过 Homebrew 安装：`brew install xcodegen`）

### 叩问法门

1. **获取典籍**
   ```bash
   git clone https://github.com/YangChen-cn/Ascend.git
   cd Ascend
   ```

2. **生成玄机（Xcode 工程）**
   ```bash
   xcodegen generate
   ```

3. **合道验真（运行全量 270+ 单元测试，约 11 秒）**
   ```bash
   xcodebuild test \
     -project Ascend.xcodeproj \
     -scheme Ascend \
     -destination 'platform=macOS' \
     -derivedDataPath .build/DerivedData
   ```

4. **一气呵成（一键验证构建与启动）**
   ```bash
   ./script/build_and_run.sh --verify
   ```

<br />

---

## 🔮 灵核接入 · 本地大模型示范

若欲在本地完全离线清修，推荐使用 [Ollama](https://ollama.ai)：

1. 终端启动本地 Ollama 守护：
   ```bash
   ollama run qwen2.5-coder:14b
   ```
2. 打开知境录「设置 ➔ AI 接口 ➔ 添加端点」：
   - **端点名称**：`本地 Ollama`
   - **Base URL**：`http://localhost:11434/v1`
   - **API Key**：可留空或填入任意字符
3. 点击「测试连接」并选择已下载的模型，即刻启用全本地 AI 认知提炼。

<br />

---

## 🗂️ 洞府藏经 · 架构规制

```
Ascend/
├── App/                  # 灵机枢纽：应用生命周期与菜单栏常驻驾舱
├── Models/               # 境界法度：SwiftData 实体模型与无损迁移方案
│   ├── AscendSchema.swift        # Schema 版本演进与数据迁移计划
│   ├── KnowledgeNode.swift       # 知识实体与五维认知心印
│   ├── KnowledgeEdge.swift       # 先导 DAG 与六大关联网络（带 Provenance 溯源）
│   ├── TaxonomySuggestion.swift  # 结构化纳新、合并与先导关系审核建议
│   ├── AssessmentSession.swift   # 隐藏缓存题包、主动研习与轻量验证会话
│   ├── MemoryState.swift         # FSRS 稳定性、难度、可提取率与温故计划
│   └── ExportBundle.swift        # 全量修行数据无损备份与还原
├── Stores/               # 气运流转：主线程 @Observable 状态机扩展
│   ├── AppState.swift            # 状态枢纽与 FSRS 实时掌握度驱动
│   ├── AppState+ActivityTracking.swift # 资料源监听与隐式扫描
│   ├── AppState+AIAnalysis.swift # 智能提炼、批次调度与脉络发现
│   ├── AppState+Scoring.swift    # 五维心印、BKT 掌握度与 XP 净增结算
│   ├── AppState+Assessment.swift # 隐藏题包发现、0 AI 主动研习与自适应测评
│   ├── AppState+Memory.swift     # FSRS 温故快速卡片与笔记即时预览
│   ├── AppState+Taxonomy.swift   # 知识审核闭环、DAG 成环校验与下一境创建
│   ├── AppState+Automation.swift # 周期演进、免打扰通知投递与心神传讯
│   └── AppState+ImportExport.swift # 备份卷轴导出与数据清理
├── Services/             # 乾坤推演：Actor 隔离的高性能后台引擎
│   ├── AI/                       # OpenAI 协议兼容客户端
│   ├── Connectors/               # FSEvents 监听、Git 管道与 Markdown 差异分析器
│   ├── Topology/                 # LearningTopologyEngine 先导 DAG 拓扑推演引擎
│   ├── Recommendation/           # LearningRecommendationEngine 下一境与复习推荐
│   ├── Memory/                   # FSRS 记忆模型与遗忘计算
│   └── Trigger/                  # 幂等触发器引擎与挑战评估器
├── Views/                # 幻境显化：SwiftUI 现代古典交互组件
│   ├── Dashboard/                # 修为大盘与今日知得
│   ├── Knowledge/                # 天球星宿图谱、脉络图与分类审核弹窗
│   ├── Review/                   # 快速回忆知识卡与笔记即时呼出预览
│   ├── Assessment/               # 自愿主动研习与轻量突破验证
│   ├── MenuBar/                  # 菜单栏微缩驾舱
│   ├── Settings/                 # 秘钥、数据源与偏好配置
│   └── Export/                   # 水墨研习长卷渲染视图
└── Support/              # 辅助符篆：主题调色盘、结构化日志与通用扩展
```

<br />

---

## 📥 飞升启程 · 安装与部署

### 1. 直接下载 DMG 镜像（推荐）
- 前往 [GitHub Releases](https://github.com/YangChen-cn/Ascend/releases/latest) 下载最新版本的 `Ascend-v0.99.0-arm64.dmg`。
- 双击 DMG，将 **知境录** 拖拽入 `Applications` 应用程序文件夹。
- 首次打开若提示未经公证，前往 macOS **系统设置 > 隐私与安全性**，点击「仍要打开」即可。

### 2. 源码构建与运行
```bash
# 1. 克隆仓库
git clone https://github.com/YangChen-cn/Ascend.git
cd Ascend

# 2. 生成 Xcode 工程 (需已安装 xcodegen: brew install xcodegen)
xcodegen generate

# 3. 运行测试并启动应用
./script/build_and_run.sh
```

<br />

---

## 📜 律令与谢忱

- **作者**：[YangChen](https://github.com/YangChen-cn)
- **仓库地址**：[https://github.com/YangChen-cn/Ascend](https://github.com/YangChen-cn/Ascend)
- **开源协议**：本项目采用 [MIT 许可证](LICENSE)。
- **记忆模型**：依托开源 [swift-fsrs](https://github.com/open-spaced-repetition/swift-fsrs) 项目。

<br />

<div align="center">

*大道至简，知行合一。愿知境录伴你在求知之路上精进不休，终登化境。*

<br />

</div>
