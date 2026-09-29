import Foundation

/// 디데이 계산 순수 로직. 뷰·저장소와 분리해 단위 테스트 대상으로만 존재한다.
///
/// 날짜 경계는 항상 지정한 캘린더(기본: 아시아/서울)의 자정(startOfDay) 기준으로
/// 판정한다. UTC 고정 Date를 그대로 비교하면 한국 시간 밤 9시~자정 사이에
/// "어제/오늘"이 뒤집히므로, 모든 계산은 이 모듈을 통해서만 수행한다.
enum DDayMath {

    /// 한국 시간대(서울). 앱의 날짜 개념은 전부 이 시간대 기준이다.
    static let seoulTimeZone = TimeZone(identifier: "Asia/Seoul")!

    /// 서울 시간대 그레고리안 캘린더.
    static func seoulCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = seoulTimeZone
        return calendar
    }

    /// 해당 날짜의 자정(서울 시간대). 시·분 성분을 제거한다.
    static func startOfDay(_ date: Date, calendar: Calendar = seoulCalendar()) -> Date {
        calendar.startOfDay(for: date)
    }

    /// reference(보통 오늘) 대비 target까지의 일수.
    /// 미래는 양수, 과거는 음수, 같은 날은 0.
    static func dayOffset(
        from reference: Date,
        to target: Date,
        calendar: Calendar = seoulCalendar()
    ) -> Int {
        let components = calendar.dateComponents(
            [.day],
            from: startOfDay(reference, calendar: calendar),
            to: startOfDay(target, calendar: calendar)
        )
        return components.day ?? 0
    }

    /// 화면 표시용 D-day 라벨. 같은 날 "D-DAY", 미래 "D-123", 과거 "D+45".
    static func ddayLabel(
        target: Date,
        reference: Date = Date(),
        calendar: Calendar = seoulCalendar()
    ) -> String {
        switch dayOffset(from: reference, to: target, calendar: calendar) {
        case 0: return "D-DAY"
        case let days where days > 0: return "D-\(days)"
        case let days: return "D+\(-days)"
        }
    }

    /// 반복 옵션을 반영해 reference 시점 이후(같은 날 포함)의 다음 실제 날짜를 반환한다.
    /// - .none: 기준일 그대로(과거면 과거 유지)
    /// - .annually: 올해 해당 월·일이 지났으면 내년, 안 지났으면 올해 날짜
    /// - 2/29처럼 해당 연도에 없는 날은 전 날(2/28)로 완화한다. (추정 — 제품 관례 선택)
    static func nextOccurrence(
        of date: Date,
        recurrence: DDayRecurrence,
        reference: Date = Date(),
        calendar: Calendar = seoulCalendar()
    ) -> Date {
        let target = startOfDay(date, calendar: calendar)
        guard recurrence == .annually else { return target }

        let today = startOfDay(reference, calendar: calendar)
        let source = calendar.dateComponents([.month, .day], from: target)
        let currentYear = calendar.component(.year, from: today)

        if let candidate = occurrenceDate(year: currentYear, month: source.month, day: source.day, calendar: calendar),
           candidate >= today {
            return candidate
        }
        let nextYear = currentYear + 1
        return occurrenceDate(year: nextYear, month: source.month, day: source.day, calendar: calendar) ?? target
    }

    /// 해당 연도의 월·일 날짜를 만든다. 존재하지 않는 날(윤년 아닌 해의 2/29)은 전 날로 완화.
    private static func occurrenceDate(
        year: Int,
        month: Int?,
        day: Int?,
        calendar: Calendar
    ) -> Date? {
        var components = DateComponents(year: year, month: month, day: day)
        if let date = calendar.date(from: components) {
            return date
        }
        components.day = (day ?? 1) - 1
        return calendar.date(from: components)
    }

    /// 목록 표시 순서: 반복을 반영한 다음 날짜 오름차순(가까운 순).
    /// 같은 날짜면 먼저 만든 항목이 먼저(생성 시각 보조 정렬).
    static func sorted(
        _ items: [DDayItem],
        reference: Date = Date(),
        calendar: Calendar = seoulCalendar()
    ) -> [DDayItem] {
        items.sorted { lhs, rhs in
            let lhsNext = nextOccurrence(of: lhs.date, recurrence: lhs.recurrence, reference: reference, calendar: calendar)
            let rhsNext = nextOccurrence(of: rhs.date, recurrence: rhs.recurrence, reference: reference, calendar: calendar)
            if lhsNext != rhsNext { return lhsNext < rhsNext }
            return lhs.createdAt < rhs.createdAt
        }
    }

    /// 위젯 표시용: 반복을 반영해 "가장 가까운" 항목 하나를 고른다.
    /// 미래(오늘 포함) 항목 중 가장 임박한 것을 고르고, 전부 과거면 가장 최근에 지난 것.
    static func nearest(
        from items: [DDayItem],
        reference: Date = Date(),
        calendar: Calendar = seoulCalendar()
    ) -> DDayItem? {
        guard !items.isEmpty else { return nil }
        let withNext = items.map { item in
            (item, nextOccurrence(of: item.date, recurrence: item.recurrence, reference: reference, calendar: calendar))
        }
        let today = startOfDay(reference, calendar: calendar)
        if let upcoming = withNext.filter({ $0.1 >= today }).min(by: { $0.1 < $1.1 }) {
            return upcoming.0
        }
        return withNext.max(by: { $0.1 < $1.1 })?.0
    }
}
