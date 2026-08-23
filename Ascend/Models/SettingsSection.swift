import Foundation

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case sources
    case ai
    case analysis
    case privacy
    case notifications
    case appearance

    var id: Self { self }
}
