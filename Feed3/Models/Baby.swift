import Foundation
import SwiftData

@Model
final class Baby {
    @Attribute(.unique) var id: UUID
    var name: String
    var birthDate: Date
    var createdAt: Date

    init(id: UUID = UUID(), name: String, birthDate: Date, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.createdAt = createdAt
    }
}
