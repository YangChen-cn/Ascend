# AGENTS.md

## 项目概览

知境录是一个面向 macOS 15+ 的本地优先个人学习监控与成长系统。应用使用 Swift 6、SwiftUI、SwiftData、Keychain 和 Swift Concurrency，不引入第三方运行时框架。

产品原则：

- 只根据可追溯的真实学习证据更新掌握度和 XP。
- 知识点维护接触、理解、实践、记忆、自主五维评分。
- 每个领域独立计算掌握度、XP 与境界，领域之间不得混算。
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
- 玄青主题必须同时支持明亮、深色和跟随系统模式。
- 用户可见名称使用“知境录”；内部 target、module 和 bundle identifier 仍为 `Ascend` / `com.yang.Ascend`。

## 数据与隐私

- 文件扫描仅限用户主动选择的目录。
- Git 未提交改动必须逐仓库授权。
- 默认不持久化完整源码，只保存来源定位、哈希、摘要和有限审计片段。
- 日志中不得输出 API Key、Authorization Header、完整源码或敏感文件内容。
- JSON 导入导出不得包含 API Key。
- 删除数据或迁移模型时，先确认不会误删用户配置；迁移应可重复执行并保持幂等。

## 评分与领域规则

- 综合掌握度权重固定为：接触 10%、理解 25%、实践 25%、记忆 20%、自主 20%。
- XP 只来自已验证证据造成的正向综合增量，历史 XP 不回退。
- 遗忘只动态影响记忆维度，不修改历史证据和既得 XP。
- 知识点境界：初窥、入门、通晓、融会、化用、通达。
- 领域境界必须同时满足该领域的掌握度与 XP 门槛。
- 新知识点、跨领域关系和低置信度匹配应进入确认流程，不能直接计分。

## 修改前后的检查

1. 阅读与任务最接近的模型、服务和视图，不要复制已有逻辑。
2. 保留用户已有数据和工作区中的无关改动。
3. 修改评分、遗忘、领域或 AI 协议时必须增加或更新单元测试。
4. 提交前运行 XcodeGen、完整单元测试和 `build_and_run.sh --verify`。
5. 确认仓库中没有 API Key、签名凭据、DerivedData、日志或临时截图。
