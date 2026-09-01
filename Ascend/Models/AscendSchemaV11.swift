import SwiftData

enum AscendSchemaV11: VersionedSchema {
    static let versionIdentifier = Schema.Version(11, 0, 0)

    static var models: [any PersistentModel.Type] {
        AscendSchemaV10.models
    }
}
