import Foundation

enum AnalysisBatchPlanner {
    static func ranges(itemCount: Int, batchSize: Int) -> [Range<Int>] {
        guard itemCount > 0 else { return [] }
        let safeBatchSize = max(1, batchSize)
        return stride(from: 0, to: itemCount, by: safeBatchSize).map { lowerBound in
            lowerBound..<min(lowerBound + safeBatchSize, itemCount)
        }
    }
}
