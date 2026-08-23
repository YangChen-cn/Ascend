# AGENTS.md

## 项目概览

知境录是一个面向 macOS 15+ 的本地优先个人学习监控与成长系统。应用使用 Swift 6、SwiftUI、SwiftData、Keychain 和 Swift Concurrency。

产品原则：

- 只根据可追溯的真实学习证据更新掌握度和 XP。
- 知识点维护接触、理解、实践、记忆、自主五维评分。
- 每个领域独立计算掌握度、XP 与境界，领域之间不得混算。
- 历史掌握与当前状态是两个概念：遗忘只影响当前记忆保持和即时状态，不得回退历史 XP、最高境界或删除历史证据。
- Challenge XP 与 Knowledge XP 必须分离；复习、挑战和境界变化只能由真实、已验证且可追溯的 Evidence 触发。
- API Key 只能保存在 Keychain，不得进入 SwiftData、日志、测试夹具或导出文件。
- 默认数据库必须为空，不得加入演示知识、虚构证据、默认 XP 或默认境界。
- AI 请求失败、格式错误或证据置信度不足时不得改变评分。

## 工程与运行

- Xcode 工程由根目录的 `project.yml` 使用 XcodeGen 生成。
- 修改目标、构建设置或资源配置后运行：`xcodegen generate`。
- 构建并启动：`./script/build_and_run.sh`。
- 仅验证构建和进程：`./script/build_and_run.sh --verify`。
- 单元测试：

  ```bash
  xcodebuild test \
    -project Ascend.xcodeproj \
    -scheme Ascend \
    -destination 'platform=macOS' \
    -derivedDataPath .build/DerivedData
  ```

- 不要手工编辑 `Ascend.xcodeproj/project.pbxproj`；应修改 `project.yml` 后重新生成。

## 第三方依赖策略

- 允许在收益明确、范围合理且不会明显影响启动速度、常驻内存、采集性能、应用体积或隐私的情况下引入第三方依赖。
- 核心生命周期、本地数据、Keychain、登录启动、文件监听和菜单栏能力优先使用 Apple 系统框架；已有系统能力足以清晰实现的小功能不要仅为减少少量代码引入依赖。
- 引入前必须检查许可证、维护活跃度、macOS 15+ 与 Swift 6 严格并发兼容性、二进制体积、隐私行为和传递依赖；网络或遥测依赖不得读取 API Key、源码、笔记或学习数据。
- 依赖应通过 Swift Package Manager 和 `project.yml` 声明，锁定可复现版本，并在相关改动中说明用途与取舍；不要手工修改 Xcode 工程文件。
- 成熟算法或协议实现必须通过项目自有的 Service / Adapter 协议隔离；Domain Model、SwiftData Entity 与 UI 不得直接依赖第三方类型，也不得在业务代码各处散落第三方 `import`。
- 新依赖必须有实际调用场景和必要测试。发现依赖闲置、功能可被更轻量方案替代或造成明显性能回退时，应及时移除。

## 目录约定

- `Ascend/App`：应用入口、场景和命令。
- `Ascend/Models`：SwiftData 实体与纯值模型。
- `Ascend/Stores`：主线程应用状态和持久化协调。
- `Ascend/Services`：AI、采集、评分、Keychain、调度与系统服务。
- `Ascend/Views`：按功能拆分的 SwiftUI 页面和组件。
- `Ascend/Support`：主题、日志、常量与通用扩展。
- `AscendTests`：纯逻辑和服务单元测试。项目不保留 UI 测试目标。

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

## 应用生命周期与后台自动化

- 应用采用菜单栏常驻 Agent 模式：冷启动不显示 Dock 图标且不主动打开主窗口，主窗口使用单例 `Window` 按需打开。
- 关闭主窗口只关闭窗口，不得停止 Automation Tick、Markdown FSEvents、Remote Git polling、TriggerEngine 或其他后台任务；只有明确退出应用才终止进程。
- 自动采集开关和调度配置必须持久化。关闭自动采集时立即停止采集调度，启动应用时恢复用户上次状态。
- 自动采集只写入新的本地 `ActivityEvent`，不得因每次文件变化自动调用 AI。自动 AI 分析默认关闭，因为它会产生 Token 费用。
- Automation Tick 应轻量、可取消且防止重入；即使自动 AI 分析关闭，也要周期处理 ReviewPlan 到期、retention、通知和 Challenge 状态。
- TriggerEngine 和所有周期任务必须幂等，不得重复创建 ReviewPlan、重复完成 Challenge、重复奖励 XP 或重复发送同一到期通知。
- 对真实 AI 接口的自动化测试不得加入常规测试流程。只有用户明确要求时才执行，并默认只调用一次，后续验证使用 mock 或固定夹具。

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
- AI 输出默认使用中文，并必须包含 `sessionSummary` 等协议要求的完整结构字段。解析失败可执行兼容降级和有限修复重试，但失败结果不得写入评分。

## 日报、复习与挑战

- `DailyDigest` 按 `ActivityEvent.timestamp` 所属自然日归档，而不是按 AI 请求发生时间归档。
- 跨日期批次应按实际 Activity 关联拆分和聚合；同一天只有一份 Digest，采用 upsert。重新分析旧 Activity 时必须替换对应旧 summary，不得重复残留。
- Digest 的知识、XP、成长、遗忘、复习和 Challenge 状态优先由同一天真实结构化数据本地聚合；不得为了摘要重复发送完整源码或 diff。
- ReviewPlan 状态只允许由真实计划时间、用户取消和对应知识点的已验证 Evidence 推进；同一知识点已有有效计划时不得重复创建。
- 多知识点 Challenge 必须满足全部目标知识点的覆盖要求后才能完成；单个知识点的一条 Evidence 不得完成整个多知识点 Challenge。
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

## 评分与领域规则

- 综合掌握度权重固定为：接触 10%、理解 25%、实践 25%、记忆 20%、自主 20%。
- XP 只来自已验证证据造成的正向综合增量，历史 XP 不回退。
- 遗忘只动态影响记忆维度，不修改历史证据和既得 XP。
- FSRS 只负责记忆维度、可提取率与复习时间；接触、理解、实践、自主以及历史 XP 继续遵循知境录自己的证据与评分规则。
- 知识点境界：初窥、入门、通晓、融会、化用、通达。
- 领域境界必须同时满足该领域的掌握度与 XP 门槛。
- 新知识点、跨领域关系和低置信度匹配应进入确认流程，不能直接计分。

## 修改前后的检查

1. 阅读与任务最接近的模型、服务和视图，不要复制已有逻辑。
2. 保留用户已有数据和工作区中的无关改动。
3. 修改评分、遗忘、领域、审核关联、去重、采集 cursor、调度、日报、复习、Challenge、迁移或 AI 协议时必须增加或更新单元测试。
4. 提交前运行 XcodeGen、完整单元测试和 `build_and_run.sh --verify`。
5. 确认仓库中没有 API Key、签名凭据、DerivedData、日志或临时截图。
6. 不要随便使用 Computer Use 操作或验证应用界面；优先让用户自行运行并验证 UI。只有用户明确要求代为操作，或无法通过代码、单元测试、构建与日志完成验证且已征得用户同意时，才使用 Computer Use。
