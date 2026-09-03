# AGENTS.md

## 项目概览

知境录是一个面向 macOS 15+ 的本地优先个人学习监控与成长系统。应用使用 Swift 6、SwiftUI、SwiftData、Keychain 和 Swift Concurrency。

产品原则：

- 只根据可追溯的真实学习证据更新掌握度和 XP。
- 知识点维护接触、理解、实践、记忆、自主五维评分。
- 每个领域独立计算掌握度、XP 与境界，领域之间不得混算。
- 历史掌握与当前状态是两个概念：遗忘只影响当前记忆保持和即时状态，不得回退历史 XP、最高境界或删除历史证据。
- Challenge XP 与 Knowledge XP 必须分离；复习、挑战和境界变化只能由真实、已验证且可追溯的 Evidence 触发。
- 平时学习负责自然成长，主动验证只负责提高可信度和突破融会，Production 证据决定化用与通达，FSRS 只负责记忆保持与温故调度。
- API Key 只能保存在 Keychain，不得进入 SwiftData、日志、测试夹具或导出文件。
- 默认数据库必须为空，不得加入演示知识、虚构证据、默认 XP 或默认境界。
- AI 请求失败、格式错误或证据置信度不足时不得改变评分。

## 工程与运行

- Xcode 工程由根目录的 `project.yml` 使用 XcodeGen 生成。
- 修改目标、构建设置、版本号或资源配置后运行：`xcodegen generate`。
- 构建并启动：`./script/build_and_run.sh`。
- 仅验证构建和进程：`./script/build_and_run.sh --verify`。
- 单元测试（全量 ~11 秒）：

  ```bash
  xcodebuild test \
    -project Ascend.xcodeproj \
    -scheme Ascend \
    -destination 'platform=macOS' \
    -derivedDataPath .build/DerivedData
  ```

- 不要手工编辑 `Ascend.xcodeproj/project.pbxproj`；应修改 `project.yml` 后重新生成。

## 发布构建、便携化与代码签名

- 发布打包统一使用 `./script/package_release.sh`（或 `./script/package_dmg.sh`）。
- **零开发机路径残留（Path Independence）**：
  - Release 构建注入 `-file-prefix-map $ROOT_DIR=AscendBuild`，防止源码绝对路径进入二进制符号表。
  - 使用 `strip -S` 剥离指向 DerivedData 的 Swift AST / debug 记录。
  - 自动清理非便携绝对路径 RPATH，只保留系统路径与 `@executable_path/../Frameworks`。
  - 静态 UI 占位符与示例文本严禁使用 `/Users/...` 等前缀，推荐使用 `~/...`。
  - 打包前与 DMG 挂载后必须执行 `verify_portable_bundle` 双重校验，断言 Bundle 不包含源码根路径、用户目录路径或非系统未知依赖。
- **代码签名（Code Signing）**：
  - 编译阶段保持 `CODE_SIGNING_ALLOWED=NO`；
  - 最终代码签名使用固定自签名或正式证书，支持环境变量 `ASCEND_SIGN_IDENTITY`（默认值 `Ascend Local Signing`）；
  - 构建前使用 `security find-identity -p codesigning` 严格检查证书是否存在，若缺失则立即报错退出，严禁自动 fallback 到 ad-hoc；
  - 签名时递归处理内部所有 Mach-O 二进制，最终 App 使用 `Ascend/Support/Ascend.entitlements` 密封。
- 严禁将证书私钥、临时 DMG 产物（`dist/`）或 DerivedData 提交至 Git 仓库。

## 第三方依赖策略

- 允许在收益明确、范围合理且不会明显影响启动速度、常驻内存、采集性能、应用体积或隐私的情况下引入第三方依赖。
- 核心生命周期、本地数据、Keychain、登录启动、文件监听和菜单栏能力优先使用 Apple 系统框架；已有系统能力足以清晰实现的小功能不要仅为减少少量代码引入依赖。
- 引入前必须检查许可证、维护活跃度、macOS 15+ 与 Swift 6 严格并发兼容性、二进制体积、隐私行为和传递依赖；网络或遥测依赖不得读取 API Key、源码、笔记或学习数据。
- 依赖应通过 Swift Package Manager 和 `project.yml` 声明，锁定可复现版本，并在相关改动中说明用途与取舍；不要手工修改 Xcode 工程文件。
- 成熟算法或协议实现必须通过项目自有的 Service / Adapter 协议隔离；Domain Model、SwiftData Entity 与 UI 不得直接依赖第三方类型，也不得在业务代码各处散落第三方 `import`。
- 新依赖必须有实际调用场景和必要测试。发现依赖闲置、功能可被更轻量方案替代或造成明显性能回退时，应及时移除。
- Markdown 富文本渲染统一使用通过 SPM 锁定的 `Textual`。业务视图不得直接散落 `import Textual`，必须经 `LocalMarkdownDocumentView` 适配层使用；不要重新实现按行拆分、代码围栏、列表或表格解析器。

## 目录约定

- `Ascend/App`：应用入口、生命周期、AppDelegate 与全局菜单命令。
- `Ascend/Models`：SwiftData 实体、枚举与纯值模型（VersionedSchema 与 SchemaMigrationPlan）。
- `Ascend/Stores`：主线程应用状态机（AppState）和业务扩展（评分、AI 分析、采集、温故、验证、脉络、自动化与导入导出）。
- `Ascend/Services`：AI、采集、拓扑推演、推荐、评分、FSRS 记忆、Keychain、调度与系统服务。
- `Ascend/Views`：按功能拆分的 SwiftUI 页面和组件（大盘、星图、脉络、温故卡片、验证研习、菜单栏微驾舱、设置与长卷导出）。
- `Ascend/Support`：主题色系、日志、常量、entitlements 与通用扩展。
- `AscendTests`：纯逻辑和服务单元测试。项目不保留 UI 测试目标。
- `script/`：编译启动、便携式打包与发布自动化脚本。

## Swift 与 SwiftUI 约定

- 保持 Swift 6 严格并发检查通过；共享可观察状态使用 `@MainActor @Observable`。
- 网络、进程、扫描和调度服务使用 actor 隔离；跨隔离值应符合 `Sendable`。
- 视图保持小而明确，一个主要类型对应一个文件。
- macOS 主交互采用侧栏、工具栏、Settings 和 inspector，避免 iOS 式层层跳转。
- 优先使用语义颜色、系统控件、键盘操作和 VoiceOver 标签。
- 页面布局应适应窗口缩放；避免会迫使窗口超出屏幕的组合最小宽度。
- 玄青及“玄墨 / 清境”等现有视觉主题必须同时支持明亮、深色和跟随系统模式。
- 用户可见名称使用“知境录”；内部 target、module 和 bundle identifier 仍为 `Ascend` / `com.yang.Ascend`。
- 长技术名称和知识点标题应支持合理换行与完整阅读，不得依赖固定宽度造成无提示截断。

## Markdown 预览

- 所有 Markdown 预览入口统一使用 `MarkdownNotePreviewSheet` 与 `LocalMarkdownDocumentView`，知识详情和温故卡不得各自维护另一套渲染逻辑。
- 只有 `ReviewActivityLocator` 能解析为真实 `.md` 文件的 Activity 才显示笔记预览入口。代码提交、测评回执与挑战回执只能显示摘要，除非后续实现独立的代码 Diff 查看器。
- `Textual` 当前固定 revision 为 `01b51875a5406eefc95f52a058cb059e7bc94dc4`（0.5.0）。升级时必须重新验证 Swift 6 严格并发、macOS 15、依赖体积、许可证与启动性能。
- Markdown 图片默认只允许笔记所在目录内的本地文件；必须防止 `..` 和符号链接越界，并限制单图大小。远程 HTTP/HTTPS 图片不得自动请求，以免泄露阅读行为或引入不可控网络访问。

## 掌握度、境界阶梯与验证机制

- **五维掌握度权重**：接触 10%、理解 25%、实践 25%、记忆 20%、自主 20%。
- **自然学习与弱证据成长**：
  - 真实 Markdown 与 Git 采集的材料经 AI 分析后生成的 Artifact Evidence 立即推动掌握度与 XP 的自然弱成长；
  - 初窥（0-19分）与入门（20-39分）完全依赖日常学习即可自然进阶，不需要强制做题；
  - 即使知识点处于 Provisional 状态或归属未经人工确认，只要学习材料真实即可产生低阶段成长，绝不卡死在 0 XP / 0 境界。
- **高阶 Production Gates 守卫**：
  - **融会（60分）**：必须至少 1 次独立主动验证或生产实作认证（`hasDirectAssessment`）；
  - **化用（80分）**：必须至少 1 次可靠的独立无辅助生产实作（`hasProduction`）；
  - **通达（90-100分）**：必须至少 2 次不同情境（Distinct Context Hash）、间隔 $\ge 7$ 天的独立生产实作（`hasSeparatedProductions`）；
  - 选择题测评最高只能认证到融会，绝不能单独跨越至化用或通达。
- **隐藏缓存题包与用户自愿主动研习**：
  - AI 分析时顺带内嵌生成的 `embeddedAssessmentPackage` 直接持久化为隐藏缓存题包；
  - **Cached Assessment $\neq$ Pending Verification**：低境界知识点不进入 `pendingVerificationKnowledgeCount`，不发催办通知，不制造待办债务；
  - **0 AI 主动研习**：用户主动点击研习时优先命中缓存题包，直接产生 0 次 AI API 调用；
  - 按钮语义分层：初窥/入门显示「**主动研习**」（命中缓存提示「题目已备好 · 0 AI」，无缓存提示「生成研习题 · 1 次 AI」）；通晓且接近融会（$\ge 45$ 分）显示「**主动印证**」；
  - 答题按 BKT 步长逐题温和结算净增 XP，已完成题包退出缓存，防止重复刷分；
  - `retireRedundantPreparedAssessments` 保留学习中节点的缓存题包，仅废弃已达融会或刚测过处于 24h 冷却期内的多余题包。

## 温故与科学到期复习 (Flashcards & FSRS)

- **主动验证与温故彻底解耦**：
  - 主动验证负责判断“会不会 / 印证掌握”；温故负责“防止忘记”；
  - **温故 0 AI 调用**：打开温故、查看要点、提交复习反馈绝对不产生任何 AI API 请求。
- **快速回忆知识卡（Flashcard Deck）**：
  - 到期知识点以卡片式回忆流展示：默认显示知识点名称与回忆提示，点击「查看要点」后展开富文本核心总结；
  - **本地可信笔记预览**：支持在温故卡片中直接呼出已验证的关联笔记与代码片段弹窗，不加载未确认证据；
  - **四档 FSRS 评分**：遗忘 (Again)、困难 (Hard)、良好 (Good)、容易 (Easy)，直接更新稳定性、难度与下次复习计划；
  - 无历史复习数据时 retention 返回 `nil`，严禁虚假显示 100%。

## 应用生命周期与后台自动化

- 应用采用 Dock + 菜单栏双入口，使用常规 `.regular` 激活策略。主窗口使用单例 `Window`；窗口关闭后点击 Dock 图标或菜单栏入口都必须能重新创建并显示窗口。
- 关闭主窗口只关闭窗口，不得停止 Automation Tick、Markdown FSEvents、Remote Git polling、TriggerEngine 或其他后台任务；只有明确退出应用才终止进程。
- 自动采集开关和调度配置必须持久化。关闭自动采集时立即停止采集调度，启动应用时恢复用户上次状态。
- 自动采集只写入新的本地 `ActivityEvent`，不得因每次文件变化自动调用 AI。自动 AI 分析默认关闭，因为它会产生 Token 费用。
- Automation Tick 应轻量、可取消且防止重入；即使自动 AI 分析关闭，也要周期处理 ReviewPlan 到期、retention、通知和 Challenge 状态。
- TriggerEngine 和所有周期任务必须幂等，不得重复创建 ReviewPlan、重复完成 Challenge、重复奖励 XP 或重复发送同一到期通知。
- 对真实 AI 接口的自动化测试不得加入常规测试流程。只有用户明确要求时才执行，并默认只调用一次，后续验证使用 mock 或固定夹具。

## 系统通知、分类偏好与投递策略

- **明确权限申请**：权限申请必须调用 `AppState.requestNotificationAuthorization()`，底层直达 `UNUserNotificationCenter.requestAuthorization`。严禁将单纯的 `scheduleDailyDigest` 视作权限申请。
- **状态快照与守卫**：
  - 维护 `NotificationPermissionSnapshot`，实时读取授权状态（`authorizationStatus`）、横幅（`alertSetting`）、声音（`soundSetting`）和通知中心（`notificationCenterSetting`）；
  - 发送通知或测试通知前必须先检查快照：若为 `.notDetermined` 或 `.denied` 必须明确阻断并提示错误，严禁仅因 `center.add()` 未报错就显示成功。
- **分类设置与总控**：
  - 总开关（`digestNotificationsEnabled`）统揽所有自动通知；
  - 独立分类开关：每日研习战报（`digestDailyNotificationEnabled`）、温故提醒（`reviewDueNotificationEnabled`）；
  - 关闭总开关或分类开关仅停止 macOS Banner 投递，绝不影响 FSRS 记忆曲线、ReviewPlan 状态判定、Mastery、XP 或境界计算。
- **批量聚合与投递策略（Delivery Policy）**：
  - **禁止逐个 Banner 轰炸**：同一时间窗口到期的多个 ReviewPlan 必须聚合为单条通知（1个、2~3个、4个以上梯度文案）；
  - **战报吸收机制**：每日战报时间前后 15 分钟内的温故提醒由战报自动合并吸收，不单独弹窗；
  - **Cooldown 防打扰**：同类 Review Batch 维持 30 分钟静默冷却期；
  - **安全 Receipt 写入**：必须在通知通过 `DigestScheduler` 真正成功投递至系统后才写入 `AutomationReceipt`，发送失败严禁误标，确保后续可重试；
  - **稳定标识符**：统一使用 `ascend.daily-digest` 与 `ascend.review-batch`，避免堆积通知中心。
- **前台展示代理**：`AppDelegate` 必须实现 `UNUserNotificationCenterDelegate`，前台展示选项返回 `[.banner, .sound, .badge, .list]`。

## 采集、去重与 AI 分析

- `eventFingerprint` 标识一次具体采集事件；`contentChangeHash` 标识跨来源的规范化内容变化，两者不得混用。
- 同一内容可以保留 Local Markdown 与 Remote Git 两条来源记录，但 Evidence 的 canonical 去重必须至少结合 `contentChangeHash + knowledgeNodeID`，并覆盖评分、Challenge 和 ReviewPlan，防止重复计分或重复完成。
- Local Markdown 保留 FSEvents 与 reconciliation scan。Snapshot 只能在 `ActivityEvent` 成功持久化后推进；同内容 rename/move 只更新路径，不生成学习 Evidence。
- Markdown 标题解析必须忽略 fenced code 中的伪标题，并避免将 C/C++ 的 `#include` 等预处理指令识别为标题。
- Remote Git 数据源统一为 Remote Git Repository，可独立配置分析 Markdown 与代码。同步状态以实际 upstream tracking branch 为准，不得用落后的本地 `HEAD` 代替远端状态。
- Remote Git cursor 仅在整批 unseen commits 按顺序成功处理并持久化后推进；fetch、鉴权或持久化失败必须保留明确错误，不得静默漏采。
- 远端 Markdown 按文件和语义增量生成活动；代码默认一个 commit 生成一个主要实践活动，使用明确代码扩展名或文件名白名单，避免按文件制造重复活动。
- Markdown Evidence 侧重接触、解释、复习和概念修正；Code Evidence 侧重练习、项目和独立解决。格式化、改名、注释或版本号变化不得被判为高价值实践。
- AI 分批大小是全局请求上限：选中或待分析的 N 条活动按 `ceil(N / batchSize)` 分批，不得先按日期、来源或活动类型拆分而无故增加请求次数。
- 分析进度属于独立的持久会话状态，应一直显示到整个分析完成；普通成功、警告或错误消息不得覆盖或清除批次进度。
- AI 输出默认使用中文，必须包含完整结构体与 `possibleNextConcepts` / `edgeSuggestions`。解析失败可执行兼容降级，但失败结果不得写入评分。

## 知识脉络与星图交互 (Concept Lineage & Graph)

- **先导依赖语义（Prerequisite DAG）**：
  - 先导依赖具有严格方向性（$A \xrightarrow{\text{prerequisite}} B$ 表示 $A$ 是 $B$ 的前置知识）；
  - 必须进行成环检测（Cycle Detection），阻止形成闭环依赖；
  - 纳新审核与前置关系创建必须满足原子性预检（Preflight）：所有前置概念合法才一次性提交，否则保持 pending。
- **下一境推荐与受阻保护**：
  - 前置概念掌握度均达到门槛（融会 60 分）时解锁下一境推荐；
  - 前置概念若因遗忘衰减跌破门槛，下游概念逻辑上标记为受阻（Blocked），但绝不扣减历史最高境界或删除已学证据。
- **星图交互与渲染性能**：
  - 星图渲染必须采用批量拓扑预计算，避免每帧重复计算掌握度与 FSRS 状态；
  - 交互手势明确分工：单击仅高亮选中概念及其完整先导祖先（Ancestors）与后继衍生（Descendants）脉络，双击才打开详情与审核面板；
  - 节点拖拽手势必须做到 1:1 跟手连续位移更新，并在松手时持久化最终坐标。

## 日报、复习与挑战

- `DailyDigest` 按 `ActivityEvent.timestamp` 所属自然日归档，而不是按 AI 请求发生时间归档。
- 跨日期批次应按实际 Activity 关联拆分和聚合；同一天只有一份 Digest，采用 upsert。重新分析旧 Activity 时必须替换对应旧 summary，不得重复残留。
- Digest 的知识、XP、成长、遗忘、复习和 Challenge 状态优先由同一天真实结构化数据本地聚合；不得为了摘要重复发送完整源码或 diff。
- ReviewPlan 状态只允许由真实计划时间、用户取消和对应知识点的已验证 Evidence 推进；同一知识点已有有效计划时不得重复创建。
- 多知识点 Challenge 必须满足全部目标知识点的覆盖要求后才能完成；单个知识点的一条 Evidence 不得完成整个多知识点 Challenge。
- Challenge 有两条完成路径：选择题属于低奖励的知识验证，生产实作属于完整奖励的项目证据；前者不得伪装成生产实作，也不得解锁仅限 Production 的高阶掌握。
- 用户勾选“独立完成”等声明只作为 AI 核验上下文，绝不能直接创建已验证 Evidence 或自动完成 Challenge。Git 提交或本地文件必须经过挑战量规的独立 AI 复核；低置信度、失败、取消或格式错误均为零写入。
- 当前挑战实作仅接受最近三天的候选来源。聚合 Git 提交允许用户明确选择具体代码文件；审计片段须按挑战相关性提取、限制长度、脱敏，完整源码不得持久化或发送。
- AI 核验失败原因必须保留，并在同一挑战下次提交时随请求带回，帮助比较修正是否覆盖缺口。用户可取消进行中的备题/核验，也可放弃挑战；取消和放弃不得产生部分 Evidence、XP 或删除既有学习记录。
- TaxonomySuggestion 与 EvidenceRecord 必须保持明确的一对一关联，审核操作只能影响 suggestion 指向的 evidence。

## 菜单栏与视觉规范

- `MenuBarExtra` 是紧凑的学习驾驶舱，不是主窗口缩小版；保持 Header、今日所学、Stats、待温故、主修、Source Health、Quick Actions 的既有信息结构。
- Popover 高度必须随实际可见内容实时收缩，并设置合理最大高度后仅滚动中部内容；不得因隐藏或删除内容留下大面积空白，也不得通过反复调整窗口造成闪烁。
- 打开主窗口后应关闭菜单栏 Popover。顶部保留高频操作；模型切换等低频设置放入更多菜单，避免重复入口。
- 临时状态消息可自动消失；批次分析等进行中状态必须常驻至任务完成，并与临时消息分层展示。
- 菜单栏采用“玄墨 / 清境”视觉：墨为结构、青玉为正常与成长、暖金为境界与主要操作、朱砂仅用于警告。不要重新引入蓝色主强调或大面积卡片。
- 仅“知境录、今日所学、待温故、主修”等品牌标题使用 Serif；技术名、数字、XP、状态、时间和领域名使用系统字体。
- 明亮与深色模式应分别调校，不得简单反相；装饰保持克制，只允许 Header 使用极淡山形等单一品牌元素。

## 数据与隐私

- 文件扫描仅限用户主动选择的目录。
- Git 未提交改动必须逐仓库授权。
- 默认不持久化完整源码，只保存来源定位、哈希、摘要和有限审计片段。
- 日志中不得输出 API Key、Authorization Header、完整源码或敏感文件内容。
- JSON 导入导出不得包含 API Key。
- 删除数据或迁移模型时，先确认不会误删用户配置；迁移应可重复执行并保持幂等。
- SwiftData 模型变化应维护 VersionedSchema 与 SchemaMigrationPlan。即使当前是单用户，也不得把删除数据库作为默认升级方案；只有用户明确授权清空本地学习数据时才能重建。

## 修改前后的检查

1. 阅读与任务最接近的模型、服务和视图，不要复制已有逻辑。
2. 保留用户已有数据和工作区中的无关改动。
3. 修改评分、遗忘、领域、审核关联、去重、采集 cursor、调度、日报、复习、Challenge、迁移、先导脉络或 AI 协议时必须增加或更新单元测试。
4. 提交前运行 XcodeGen、完整单元测试和 `build_and_run.sh --verify`。
5. 发布前运行 `./script/package_release.sh` 确保便携性检测与固定证书签名通过。
6. 确认仓库中没有 API Key、签名凭据、DerivedData、`dist/` 临时文件、日志或临时截图。
7. 不要随便使用 Computer Use 操作或验证应用界面；优先让用户自行运行并验证 UI。只有用户明确要求代为操作，或无法通过代码、单元测试、构建与日志完成验证且已征得用户同意时，才使用 Computer Use。
