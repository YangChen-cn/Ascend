# 知境录 · 产品理念对齐优化计划

三个审阅 agent 已通读 Models / Stores / Services / Views / Tests。核心理念（无感成长、净增 XP、四类证据分离、温故 0 AI、低境界零债务）大多已有扎实实现和测试；主要偏差集中在四处：**化用/通达事实不可达**、**1 题全对即「已印证」过宽**、**内部算法数字大面积直露 UI**、**多处以「待办/催办」口吻制造债务感**。另有一个真实数据缺陷（production 投影会把 artifact 成长清零）。

按已确认的四个决策执行：手动实作登记入口（V1 无 AI）、印证门槛 ≥2 次答对、数字温和收敛、研习题允许提交错误答案。

---

## P0 · 判定正确性与高境界可达性

### 1. 修复 production 投影清零 artifact 成长（数据 bug）
`Ascend/Stores/AppState+Performance.swift:164-178` 的 `synchronizePerformanceProjection` 用 `(estimate ?? 0) * 100` 直接覆写五维，首条实作证据会把无 estimate 维度（exposure/understanding/practice 等）拉到 0。改为与 `AppState+Assessment.swift:1261-1281` 一致的 `max(state.vector.x, estimate*100)` 投影：estimate 只覆盖被测维度（autonomy），其余保留 artifact 成长。
- 测试：节点先走 artifact 成长（复用 `MasteryPresumptionAndVerificationTests` 夹具），再 `recordVerifiedPerformance`，断言其余四维不回退、composite 单调。

### 2. 印证门槛收紧至 ≥2 次独立答对
- `Ascend/Stores/AppState.swift:361-363` `hasPassingChoiceAssessment` 从「任意 1 个 response 全对」改为「≥2 个不同 response 全对」（responseID 去重计数）。
- 联动自适应引擎：`Ascend/Services/AssessmentAdaptiveEngine.swift` 目前允许 1 题全对即结束；当 session 为验证意图（节点 `currentComposite ≥ 45` 或 `certifiedStage ≥ 通晓`）且题库 ≥2 题时，最少答 2 题才提前结束，避免「答对了却不认证」的困惑。研习意图（低境界）保持 1 题可结束——低境界不强制做题。
- `isCertified` / `verificationBadgeTitle`（`MasteryReadinessSnapshot.swift:46-58`）语义自动随之收紧。
- 更新受影响测试（`MasteryPresumptionAndVerificationTests`、`AssessmentIntegrationTests` 等中 1 题全对即融会的用例改为 2 题）。

### 3. 实作认证手动登记入口（化用/通达可达，0 AI）
新视图 `Ascend/Views/Assessment/PerformanceAttainmentView.swift`（sheet 表单），入口放在知识详情页 `AssessmentLaunchButton` 旁，仅当 `certifiedStage ≥ 融会 || currentComposite ≥ 60` 时显示（低境界不引入噪音）：
- **情境**：项目/情境名称（生成规范化 contextHash）+ 描述；提示「同一情境只认证一次；通达需两次不同情境、间隔 ≥7 天」（与 `stageBlockReason` 文案一致）。
- **独立声明**：勾选「本次实作未借助资料、提示或 AI」（对应 `assistanceMode = .declaredUnassisted`）。
- **认证方式二选一**：
  - 量规自评（`.productionRubric`）：3 条勾选量规（真实项目情境 / 独立完成 / 达到预期质量），全勾才给 `scoringConfidence ≥ 0.8` 通过守卫，部分勾选被拒并解释；
  - 确定性验证（`.productionDeterministic`）：填写测试/构建/CI 结果说明，通过 → score 1、confidence 1。
- 走现有 `recordVerifiedPerformance`（`AppState+Performance.swift:4-107`）完整链路（receipt + evidence + BKT + XP + gates），不新增评分路径、不调 AI。
- 详情页新增「实作认证」小区块：列出 receipts（情境名、时间、「通过」语义徽章），替代裸分数。

### 4. 遗忘回退的解释文案
`AppState.swift:366-385` `stageBlockReason` 目前只解释 gate 缺口。补充：当 `currentStage` 低于 `historicalStage` 且衰减前 composite 本可支撑更高境界时，reason = 「记忆自然回落影响当前状态；温故即可恢复，历史境界与知验不受影响」。消除境界静默回退的不可解释性。

---

## P1 · 外部简单：数字与待办感收敛（温和档）

### 5. 详情页收敛（`KnowledgeDetailView.swift`）
- 徽章 `:44` 改用已实现但零调用的 `stageDisplayTitle`（`MasteryReadinessSnapshot.swift:60-68`）——「通晓 · 待印证」「融会 · 已印证」。
- 指标格 `:79-87`：删除「掌握估计」（环心已有分）、「模型校准 Brier」（纯内部统计量）、「印证状态」四档（`measurementStatus` 保留内部，不再展示）；「记忆保持」数字改三档语义（记得牢 / 略有生疏 / 需温故，无数据→「尚未安排温故」），精确数字进 tooltip；保留「累积知验 XP」。
- 五维条带 `MasteryDimensionStrip.swift`：保留条带图形，裸分数从 `.title2` 大数字降为 caption 小字（或仅 tooltip），不再五个大数字同屏。
- `stageBlockReason`（`:125-129`）提升视觉权重：加边框/背景的提示胶囊，与金色大环竞争可读。
- `EvidenceLedgerView.swift:36-42` 去掉「+0.4」小数增量与 help 中「43.2 → 43.6」精度（改为 XP 与境界语义）。

### 6. 其余页面数字收敛
- `ConceptLineagePathwayView.swift:104,112`：「已融会 (63)」「未达标 (41/60)」→「已融会」「未达融会」（分数进 tooltip）。
- `CelestialConstellationGraphView.swift:487-494`：图例去掉分数区间，六境分色图例不带「60-79」等数字。
- `MasteryChangeListView.swift` / `XPGainLedgerView.swift`：`.largeTitle` XP 与三列变化数字降权为 caption/次要位置（保留信息，不再是大屏主视觉）。
- 温故侧：`ReviewPlanCardView.swift:108-142` 移除「当前记忆可提取率 XX%」进度条与「已复习 N 次」→ 状态徽章（到期/按节奏安排中）；`ReviewQueueView.swift:130-135` 页头百分比与 `ReviewScienceRailView.swift:75-108` 的「可提取率/−N 掌握」收敛为语义文案，百分比进 tooltip。删除 `ReviewFlashcardDeckView.swift:28-31,397-405` 死代码（currentRetention/retentionColor）。

### 7. 待办感与压力文案收敛
- `MenuBarAttentionSection.swift`：区块「待办」更名「温故提醒」；到期温故与「待确认建议」分离；taxonomy 建议不再逐条朱砂罗列（限 3 条、中性色、更多入口）。
- `MenuBarNavigationGrid.swift:59-81`：债务三格（待析/到期/待确认）零值不显示或中性色；「待确认」朱砂改中性。
- `MenuBarQuickActions.swift:183-190`：「备题 N / 续备 N / 验证 N」→「主动研习」不带批量计数口吻。
- `TodayDashboardView.swift:17-43`：朱砂横幅「N 条待确认」→ 可折叠的温和提示条。
- `SidebarView.swift:119-127`：「待定真意 N」朱砂徽章 → 0 时隐藏、非 0 中性色。
- `ForgettingListView.swift`：「N 待巩固」朱砂 → 玉青中性；「−N 掌握」→「记忆自然回落」语义。
- 通知文案 `NotificationDeliveryPolicy.swift:8-22`：标题「知境录 · 到期复习」→「知境录 · 温故」，正文用「温故」术语（聚合梯度文案结构不变，更新对应测试断言）。
- `NextStageView.swift:62-70`：按钮与 gate 对齐——无 directAssessment 时主按钮直接复用 `AssessmentLaunchButton`（主动印证），替代语义脱节的「接受破境挑战」。
- `OnboardingGuideCard.swift`：补一句预期管理：「此后无需做题，日常学习会自动推动初窥 → 通晓」。

---

## P2 · 研习与温故体验轻量化

### 8. 研习题允许提交错误答案（已确认）
`AssessmentSessionView.swift:141-190`：判断题选定即可「提交本题」，不再强制重答；答错直接进入讲解反馈（现有 feedbackView 的答案/理由/误区展示），首次表现如实入账（BKT 语义不变——首判为准、不因重试覆盖）；答对才解锁理由题（保持现锁逻辑但删掉 `answerValidationMessage` 强制重答分支）。更新 answerGate 相关单测。

### 9. 研习流程减负
- 移除 `AssessmentSessionView.swift:70-71` 的 `interactiveDismissDisabled`：未完成 session 状态已持久化，`cachedAssessment(for:)` 会重新命中，关闭即「稍后继续」，文案注明。
- `AssessmentLaunchButton.swift:40-60`：无缓存时按钮副标题/徽章面显「生成研习题 · 1 次 AI」（当前只在 hover help），命中缓存保持「题目已备好 · 0 AI」。

### 10. 温故文案与提示统一
- 四档评分三套文案统一为一套：「忘了 / 有点模糊 / 记得 / 很熟」——对齐 `MemoryReviewGrade.title`（`MemoryReviewGrade.swift:11-18`）、`ReviewGradeButtonsView.swift:13-16`、`AppState+Review.swift:166` statusMessage；`ReviewScienceRailView.swift:35` 的英文「Again/Hard/Good/Easy」改中文四档（FSRS 术语名可留 tooltip）。
- 卡片正面回忆提示差异化：`ReviewFlashcardDeckView.swift:153-199` 静态通用文案改为节点特定提示（取已验证证据摘要生成一行引导，不暴露完整要点）。
- 正面「预览笔记」按钮 `:124-133` 按 `sourceKind` 挑 markdown 活动而非 `first`。

---

## P3 · 口径与健壮性小修

11. **ledger 口径**：`finalizeAssessment`（`AppState+Assessment.swift:1082-1106`）与 production 路径中 `previousComposite` 记 peak 导致 `weeklyChange`/trajectory 虚高——ledger 改记结算前真实 composite，peak 只用于 XP 计算。加单测（重测下降场景 weeklyChange 不虚报）。
12. **通知 receipt**：`AppState+Automation.swift:282,304` 投递成功但 `try? save()` 失败会重发同批——投递成功后无论 receipt 落库是否成功都推进 cooldown（内存 + best-effort 持久），重复打扰优先于可重试性；失败记日志。
13. **死代码清理**：`ScoringEngine.replay`、`replayArtifactEvidence`（`AppState+Scoring.swift:187-233`）、`skipAssessmentItem` 的无人读取冷却写入（`AppState+Assessment.swift:877-878`）——删除或接线；`MasteryState.confidence/stabilityDays` 等 SwiftData 字段保留（避免无谓迁移），仅停止写入并注释。
14. **可选（默认执行，若触发 schema 迁移则降级为字符串判定加固）**：`[低信息代码变更]` 前缀判定（`AppState+AIAnalysis.swift:337-341`）改结构化标志。
15. **DomainRealm XP 门槛重标定暂缓**（300/1000/3000/7000/15000 与净增 XP 量级偏紧）：本轮只观测不动参数，避免同时改两套口径。

---

## 执行顺序与验证

1. P0（1→2→3→4）→ P1（5-7）→ P2（8-10）→ P3（11-13）。
2. 每个行为改动配/改单元测试（评分门槛、projection、ledger 口径、自适应最少题数、通知文案、量规守卫、幂等）。
3. 收尾：`xcodegen generate`（如有资源/文件新增）→ 全量 `xcodebuild test` → `./script/build_and_run.sh --verify`。
4. 不使用 Computer Use 验证 UI，构建与单测通过后由你自行运行确认视觉。