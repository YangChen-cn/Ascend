import SwiftData

enum AscendMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AscendSchemaV6.self, AscendSchemaV8.self, AscendSchemaV9.self, AscendSchemaV10.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: AscendSchemaV6.self, toVersion: AscendSchemaV8.self),
            .lightweight(fromVersion: AscendSchemaV8.self, toVersion: AscendSchemaV9.self),
            .lightweight(fromVersion: AscendSchemaV9.self, toVersion: AscendSchemaV10.self)
        ]
    }
}
