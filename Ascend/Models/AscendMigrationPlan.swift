import SwiftData

enum AscendMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AscendSchemaV1.self, AscendSchemaV2.self, AscendSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: AscendSchemaV1.self, toVersion: AscendSchemaV2.self),
            .lightweight(fromVersion: AscendSchemaV2.self, toVersion: AscendSchemaV3.self)
        ]
    }
}
