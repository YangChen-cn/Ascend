import Foundation

enum AssessmentBatchPlanner {
    static func balancedPackageCounts(
        totalPackages: Int,
        maximumPackagesPerRequest: Int
    ) -> [Int] {
        guard totalPackages > 0, maximumPackagesPerRequest > 0 else { return [] }
        let requestCount = Int(ceil(Double(totalPackages) / Double(maximumPackagesPerRequest)))
        let smallerCount = totalPackages / requestCount
        let largerRequestCount = totalPackages % requestCount
        return Array(repeating: smallerCount, count: requestCount - largerRequestCount)
            + Array(repeating: smallerCount + 1, count: largerRequestCount)
    }
}
