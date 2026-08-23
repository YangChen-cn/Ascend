import Foundation
import SwiftData

enum PersistenceController {
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(versionedSchema: AscendSchemaV3.self)
        let configuration = ModelConfiguration(
            "Ascend",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: AscendMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            fatalError("Unable to create Ascend data store: \(error.localizedDescription)")
        }
    }
}
