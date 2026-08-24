import SwiftData

enum AscendSchemaV9: VersionedSchema {
    static let versionIdentifier = Schema.Version(9, 0, 0)

    static var models: [any PersistentModel.Type] {
        AscendSchemaV8.models + [
            AssessmentSession.self,
            AssessmentItem.self,
            AssessmentResponse.self,
            MasteryObservation.self,
            MasteryEstimate.self,
            PerformanceReceipt.self
        ]
    }
}
