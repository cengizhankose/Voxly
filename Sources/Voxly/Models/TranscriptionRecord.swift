import Foundation

struct TranscriptionRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    var text: String
    var durationSeconds: Double
    var language: String?
    var targetAppBundleId: String?
    var targetAppName: String?
    var modelName: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        text: String,
        durationSeconds: Double,
        language: String? = nil,
        targetAppBundleId: String? = nil,
        targetAppName: String? = nil,
        modelName: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.durationSeconds = durationSeconds
        self.language = language
        self.targetAppBundleId = targetAppBundleId
        self.targetAppName = targetAppName
        self.modelName = modelName
    }
}
