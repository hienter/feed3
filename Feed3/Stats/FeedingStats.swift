import Foundation

/// 수유 집계 순수 로직 — SwiftUI·SwiftData 컨텍스트 미의존.
/// 입력은 [Feeding] 값 배열만 받고, 순수 함수로만 구성한다.
enum FeedingStats {

    struct DailySummary: Equatable {
        var count: Int
        var totalML: Int
        var breastMinutes: Int
        var formulaML: Int
    }

    struct WeekPoint: Equatable {
        var day: Date       // 일 단위 시작(자정, UTC+0 캘린더 기준 아님 — 전달된 calendar 따름)
        var count: Int
        var ml: Int
    }

    // MARK: - dailySummary

    /// 특정 하루(day가 속한 캘린더 일)의 요약.
    /// - 진행 중(endedAt == nil) 수유는 집계에서 제외
    /// - 모유(breast)는 ml이 없으므로 totalML에 불포함, 지속시간(분)만 breastMinutes에 합산
    /// - 유축은 ml 있으면 totalML 포함 + breastMinutes에도 합산(모유류 취급)
    /// - formula는 totalML·formulaML에 합산
    static func dailySummary(
        _ feedings: [Feeding],
        day: Date,
        calendar: Calendar = .current
    ) -> DailySummary {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return DailySummary(count: 0, totalML: 0, breastMinutes: 0, formulaML: 0)
        }

        var summary = DailySummary(count: 0, totalML: 0, breastMinutes: 0, formulaML: 0)

        for feeding in feedings where isFeed(feeding, in: dayStart..<dayEnd) {
            summary.count += 1
            switch feeding.type {
            case .formula:
                let ml = feeding.amountML ?? 0
                summary.totalML += ml
                summary.formulaML += ml
            case .breastLeft, .breastRight, .pumpLeft, .pumpRight:
                let minutes = Int((feeding.finishedDurationSeconds ?? 0) / 60.0)
                summary.breastMinutes += minutes
                if let ml = feeding.amountML {
                    summary.totalML += ml
                }
            }
        }
        return summary
    }

    // MARK: - weeklySeries

    /// 최근 `weeks`주(기본 1주 = 7일)의 일별 (day, count, ml) 시계열. 오래된 날부터.
    /// - 진행 중 수유는 제외
    static func weeklySeries(
        _ feedings: [Feeding],
        weeks: Int = 1,
        calendar: Calendar = .current
    ) -> [WeekPoint] {
        let today = calendar.startOfDay(for: Date())
        var points: [WeekPoint] = []
        points.reserveCapacity(weeks * 7)

        for offset in stride(from: (weeks * 7 - 1), through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let summary = dailySummary(feedings, day: day, calendar: calendar)
            points.append(WeekPoint(day: day, count: summary.count, ml: summary.totalML))
        }
        return points
    }

    // MARK: - hourHistogram

    /// 0-23시 시간대별 수유 시작 분포. 진행 중 수유도 시작은 있으므로 포함.
    static func hourHistogram(
        _ feedings: [Feeding],
        calendar: Calendar = .current
    ) -> [Int: Int] {
        var histogram: [Int: Int] = [:]
        for feeding in feedings {
            let hour = calendar.component(.hour, from: feeding.startedAt)
            histogram[hour, default: 0] += 1
        }
        return histogram
    }

    // MARK: - lastFeedingGap

    /// 마지막 종료 시점 ~ now 사이 간격(초). 종료된 수유가 없으면 nil.
    /// - 진행 중 수유는 간격 계산에서 제외(아직 안 끝남)
    static func lastFeedingGap(
        _ feedings: [Feeding],
        now: Date
    ) -> TimeInterval? {
        feedings
            .compactMap { $0.endedAt }
            .max()
            .map { now.timeIntervalSince($0) }
    }

    // MARK: - helpers

    private static func isFeed(
        _ feeding: Feeding,
        in interval: Range<Date>
    ) -> Bool {
        guard let endedAt = feeding.endedAt else { return false }
        // 자정을 걸친 수유(시작은 어제, 종료는 오늘)는 "종료 시점" 기준으로 귀속
        return interval.contains(endedAt)
    }

    // MARK: - dayKey / totalMlPerDay / daySectionHeader (타임라인 일자별 그룹핑)

    /// 캘린더 날짜(자정 기준)별 그룹핑 키. "2026-09-27" 형태.
    static func dayKey(
        _ date: Date,
        calendar: Calendar = .current
    ) -> String {
        let start = calendar.startOfDay(for: date)
        let comps = calendar.dateComponents([.year, .month, .day], from: start)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    /// 일자(dayKey)별 총 ml. dailySummary와 동일 규칙:
    /// - 종료 시점 기준 귀속(자정 걸친 수유 포함), 진행 중 제외
    /// - formula는 ml 합산, 유축은 ml 있으면 합산, 모유(분만)는 ml 불포함
    /// - 기록이 있는 날만 키로 생성 (빈 날은 키 없음)
    static func totalMlPerDay(
        _ feedings: [Feeding],
        calendar: Calendar = .current
    ) -> [String: Double] {
        var result: [String: Double] = [:]
        for feeding in feedings {
            guard let endedAt = feeding.endedAt else { continue } // 진행 중 제외
            let key = dayKey(endedAt, calendar: calendar)
            let ml: Double
            switch feeding.type {
            case .formula:
                ml = Double(feeding.amountML ?? 0)
            case .breastLeft, .breastRight, .pumpLeft, .pumpRight:
                ml = feeding.amountML.map(Double.init) ?? 0
            }
            result[key, default: 0] += ml
        }
        return result
    }

    /// 타임라인 섹션 헤더 문자열.
    /// 오늘 = "오늘 · 9월 27일(일)", 어제 = "어제 · 9월 26일(토)", 그 외 = "9월 25일(금)".
    static func daySectionHeader(
        _ day: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일(E)"

        let today = calendar.startOfDay(for: now)
        let dayStart = calendar.startOfDay(for: day)
        let days = calendar.dateComponents([.day], from: dayStart, to: today).day ?? 0

        let dateText = formatter.string(from: dayStart)
        if days == 0 { return "오늘 · \(dateText)" }
        if days == 1 { return "어제 · \(dateText)" }
        return dateText
    }
}
