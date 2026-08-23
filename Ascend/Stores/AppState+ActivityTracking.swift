import Foundation
import SwiftData

extension AppState {
    func loadActivityFeed(
        filter: ActivityFeedFilter,
        searchText: String,
        limit: Int
    ) {
        do {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            var descriptor: FetchDescriptor<ActivityEvent>
            switch (filter, query.isEmpty) {
            case (.all, true):
                descriptor = FetchDescriptor(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
            case (.pending, true):
                descriptor = FetchDescriptor(
                    predicate: #Predicate { !$0.isProcessed },
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
            case (.processed, true):
                descriptor = FetchDescriptor(
                    predicate: #Predicate { $0.isProcessed },
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
            case (.all, false):
                descriptor = FetchDescriptor(
                    predicate: #Predicate {
                        $0.title.localizedStandardContains(query) ||
                            $0.summary.localizedStandardContains(query) ||
                            $0.sourceLocator.localizedStandardContains(query)
                    },
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
            case (.pending, false):
                descriptor = FetchDescriptor(
                    predicate: #Predicate {
                        !$0.isProcessed &&
                            ($0.title.localizedStandardContains(query) ||
                                $0.summary.localizedStandardContains(query) ||
                                $0.sourceLocator.localizedStandardContains(query))
                    },
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
            case (.processed, false):
                descriptor = FetchDescriptor(
                    predicate: #Predicate {
                        $0.isProcessed &&
                            ($0.title.localizedStandardContains(query) ||
                                $0.summary.localizedStandardContains(query) ||
                                $0.sourceLocator.localizedStandardContains(query))
                    },
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
            }
            activityFeedTotalCount = try modelContext.fetchCount(descriptor)
            descriptor.fetchLimit = max(1, limit)
            activityFeedEvents = try modelContext.fetch(descriptor)
        } catch {
            statusMessage = "读取资料流失败：\(error.localizedDescription)"
        }
    }

    func addSource(
        name: String,
        kind: SourceKind,
        path: String,
        analyzeMarkdown: Bool = true,
        analyzeCode: Bool = true,
        remoteURLString: String? = nil
    ) throws {
        guard !sources.contains(where: { $0.path == path && $0.kind == kind }) else {
            throw AppStateError.duplicateSource
        }
        let source = SourceConfiguration(
            name: name,
            kind: kind,
            path: path,
            analyzeMarkdown: analyzeMarkdown,
            analyzeCode: analyzeCode,
            remoteURLString: remoteURLString
        )
        modelContext.insert(source)
        try modelContext.save()
        sources.append(source)
        sources.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        syncLocalMarkdownWatchers()
    }

    func deleteSource(_ source: SourceConfiguration) throws {
        modelContext.delete(source)
        try modelContext.save()
        sources.removeAll { $0.id == source.id }
        localMarkdownWatchers[source.id]?.stop()
        localMarkdownWatchers.removeValue(forKey: source.id)
        Task { [weak self] in
            await self?.markdownSnapshotStore.clearSnapshots(for: source.id)
        }
        syncLocalMarkdownWatchers()
    }

    func scanSources() async throws {
        guard !isScanningSources else { return }
        isScanningSources = true
        defer { isScanningSources = false }
        let existingEvents = (try? modelContext.fetch(FetchDescriptor<ActivityEvent>())) ?? []
        var insertedFingerprints = Set(existingEvents.map(\.fingerprint))
        var insertedEvents: [ActivityEvent] = []
        var failedSources: [String] = []
        let excludedLocations = Set(activityTrackingExclusions.map(trackingKey))

        for source in sources where source.isEnabled && source.kind != .manual {
            let descriptor = SourceDescriptor(
                id: source.id,
                name: source.name,
                kind: source.kind,
                path: source.path,
                analyzeWorkingTree: source.analyzeWorkingTree,
                analyzeMarkdown: source.analyzeMarkdown,
                analyzeCode: source.analyzeCode,
                authorFilter: source.authorFilter,
                ignorePatterns: source.ignorePatterns,
                lastScannedAt: source.lastScannedAt,
                lastCursor: source.lastCursor
            )

            do {
                let result: ActivityScanResult
                switch source.kind {
                case .gitRepository:
                    result = try await gitConnector.scan(source: descriptor)
                case .markdownDirectory:
                    result = try await markdownConnector.scan(source: descriptor)
                case .remoteGitRepository, .remoteGitMarkdown:
                    result = try await remoteGitRepositoryConnector.scan(source: descriptor)
                case .manual:
                    result = ActivityScanResult(activities: [])
                }

                var pendingEvents: [ActivityEvent] = []
                for item in result.activities {
                    guard !insertedFingerprints.contains(item.fingerprint),
                          !excludedLocations.contains(trackingKey(sourceID: item.sourceID, sourceLocator: item.sourceLocator)) else {
                        continue
                    }
                    let event = ActivityEvent(
                        id: item.id,
                        sourceID: item.sourceID,
                        sourceKind: item.sourceKind,
                        timestamp: item.timestamp,
                        fingerprint: item.fingerprint,
                        contentChangeHash: item.contentChangeHash,
                        title: item.title,
                        sourceLocator: item.sourceLocator,
                        summary: item.summary,
                        excerpt: item.excerpt
                    )
                    modelContext.insert(event)
                    pendingEvents.append(event)
                    insertedFingerprints.insert(item.fingerprint)
                }

                source.lastScannedAt = result.scannedAt
                source.lastSyncError = nil
                if source.kind == .gitRepository || source.kind == .remoteGitRepository || source.kind == .remoteGitMarkdown {
                    source.lastCursor = result.nextCursor
                }
                if source.kind == .remoteGitRepository || source.kind == .remoteGitMarkdown {
                    source.lastUpstreamReference = result.upstreamReference
                    if let remoteURL = result.remoteURLString, !remoteURL.isEmpty {
                        source.remoteURLString = remoteURL
                    }
                }
                try modelContext.save()
                if source.kind == .markdownDirectory {
                    await markdownConnector.commitSnapshotMutations(result.markdownSnapshotMutations)
                }
                insertedEvents.append(contentsOf: pendingEvents)
            } catch {
                modelContext.rollback()
                source.lastSyncError = error.localizedDescription
                try? modelContext.save()
                failedSources.append("\(source.name)：\(error.localizedDescription)")
                AppLogger.collector.error("Source sync failed for \(source.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        activityEvents = Array((insertedEvents + activityEvents)
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(200))
        refreshActivityCounts()
        AppLogger.collector.info("Source scan completed with \(insertedEvents.count) new activities")
        if !failedSources.isEmpty {
            throw AppStateError.sourceSyncFailed(failedSources.joined(separator: "；"))
        }
    }

    func syncLocalMarkdownWatchers() {
        guard isCollecting else {
            for (_, watcher) in localMarkdownWatchers {
                watcher.stop()
            }
            localMarkdownWatchers.removeAll()
            return
        }

        let activeMarkdownSources = sources.filter { $0.isEnabled && $0.kind == .markdownDirectory }
        let activeIDs = Set(activeMarkdownSources.map(\.id))

        // 停止并移除已禁用或删除的 watcher
        for (id, watcher) in localMarkdownWatchers where !activeIDs.contains(id) {
            watcher.stop()
            localMarkdownWatchers.removeValue(forKey: id)
        }

        // 为新增或需更新的来源启动 watcher
        for source in activeMarkdownSources {
            if let existing = localMarkdownWatchers[source.id] {
                if existing.rootPath != source.path || existing.ignorePatterns != source.ignorePatterns {
                    existing.stop()
                    localMarkdownWatchers.removeValue(forKey: source.id)
                } else {
                    continue
                }
            }

            let watcher = LocalMarkdownEventSource(
                sourceID: source.id,
                rootPath: source.path,
                ignorePatterns: source.ignorePatterns
            ) { [weak self] sourceID, changedPaths in
                Task { @MainActor [weak self] in
                    await self?.handleMarkdownFilesChanged(sourceID: sourceID, paths: changedPaths)
                }
            }
            localMarkdownWatchers[source.id] = watcher
            watcher.start()
        }
    }

    func handleMarkdownFilesChanged(sourceID: UUID, paths: [String]) async {
        await markdownDebouncer.enqueue(sourceID: sourceID, paths: paths) { [weak self] srcID, flushedPaths in
            await self?.processDebouncedMarkdownFiles(sourceID: srcID, paths: flushedPaths)
        }
    }

    func processDebouncedMarkdownFiles(sourceID: UUID, paths: [String]) async {
        guard let source = sources.first(where: { $0.id == sourceID && $0.isEnabled }) else { return }
        let descriptor = SourceDescriptor(
            id: source.id,
            name: source.name,
            kind: source.kind,
            path: source.path,
            analyzeWorkingTree: source.analyzeWorkingTree,
            analyzeMarkdown: source.analyzeMarkdown,
            analyzeCode: source.analyzeCode,
            authorFilter: source.authorFilter,
            ignorePatterns: source.ignorePatterns,
            lastScannedAt: source.lastScannedAt,
            lastCursor: source.lastCursor
        )

        let result = await markdownConnector.processChangedFiles(source: descriptor, filePaths: paths)
        guard !result.activities.isEmpty || !result.markdownSnapshotMutations.isEmpty else { return }

        let existingEvents = (try? modelContext.fetch(FetchDescriptor<ActivityEvent>())) ?? []
        var knownFingerprints = Set(existingEvents.map(\.fingerprint))
        let excludedLocations = Set(activityTrackingExclusions.map(trackingKey))
        var insertedEvents: [ActivityEvent] = []

        for item in result.activities {
            guard !knownFingerprints.contains(item.fingerprint),
                  !excludedLocations.contains(trackingKey(sourceID: item.sourceID, sourceLocator: item.sourceLocator)) else {
                continue
            }
            let event = ActivityEvent(
                id: item.id,
                sourceID: item.sourceID,
                sourceKind: item.sourceKind,
                timestamp: item.timestamp,
                fingerprint: item.fingerprint,
                contentChangeHash: item.contentChangeHash,
                title: item.title,
                sourceLocator: item.sourceLocator,
                summary: item.summary,
                excerpt: item.excerpt
            )
            modelContext.insert(event)
            insertedEvents.append(event)
            knownFingerprints.insert(item.fingerprint)
        }

        do {
            if !insertedEvents.isEmpty {
                try modelContext.save()
            }
            await markdownConnector.commitSnapshotMutations(result.markdownSnapshotMutations)
            if !insertedEvents.isEmpty {
                activityEvents = Array((insertedEvents + activityEvents)
                    .sorted { $0.timestamp > $1.timestamp }
                    .prefix(200))
                refreshActivityCounts()
                AppLogger.collector.info("FSEvents processed \(insertedEvents.count) new markdown activities for \(source.name, privacy: .public)")
            }
        } catch {
            modelContext.rollback()
            statusMessage = "Markdown 活动保存失败，快照未推进：\(error.localizedDescription)"
            AppLogger.collector.error("Markdown activity persistence failed; snapshot was not advanced: \(error.localizedDescription, privacy: .public)")
        }
    }

    func stopTracking(activityIDs: Set<UUID>) throws {
        guard !activityIDs.isEmpty else { return }
        let selectedActivities = try fetchActivities(ids: activityIDs)
        guard !selectedActivities.isEmpty else { return }

        var targetLocations = Set<String>()
        for selected in selectedActivities {
            targetLocations.insert(trackingKey(sourceID: selected.sourceID, sourceLocator: selected.sourceLocator))
        }

        let allEvents = try modelContext.fetch(FetchDescriptor<ActivityEvent>())
        let activitiesToDelete = allEvents.filter {
            targetLocations.contains(trackingKey(sourceID: $0.sourceID, sourceLocator: $0.sourceLocator))
        }

        removeExistingAnalysis(for: Set(activitiesToDelete.map(\.id)))
        for activity in selectedActivities {
            createTrackingExclusion(for: activity, reason: "用户从资料流删除跟踪")
        }
        for activity in activitiesToDelete {
            modelContext.delete(activity)
        }
        try modelContext.save()
        load()
        statusMessage = "已停止跟踪 \(selectedActivities.count) 个条目并删除 \(activitiesToDelete.count) 条活动；后续扫描不会再次收录"
    }

    func createTrackingExclusion(for activity: ActivityEvent, reason: String) {
        let key = trackingKey(sourceID: activity.sourceID, sourceLocator: activity.sourceLocator)
        guard !activityTrackingExclusions.contains(where: { trackingKey($0) == key }) else { return }
        let exclusion = ActivityTrackingExclusion(
            sourceID: activity.sourceID,
            sourceKind: SourceKind(rawValue: activity.sourceKindRawValue) ?? .manual,
            sourceLocator: activity.sourceLocator,
            reason: reason
        )
        modelContext.insert(exclusion)
        activityTrackingExclusions.insert(exclusion, at: 0)
    }

    func trackingKey(_ exclusion: ActivityTrackingExclusion) -> String {
        trackingKey(sourceID: exclusion.sourceID, sourceLocator: exclusion.sourceLocator)
    }

    func trackingKey(sourceID: UUID, sourceLocator: String) -> String {
        sourceID.uuidString + "\u{001F}" + sourceLocator
    }
}
