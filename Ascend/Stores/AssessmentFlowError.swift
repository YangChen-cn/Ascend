import Foundation

enum AssessmentFlowError: LocalizedError {
    case inactiveSession
    case missingItem
    case invalidSelection
    case duplicateResponse
    case insufficientResponses
    case reviewGradeNotExpected
    case missingDueReviewPlan
    case lowPerformanceConfidence
    case duplicatePerformanceContext
    case invalidPerformanceReceipt
    case challengeNotActive
    case challengeEvidenceTooOld

    var errorDescription: String? {
        switch self {
        case .inactiveSession: "测评会话已经结束"
        case .missingItem: "找不到当前测评题目"
        case .invalidSelection: "请完成答案与理由两项选择"
        case .duplicateResponse: "这道题已经提交"
        case .insufficientResponses: "有效作答不足 3 组，不能形成掌握观察"
        case .reviewGradeNotExpected: "当前会话不需要记忆难度反馈"
        case .missingDueReviewPlan: "复习计划尚未到期或已完成"
        case .lowPerformanceConfidence: "实作评分置信度不足，掌握估计未更新"
        case .duplicatePerformanceContext: "该实作情境已经记录，不能重复计分"
        case .invalidPerformanceReceipt: "只有通过量规或确定性验证的独立实作才能计分"
        case .challengeNotActive: "请先接取这项挑战，再开始验证"
        case .challengeEvidenceTooOld: "挑战只接受最近三天的提交或文件"
        }
    }
}
