# 知境录项目交接说明

更新时间：2026-09-03

本文描述当前工作区的实际实现边界。产品目标是从“根据学习产物打分”升级为“根据可验证表现估计掌握程度”，同时保留日常学习的低阶自然成长体验。

## 一、不可破坏的产品约束

- 掌握度按知识点维护接触、理解、实践、记忆、自主五维，并按领域独立聚合。
- Markdown、代码和 Git 提交属于可追溯的资料或候选实作，不能仅凭作者声明直接证明高阶能力。
- 选择题可提供直接知识表现，但不能单独认证化用或通达；生产实作才是高阶门槛。
- XP 只奖励新的掌握峰值或挑战完成结果。失败可降低当前估计，但不倒扣历史 XP 和最高境界。
- FSRS 只处理实际回忆后的记忆调度，不能由普通活动、按钮点击或作者声明伪造复习证据。
- API Key 只进 Keychain；完整源码、完整题目和正确答案默认不导出，也不得写日志。

## 二、已经完成

### 1. 数据采集与分析

- 支持本地 Markdown 目录监听、协调扫描和 Remote Git Repository 同步。
- Activity、内容变更哈希与 Evidence 的 canonical identity 分离，避免同内容跨来源重复计分。
- AI 分析负责知识提炼、领域/关系建议、资料覆盖度和隐藏题包；失败或结构不合法时不写评分。
- 分析批次按全局上限分批，进度与普通状态消息分层显示；题包可在分析时一并缓存，后续主动研习优先 0 AI 启动。
- 删除数据源时会清理其仍待分析的跟踪活动，已经处理过的历史记录按当前保留策略继续用于审计；远端仓库首次同步后可进入资料流。

### 2. 掌握、XP 与境界

- 资料覆盖基线与直接测评/实作投影分离，系统性首篇笔记可以建立低阶基础，短小后续笔记不会覆盖既有掌握。
- BKT 风格观察、五维加权、历史峰值 XP、作废重放和模型版本均有纯逻辑测试。
- 领域聚合保留广度要求，同时采用有限的代表知识点策略，避免大量低信息节点无限稀释已掌握主题。
- 融会需要直接验证；化用、通达仍受 Production 次数、不同情境与时间间隔守卫。

### 3. 主动研习与温故

- 题包本地判分，答案与理由分步展示，逐题结算；支持跳过/未学，不会因单题卡死。
- 备题和核验任务可取消，取消不会留下半成品会话或部分 Evidence。
- 预备题包不会自动抢焦点弹窗；用户通过主窗口、菜单栏或通知主动进入。
- 温故与主动验证解耦。温故使用本地 FSRS、四档回忆反馈和关联可信笔记，不调用 AI。

### 4. Challenge 实作核验

- Challenge 支持两条完成路径：选择题提供较少 Challenge XP；代码/文件实作通过核验后获得完整 Challenge XP。
- 用户声明不再直接通过挑战。提交来源需要经过一次独立 AI 量规复核，失败会展示具体缺口，并在下次提交时带回上次失败原因。
- 可使用最近三天采集到的 Git 提交或本地文件。聚合提交可展开并选择具体代码文件，避免 13 个文件被当作一个不可辨识来源。
- Git Diff 按挑战关键词优先抽取相关实现，单文件选择可获得更完整片段；总审计内容有长度上限并做密钥脱敏。
- 用户可取消进行中的核验、复制完整实作要求到剪贴板、放弃进行中的挑战。以上操作不会误发 XP 或删除历史学习数据。
- Challenge 完成评估区分 `directChoice` 与 Production verification level，多知识点挑战仍要求逐点覆盖。

### 5. Markdown 预览与应用入口

- 知识详情和温故卡的全部 Markdown 预览已统一为 `MarkdownNotePreviewSheet`。
- 渲染层已替换为 SwiftUI 原生管线的 Textual 0.5.0，支持标题、列表、代码围栏、表格、选择和滚动；旧的手写逐行解析器已删除。
- 预览只对真实可定位的 `.md` Activity 开放。远端 Git 定位会回落到本地 checkout 中的对应文件；无法解析的代码/回执只显示摘要。
- 图片加载器只读取笔记目录内的本地图片，拒绝网络图片、路径穿越和符号链接越界，单图限制 12 MiB。
- 应用已启用 Dock 图标，同时保留菜单栏驾驶舱；主窗口关闭后可通过 Dock 或菜单栏重新打开。

## 三、仍待解决或刻意未做

### P0：发布前人工验收

- 当前没有 UI Test 或截图回归基线。需要人工检查玄青/清简、明暗模式下的长文、表格、嵌套列表、超长代码块、本地图片、损坏图片和窄窗口布局。
- 需要在真实历史数据库上做一次端到端烟雾测试：远端同步 → 分析 → 缓存研习 → 逐题结算 → 温故 → Challenge 两种完成路径。

### P1：实作证据强度

- 当前代码实作是“有限 Diff/文件片段 + AI 隐藏量规”的语义核验，不会在隔离环境中编译或执行用户项目，因此不是确定性测试 Receipt。
- 后续可实现用户逐次授权的固定 executable/arguments 测试运行、前后哈希、有限 Diff 与测试结果 Receipt；不得经 shell 拼接命令。
- 代码证据目前只显示摘要，没有独立的安全 Diff 浏览器。若增加，应继续遵守按文件读取、脱敏、长度限制和不持久化完整源码的边界。

### P1：Markdown 体验

- Textual 使用 GitHub 基础样式，尚未针对玄青/清简建立完整的语义化 Markdown 主题。
- 远程图片被有意禁用；如未来开放，必须提供显式“加载远程图片”操作，不能默认联网。
- Textual 仍处于 0.x，且带有 `swift-concurrency-extras`、`swiftui-math` 传递依赖。升级前需复测启动、内存、包体积和 Swift 6 并发。

### P2：测试与校准

- 常规测试只使用 mock/fixed fixture，不覆盖真实 AI 服务的偶发协议差异。真实接口测试只能人工明确触发，并限制请求次数。
- Brier 指标只有在可计分观察达到样本门槛后才有意义；样本不足时继续显示初始估计，不能宣称心理测量校准完成。
- 建议补充 Markdown 渲染快照测试、超长 Diff 性能测试、历史数据库迁移夹具以及 Dock/通知深链的 UI 自动化。

## 四、关键数据流

```text
Local Markdown / Remote Git
        ↓
ActivityEvent（来源、定位、哈希、有限摘要）
        ↓
AI Analysis（知识、关系、coverage、隐藏题包）
        ↓
Artifact Evidence ──→ 资料基础与低阶自然成长
        │
        ├─ 主动选择题 ──→ MasteryObservation / 低奖励 Challenge 路径
        ├─ 到期温故 ───→ FSRS / 记忆维度
        └─ 实作提交 ───→ AI Challenge Review / Production Receipt
```

## 五、关键文件

- `project.yml`：XcodeGen、部署目标和 SPM revision 的唯一配置来源。
- `Ascend/Stores/AppState.swift`：主线程全局状态与任务生命周期。
- `Ascend/Stores/AppState+AIAnalysis.swift`：分析持久化和题包缓存。
- `Ascend/Stores/AppState+Assessment.swift`：主动研习与 BKT 观察。
- `Ascend/Stores/AppState+Review.swift`：可信温故资料与 FSRS 流程。
- `Ascend/Stores/AppState+Performance.swift`：Challenge 实作提交与 AI 复核。
- `Ascend/Services/ChallengeEvaluator.swift`：两条 Challenge 完成路径及覆盖守卫。
- `Ascend/Services/ChallengeEvidenceExcerptLoader.swift`：Git 文件列表、相关 Diff 截取和脱敏。
- `Ascend/Services/ReviewActivityLocator.swift`：Markdown Activity 定位与类型判定。
- `Ascend/Views/Knowledge/LocalMarkdownDocumentView.swift`：Textual 唯一适配层及本地图片策略。
- `Ascend/Views/Knowledge/MarkdownNotePreviewSheet.swift`：全应用统一预览窗口。
- `Ascend/Models/AscendSchemaV10.swift`、`Ascend/Models/AscendMigrationPlan.swift`：当前持久化 schema 与迁移。

## 六、开发与发布检查

```bash
xcodegen generate

xcodebuild test \
  -project Ascend.xcodeproj \
  -scheme Ascend \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData

./script/build_and_run.sh --verify
```

发布使用 `./script/package_release.sh`。提交前检查仓库不包含 API Key、Authorization Header、用户源码、日志、截图、`.build/DerivedData` 或 `dist/`。发布包还必须通过便携路径检查和固定证书签名。
