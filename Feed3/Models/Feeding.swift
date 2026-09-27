import Foundation
import SwiftData

enum FeedType: String, Codable, CaseIterable {
    case breastLeft
    case breastRight
    case formula
    case pumpLeft
    case pumpRight

    var isBreast: Bool { self == .breastLeft || self == .breastRight }
    var isPump: Bool { self == .pumpLeft || self == .pumpRight }
    var isFormula: Bool { self == .formula }

    /// 좌우 합산 판정: 같은 종류(모유/유축)의 반대쪽
    var oppositeSide: FeedType? {
        switch self {
        case .breastLeft: return .breastRight
        case .breastRight: return .breastLeft
        case .pumpLeft: return .pumpRight
        case .pumpRight: return .pumpLeft
        case .formula: return nil
        }
    }
}

@Model
final class Feeding {
    @Attribute(.unique) var id: UUID
    var type: FeedType
    var startedAt: Date
    var endedAt: Date?
    var amountML: Int?
    var note: String?
    var baby: Baby?

    init(
        id: UUID = UUID(),
        type: FeedType,
        startedAt: Date,
        endedAt: Date? = nil,
        amountML: Int? = nil,
        note: String? = nil,
        baby: Baby? = nil
    ) {
        self.id = id
        self.type = type
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.amountML = amountML
        self.note = note
        self.baby = baby
    }

    /// 지속시간(초). 진행 중이면 시작~지금까지의 경과 시간.
    var durationSeconds: TimeInterval {
        let end = endedAt ?? Date()
        return max(0, end.timeIntervalSince(startedAt))
    }

    /// 종료된 수유의 지속시간(초). 진행 중이면 nil.
    var finishedDurationSeconds: TimeInterval? {
        guard let endedAt else { return nil }
        return max(0, endedAt.timeIntervalSince(startedAt))
    }

    /// 진행 중(종료되지 않음) 여부
    var isActive: Bool { endedAt == nil }
}

/// sheet(item:) 프레젠테이션용
extension Feeding: Identifiable {}
