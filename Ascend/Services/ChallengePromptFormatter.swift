import Foundation

struct ChallengePromptFormatter: Sendable {
    func format(
        challenge: Challenge,
        requirement: ChallengeRequirement,
        knowledgeNames: [String]
    ) -> String {
        let targets = knowledgeNames.isEmpty ? "未指定" : knowledgeNames.joined(separator: "、")
        let requirements = requirement.descriptions.map { "- \($0)" }.joined(separator: "\n")
        return """
        # \(challenge.title)

        ## 实作任务
        \(challenge.challengeDescription)

        ## 目标知识点
        \(targets)

        ## 实作验收要求
        \(requirements)

        ## 提交说明
        完成后在知境录中选择最近三天的 Git 提交或本地文件，勾选具体实现文件并提交 AI 核验。请保留必要的实现、测试或运行结果；不要粘贴 API Key、密码或其他密钥。
        """
    }
}
