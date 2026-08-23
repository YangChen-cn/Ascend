import SwiftData

enum AscendSchemaV7: VersionedSchema {
    static let versionIdentifier = Schema.Version(7, 0, 0)

    static var models: [any PersistentModel.Type] {
        AscendSchemaV6.models + [
            MemoryState.self,
            MemoryReviewEvent.self
        ]
    }
}
