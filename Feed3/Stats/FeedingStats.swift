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
}
