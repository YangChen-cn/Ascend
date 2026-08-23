import CoreServices
import Foundation

final class LocalMarkdownEventSource: @unchecked Sendable {
    typealias EventHandler = @Sendable (UUID, [String]) -> Void

    let sourceID: UUID
    let rootPath: String
    let ignorePatterns: [String]
    private let eventHandler: EventHandler

    private var eventStream: FSEventStreamRef?
    private let dispatchQueue: DispatchQueue
    private var isRunning = false
    private let lock = NSLock()

    init(
        sourceID: UUID,
        rootPath: String,
        ignorePatterns: [String],
        eventHandler: @escaping EventHandler
    ) {
        self.sourceID = sourceID
        self.rootPath = rootPath
        self.ignorePatterns = ignorePatterns
        self.eventHandler = eventHandler
        self.dispatchQueue = DispatchQueue(label: "com.yang.Ascend.fsevents.\(sourceID.uuidString)", qos: .utility)
    }

    deinit {
        stop()
    }

    func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !isRunning else { return }

        guard FileManager.default.fileExists(atPath: rootPath) else {
            AppLogger.collector.warning("FSEvents root path does not exist: \(self.rootPath, privacy: .public)")
            return
        }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let pathsToWatch = [rootPath] as CFArray
        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagNoDefer
        )

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { (_, clientCallBackInfo, numEvents, eventPaths, eventFlags, _) in
                guard let info = clientCallBackInfo else { return }
                let watcher = Unmanaged<LocalMarkdownEventSource>.fromOpaque(info).takeUnretainedValue()
                guard let rawPaths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }
                watcher.handleRawEvents(paths: rawPaths, count: numEvents, flags: eventFlags)
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            flags
        ) else {
            AppLogger.collector.error("Failed to create FSEventStream for \(self.rootPath, privacy: .public)")
            return
        }

        self.eventStream = stream
        FSEventStreamSetDispatchQueue(stream, dispatchQueue)
        if FSEventStreamStart(stream) {
            isRunning = true
            AppLogger.collector.info("FSEvents watcher started for source \(self.sourceID.uuidString, privacy: .public) at \(self.rootPath, privacy: .public)")
        } else {
            AppLogger.collector.error("Failed to start FSEventStream for \(self.rootPath, privacy: .public)")
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.eventStream = nil
        }
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard isRunning, let stream = eventStream else { return }

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.eventStream = nil
        self.isRunning = false
        AppLogger.collector.info("FSEvents watcher stopped for source \(self.sourceID.uuidString, privacy: .public)")
    }

    // MARK: - 事件处理与过滤

    private func handleRawEvents(paths: [String], count: Int, flags: UnsafePointer<FSEventStreamEventFlags>) {
        var validChangedPaths: [String] = []

        for i in 0..<count {
            let path = paths[i]
            let flag = flags[i]

            // 过滤非 Markdown 文件
            guard path.lowercased().hasSuffix(".md") else { continue }

            // 过滤忽略模式和隐藏文件/目录
            if isIgnored(path) { continue }

            // 验证是否是有效文件变动标志
            let isItemChange = (flag & UInt32(kFSEventStreamEventFlagItemIsFile)) != 0 ||
                               (flag & UInt32(kFSEventStreamEventFlagItemModified)) != 0 ||
                               (flag & UInt32(kFSEventStreamEventFlagItemCreated)) != 0 ||
                               (flag & UInt32(kFSEventStreamEventFlagItemRenamed)) != 0 ||
                               (flag & UInt32(kFSEventStreamEventFlagItemRemoved)) != 0

            if isItemChange || path.hasSuffix(".md") {
                validChangedPaths.append(path)
            }
        }

        if !validChangedPaths.isEmpty {
            eventHandler(sourceID, validChangedPaths)
        }
    }

    private func isIgnored(_ path: String) -> Bool {
        let relative = path.replacingOccurrences(of: rootPath, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let components = relative.split(separator: "/")

        // 过滤隐藏文件或隐藏目录 (如 .git, .obsidian, .trash)
        for comp in components {
            if comp.hasPrefix(".") { return true }
        }

        for pattern in ignorePatterns where !pattern.isEmpty {
            if relative.localizedStandardContains(pattern) {
                return true
            }
        }

        return false
    }
}
