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
        if container.contains(.packages) {
            packages = try container.decode([AssessmentPackage].self, forKey: .packages)
            return
        }
        if container.contains(.assessmentPackages) {
            packages = try container.decode([AssessmentPackage].self, forKey: .assessmentPackages)
            return
        }
        if container.contains(.assessment_packages) {
            packages = try container.decode([AssessmentPackage].self, forKey: .assessment_packages)
            return
        }
        if container.contains(.results) {
            packages = try container.decode([AssessmentPackage].self, forKey: .results)
            return
        }
        throw DecodingError.keyNotFound(
            CodingKeys.packages,
            .init(
                codingPath: decoder.codingPath,
                debugDescription: "批量响应缺少 packages"
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(packages, forKey: .packages)
    }
}
