import Foundation
import Security

actor KeychainStore {
    static let shared = KeychainStore()

    enum KeychainError: LocalizedError {
        case unhandled(OSStatus)
        case invalidData

        var errorDescription: String? {
            switch self {
            case .unhandled(let status):
                "Keychain 操作失败（\(status)）"
            case .invalidData:
                "Keychain 中的密钥格式无效"
            }
        }
    }

    func saveAPIKey(_ key: String, endpointID: UUID) throws {
        let account = endpointID.uuidString
        let data = Data(key.utf8)
        let query = baseQuery(account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus != errSecItemNotFound { throw KeychainError.unhandled(updateStatus) }

        var addQuery = query
        attributes.forEach { addQuery[$0.key] = $0.value }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError.unhandled(addStatus) }
    }

    func apiKey(endpointID: UUID) throws -> String? {
        var query = baseQuery(account: endpointID.uuidString)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return value
    }

    func deleteAPIKey(endpointID: UUID) throws {
        let status = SecItemDelete(baseQuery(account: endpointID.uuidString) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConstants.bundleIdentifier + ".ai-endpoints",
            kSecAttrAccount as String: account
        ]
    }
}
