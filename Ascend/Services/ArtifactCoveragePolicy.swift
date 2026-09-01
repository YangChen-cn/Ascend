import Foundation

/// 将学习产物中的「语义覆盖」转换为保守的低阶资料基础。
/// 这不是测评结果：不会建立记忆，也不会单凭资料认证融会及以上。
enum ArtifactCoveragePolicy: Sendable {
    static let modelVersion = 1

    static func normalized(_ value: Double?, for kind: EvidenceKind) -> Double {
        (value ?? legacyCoverage(for: kind)).clamped(to: 0.15...0.85)
    }

    static func legacyCoverage(for kind: EvidenceKind) -> Double {
        switch kind {
        case .exposure: 0.25
        case .explanation: 0.72
        case .exercise: 0.60
        case .project: 0.70
        case .review: 0.45
        case .independentSolve: 0.70
        }
    }

    /// 各类资料在「系统覆盖」时能够建立的最高基础。记忆与自主必须由实际检索/表现建立。
    static func foundationFloor(for kind: EvidenceKind, coverage: Double) -> MasteryVector {
        let bounded = normalized(coverage, for: kind)
        let ceiling: MasteryVector
        switch kind {
        case .exposure:
            ceiling = .init(exposure: 50, understanding: 10, practice: 0, retention: 0, autonomy: 0)
        case .explanation:
            ceiling = .init(exposure: 85, understanding: 75, practice: 0, retention: 0, autonomy: 0)
        case .exercise:
            ceiling = .init(exposure: 70, understanding: 55, practice: 70, retention: 0, autonomy: 0)
        case .project:
            ceiling = .init(exposure: 80, understanding: 65, practice: 80, retention: 0, autonomy: 0)
        case .review:
            ceiling = .init(exposure: 60, understanding: 50, practice: 35, retention: 0, autonomy: 0)
        case .independentSolve:
            ceiling = .init(exposure: 75, understanding: 70, practice: 75, retention: 0, autonomy: 0)
        }
        return MasteryVector(
            exposure: ceiling.exposure * bounded,
            understanding: ceiling.understanding * bounded,
            practice: ceiling.practice * bounded,
            retention: 0,
            autonomy: 0
        )
    }

    static func applyingFoundation(
        for kind: EvidenceKind,
        coverage: Double,
        to vector: MasteryVector
    ) -> MasteryVector {
        let floor = foundationFloor(for: kind, coverage: coverage)
        return MasteryVector(
            exposure: max(vector.exposure, floor.exposure),
            understanding: max(vector.understanding, floor.understanding),
            practice: max(vector.practice, floor.practice),
            retention: vector.retention,
            autonomy: vector.autonomy
        )
    }
}
