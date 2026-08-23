# 知境录 v0.9.0 · 筑基初成 (Ascend v0.9.0)

> *「格物致知，循序渐进；以行践言，终入化境。」*

**知境录（Ascend）** 迎来首个正式对外预览里程碑 —— **v0.9.0**。  
这是一个面向 **macOS 15+** 的**本地优先（Local-First）个人研习监控与境界成长系统**。它静默常驻于菜单栏，以严谨的「真实学习证据」定鼎修为，借大模型提炼认知实据，融合 FSRS 算法科学抗遗忘，并以 **Concept Lineage（先导依赖知识图谱）** 构建会自动生长的技能脉络，助你在广袤知识天穹中循序渐进、筑基化境。

---

## 🌟 核心特性与亮点 (Highlights)

### 1. 诸天星宿 · 先导依赖知识脉络 (Concept Lineage)
- **严格有向 DAG 先导依赖**：参考 roadmap.sh 与 Exercism Concept Trees 设计，$A \xrightarrow{\text{prerequisite}} B$，学 $B$ 前需先掌握 $A$（达到融会 60 分门槛）。
- **六大灵脉语义关联**：支持先导依赖 (`prerequisite`)、横向关联 (`related`)、包含所属 (`partOf`)、辨析对照 (`contrasts`)、实战应用 (`applies`) 与衍生推导 (`derivedFrom`)。
- **成环检测防御**：关系提炼与审核时实施严格 Cycle Detection 校验，坚决阻断循环依赖。
- **下一境智能解锁**：前置节点全部达标后自动点亮「下一境 · 待修探索」；前置若因遗忘衰减跌破门槛，下游概念自动转为「受阻（Blocked）」保护，但绝不扣减历史最高境界与既得经验。
- **原子化审核闭环**：新概念与前置关系全流程 Preflight 预检，杜绝部分提交与脏数据。

### 2. 天球星宿图谱与 60/120 fps 丝滑体验 (Interactive Visualizer)
- **手势与拖拽重构**：彻底修复累加位移抖动，实现完全跟手的 1:1 实时连续拖动与排布。
- **单击选中 / 双击研习**：单击节点仅高亮聚焦因果知脉，双击正式开启右侧知识点详情面板。
- **因果链全路径穿透高亮**：在星图中点击或悬停任何概念，自动穿透高亮其完整前置祖先因果链（Ancestors）与后继解锁概念（Descendants），背景非相关节点优雅降亮。
- **批量拓扑预计算**：全量掌握度与 FSRS 状态单次批量计算，彻底根除 UI 渲染与拖动过程中的卡顿。

### 3. 五维心印 · 真实证据驱动评分 (Evidence-Based Scoring)
- **五维认知模型**：固定权重比例 —— **接触 10%**、**理解 25%**、**实践 25%**、**记忆 20%**、**自主 20%**。
- **六重修真境界**：初窥门径 (0–39)、入门探索 (40–59)、通晓原理 (60–74)、融会贯通 (75–84)、化用自如 (85–89)、通达化境 (90–100)。
- **XP 只增不减**：经验值仅由已验证实据的正向增量产生，遗忘只影响即时记忆保持率，绝不扣除历史 XP。

### 4. FSRS v4 科学记忆调度 (Memory Scheduling)
- **实时可提取率动态预测**：基于真实温故知新事件计算 Retrievability、Stability 与 Difficulty。
- **智能温故知新**：临近遗忘点时自动调度复习计划并推送 macOS 通知。

### 5. 本地优先与全隐私保障 (Privacy & Local-First)
- **双轨增量采集**：本地 Markdown（FSEvents 毫秒级防抖）与 Remote Git Repository（Unseen Commits 游标推进）。
- **安全存储**：API Key 仅存于系统 Keychain，绝不写入 SwiftData 数据库或日志；数据全本地沉淀，支持无损 JSON 导入导出。
- **全新关于页**：内建系统心法、版本信息、作者与开源仓库直达。

---

## 📦 下载与安装 (Installation)

- **适用系统**：macOS 15.0 (Sequoia) 及更高版本
- **硬件架构**：Apple 芯片（M1 / M2 / M3 / M4 系列）原生支持
- **DMG 安装**：
  1. 下载下方 `Ascend-v0.9.0-arm64.dmg`；
  2. 双击打开并将 **知境录** 拖入 **Applications（应用程序）** 文件夹；
  3. 首次打开若提示未经公证，前往 **系统设置 > 隐私与安全性** 点击「仍要打开」即可。

---

## 🔒 校验和 (Checksums)

```text
SHA256 (Ascend-v0.9.0-arm64.dmg):
e5f2ad0039dcff37087a84e5952cbbc96aa0cb78fb9ef8339a947d0cf9af5bde
```

---

## 👨‍💻 作者与开源信息 (Author & License)

- **作者**：[YangChen](https://github.com/YangChen-cn)
- **开源仓库**：[https://github.com/YangChen-cn/Ascend](https://github.com/YangChen-cn/Ascend)
- **许可证**：MIT License
