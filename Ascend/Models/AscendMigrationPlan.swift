import SwiftData

enum AscendMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AscendSchemaV6.self, AscendSchemaV8.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: AscendSchemaV6.self, toVersion: AscendSchemaV8.self)
        ]
    }
}
