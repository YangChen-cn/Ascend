import Foundation

struct AssessmentBatchPackage: Codable, Sendable {
    let packages: [AssessmentPackage]

    init(packages: [AssessmentPackage]) {
        self.packages = packages
    }

    private enum CodingKeys: String, CodingKey {
        case packages
        case assessmentPackages
        case assessment_packages
        case results
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let decodedPackages = try? container.decode([AssessmentPackage].self, forKey: .packages) {
            packages = decodedPackages
        } else if let decodedPackages = try? container.decode([AssessmentPackage].self, forKey: .assessmentPackages) {
            packages = decodedPackages
        } else if let decodedPackages = try? container.decode([AssessmentPackage].self, forKey: .assessment_packages) {
            packages = decodedPackages
        } else if let decodedPackages = try? container.decode([AssessmentPackage].self, forKey: .results) {
            packages = decodedPackages
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.packages,
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "批量响应缺少 packages"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(packages, forKey: .packages)
    }
}
