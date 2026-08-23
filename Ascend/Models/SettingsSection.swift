import Foundation

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case sources
    case ai
    case analysis
    case privacy
    case notifications
    case appearance
    case about

    var id: Self { self }
}
