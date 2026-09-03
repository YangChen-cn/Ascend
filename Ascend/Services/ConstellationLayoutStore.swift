import Foundation

@MainActor
struct ConstellationLayoutStore {
    private static let storageKey = "knowledgeGraph.constellationPositions.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func positions(for domainName: String, validNodeIDs: Set<UUID>) -> [UUID: CGPoint] {
        let records = load()[domainName] ?? [:]
        return records.reduce(into: [:]) { result, entry in
            guard let id = UUID(uuidString: entry.key),
                  validNodeIDs.contains(id),
                  entry.value.x.isFinite,
                  entry.value.y.isFinite else { return }
            result[id] = CGPoint(x: entry.value.x, y: entry.value.y)
        }
    }

    func save(position: CGPoint, nodeID: UUID, domainName: String) {
        guard position.x.isFinite, position.y.isFinite else { return }
        var records = load()
        records[domainName, default: [:]][nodeID.uuidString] = PositionRecord(x: position.x, y: position.y)
        persist(records)
    }

    func reset(domainName: String) {
        var records = load()
        records.removeValue(forKey: domainName)
        persist(records)
    }

    private func load() -> [String: [String: PositionRecord]] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let records = try? JSONDecoder().decode([String: [String: PositionRecord]].self, from: data) else {
            return [:]
        }
        return records
    }

    private func persist(_ records: [String: [String: PositionRecord]]) {
        guard !records.isEmpty else {
            defaults.removeObject(forKey: Self.storageKey)
            return
        }
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

private struct PositionRecord: Codable {
    let x: Double
    let y: Double
}
