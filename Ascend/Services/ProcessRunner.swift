import Foundation

actor ProcessRunner {
    enum ProcessError: LocalizedError {
        case unavailable(String)
        case failed(Int32, String)

        var errorDescription: String? {
            switch self {
            case .unavailable(let path): "无法启动命令：\(path)"
            case .failed(let code, let message): "Git 命令失败（\(code)）：\(message)"
            }
        }
    }

    func run(executableURL: URL, arguments: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        let error = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = error
        do {
            try process.run()
        } catch {
            throw ProcessError.unavailable(executableURL.path)
        }
        process.waitUntilExit()
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            throw ProcessError.failed(
                process.terminationStatus,
                String(data: errorData, encoding: .utf8) ?? "未知错误"
            )
        }
        return String(data: outputData, encoding: .utf8) ?? ""
    }
}
