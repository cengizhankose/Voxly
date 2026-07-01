import Foundation

enum PasteMode: String, Codable, CaseIterable, Identifiable {
    case paste
    case clipboard
    case both

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .paste:     return "Paste into focused app"
        case .clipboard: return "Copy to clipboard only"
        case .both:      return "Paste and copy"
        }
    }
}
