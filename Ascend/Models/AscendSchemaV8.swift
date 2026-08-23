import SwiftData

enum AscendSchemaV8: VersionedSchema {
    static let versionIdentifier = Schema.Version(8, 0, 0)

    static var models: [any PersistentModel.Type] {
        AscendSchemaV7.models
    }
}
