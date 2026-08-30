import SwiftData

enum AscendSchemaV10: VersionedSchema {
    static let versionIdentifier = Schema.Version(10, 0, 0)

    static var models: [any PersistentModel.Type] {
        AscendSchemaV9.models + [
            DailyTask.self,
            DailyTaskLog.self,
            FocusSession.self
        ]
    }
}
