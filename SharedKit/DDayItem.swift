import Foundation

/// 반복 옵션. MVP는 없음/매년 두 가지.
enum DDayRecurrence: String, Codable, CaseIterable, Sendable, Hashable {
    /// 반복 없음 — 기준일 고정
    case none
    /// 매년 반복 — 표시/정렬 시 매년 같은 월·일로 롤링
    case annually

    /// 반복 옵션 한글 라벨(Picker 표시용)
    var label: String {
        switch self {
        case .none: return "없음"
        case .annually: return "매년"
        }
    }
}

/// 하나의 디데이 항목. 메인 앱 · 위젯 확장 · 테스트가 모두 사용하는
/// 공유 도메인 모델(SharedKit 동기화 그룹 — 별도 모듈 없이 각 타깃에 컴파일된다).
struct DDayItem: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var title: String
    /// 기준일. 날짜(월·일) 성분만 사용하며 계산은 항상 startOfDay로 정규화한다.
    var date: Date
    var recurrence: DDayRecurrence
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        recurrence: DDayRecurrence = .none,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.recurrence = recurrence
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, date, recurrence, createdAt
    }

    /// 하위 호환 디코딩: 새 필드가 없는 구버전 JSON도 읽을 수 있도록 decodeIfPresent 사용.
    /// recurrence의 알 수 없는 rawValue는 .none으로 복구한다(포워드 호환).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        let decodedRecurrence = try? container.decodeIfPresent(DDayRecurrence.self, forKey: .recurrence)
        recurrence = decodedRecurrence ?? .none
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}
