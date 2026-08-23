import Foundation

struct ChallengeRequirement: Codable, Equatable, Sendable {
    let minimumEvidenceKind: EvidenceKind
    let minimumIndependence: Double
    let minimumConfidence: Double
    let minimumMastery: Double
    let requiredEvidenceCount: Int

    init(
        minimumEvidenceKind: EvidenceKind = .project,
        minimumIndependence: Double = 0.8,
        minimumConfidence: Double = 0.8,
        minimumMastery: Double = 0,
        requiredEvidenceCount: Int = 1
    ) {
        self.minimumEvidenceKind = minimumEvidenceKind
        self.minimumIndependence = minimumIndependence.clamped(to: 0...1.2)
        self.minimumConfidence = minimumConfidence.clamped(to: 0...1)
        self.minimumMastery = minimumMastery.clamped(to: 0...100)
        self.requiredEvidenceCount = requiredEvidenceCount.clamped(to: 1...20)
    }

    var descriptions: [String] {
        [
            "证据类型至少为(minimumEvidenceKind.title)",
            "独立程度不低于 \(minimumIndependence.formatted(.number.precision(.fractionLength(1))))",
            "证据置信度不低于 \(minimumConfidence.formatted(.number.precision(.fractionLength(1))))",
            "需要 \(requiredEvidenceCount) 条已验证实据"
        ] + (minimumMastery > 0 ? ["当前掌握不低于 \(Int(minimumMastery.rounded()))"] : [])
    }
}
