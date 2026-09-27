import XCTest
@testable import Feed3

final class FeedingStatsTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal
    }

    /// 고정 기준일: 2026-09-26 12:00 KST
    private var referenceDay: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 12))!
    }

    private func dayAt(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    private func feeding(
        _ type: FeedType,
        start: Date,
        end: Date?,
        ml: Int? = nil
    ) -> Feeding {
        Feeding(type: type, startedAt: start, endedAt: end, amountML: ml)
    }

    // MARK: - dailySummary

    func testDailySummaryEmptyInput() {
        let summary = FeedingStats.dailySummary([], day: referenceDay, calendar: calendar)
        XCTAssertEqual(summary, FeedingStats.DailySummary(count: 0, totalML: 0, breastMinutes: 0, formulaML: 0))
    }

    func testDailySummaryCountsOnlySameDay() {
        let day = referenceDay
        let feedings = [
            feeding(.formula, start: dayAt(2026, 9, 26, 9), end: dayAt(2026, 9, 26, 9, 10), ml: 80),
            feeding(.formula, start: dayAt(2026, 9, 25, 23), end: dayAt(2026, 9, 25, 23, 20), ml: 100), // 어제
            feeding(.formula, start: dayAt(2026, 9, 27, 1), end: dayAt(2026, 9, 27, 1, 10), ml: 70),   // 내일
        ]
        let summary = FeedingStats.dailySummary(feedings, day: day, calendar: calendar)
        XCTAssertEqual(summary.count, 1)
        XCTAssertEqual(summary.totalML, 80)
        XCTAssertEqual(summary.formulaML, 80)
    }

    func testDailySummaryExcludesActiveFeeding() {
        // 진행 중(endedAt nil)은 횟수·ml 어디에도 집계되지 않음
        let feedings = [
            feeding(.formula, start: dayAt(2026, 9, 26, 8), end: nil, ml: 50),
            feeding(.breastLeft, start: dayAt(2026, 9, 26, 7), end: nil),
        ]
        let summary = FeedingStats.dailySummary(feedings, day: referenceDay, calendar: calendar)
        XCTAssertEqual(summary.count, 0)
        XCTAssertEqual(summary.totalML, 0)
        XCTAssertEqual(summary.breastMinutes, 0)
    }

    func testDailySummaryBreastMinutesAndNoML() {
        // 모유: ml 없음 → totalML 불포함, 분만 합산
        let feedings = [
            feeding(.breastLeft, start: dayAt(2026, 9, 26, 8), end: dayAt(2026, 9, 26, 8, 15)),
            feeding(.breastRight, start: dayAt(2026, 9, 26, 11), end: dayAt(2026, 9, 26, 11, 10)),
        ]
        let summary = FeedingStats.dailySummary(feedings, day: referenceDay, calendar: calendar)
        XCTAssertEqual(summary.count, 2)
        XCTAssertEqual(summary.breastMinutes, 25)
        XCTAssertEqual(summary.totalML, 0)
        XCTAssertEqual(summary.formulaML, 0)
    }

    func testDailySummaryMixedBreastAndFormula() {
        let feedings = [
            feeding(.breastLeft, start: dayAt(2026, 9, 26, 6), end: dayAt(2026, 9, 26, 6, 20)),
            feeding(.formula, start: dayAt(2026, 9, 26, 10), end: dayAt(2026, 9, 26, 10, 10), ml: 90),
            feeding(.pumpLeft, start: dayAt(2026, 9, 26, 13), end: dayAt(2026, 9, 26, 13, 30), ml: 60),
        ]
        let summary = FeedingStats.dailySummary(feedings, day: referenceDay, calendar: calendar)
        XCTAssertEqual(summary.count, 3)
        // 유축 ml 포함 → totalML = 90 + 60
        XCTAssertEqual(summary.totalML, 150)
        XCTAssertEqual(summary.formulaML, 90)
        // 모유 20분 + 유축 30분
        XCTAssertEqual(summary.breastMinutes, 50)
    }

    func testDailySummaryFormulaWithoutMLCountsButZeroML() {
        let feedings = [
            feeding(.formula, start: dayAt(2026, 9, 26, 9), end: dayAt(2026, 9, 26, 9, 5), ml: nil),
        ]
        let summary = FeedingStats.dailySummary(feedings, day: referenceDay, calendar: calendar)
        XCTAssertEqual(summary.count, 1)
        XCTAssertEqual(summary.totalML, 0)
    }

    // MARK: - 자정 경계 (걸친 수유)

    func testMidnightCrossingFeedingAttributedToEndDate() {
        // 23:50 시작 → 익일 00:10 종료: "종료 시점" 기준으로 익일에 귀속
        let feedings = [
            feeding(.formula, start: dayAt(2026, 9, 25, 23, 50), end: dayAt(2026, 9, 26, 0, 10), ml: 40),
        ]
        let todaySummary = FeedingStats.dailySummary(feedings, day: dayAt(2026, 9, 26), calendar: calendar)
        let yesterdaySummary = FeedingStats.dailySummary(feedings, day: dayAt(2026, 9, 25), calendar: calendar)

        XCTAssertEqual(todaySummary.count, 1)
        XCTAssertEqual(todaySummary.totalML, 40)
        XCTAssertEqual(yesterdaySummary.count, 0)
    }

    func testDayBoundaryEdges() {
        // 00:00:00 종료 = 오늘, 24:00 전 종료(23:59:59) = 오늘
        let feedings = [
            feeding(.formula, start: dayAt(2026, 9, 25, 23), end: dayAt(2026, 9, 26, 0, 0), ml: 30),
            feeding(.formula, start: dayAt(2026, 9, 26, 23), end: dayAt(2026, 9, 26, 23, 59), ml: 30),
        ]
        let summary = FeedingStats.dailySummary(feedings, day: dayAt(2026, 9, 26), calendar: calendar)
        XCTAssertEqual(summary.count, 2)
        XCTAssertEqual(summary.totalML, 60)
    }

    // MARK: - weeklySeries

    func testWeeklySeriesEmptyInput() {
        let series = FeedingStats.weeklySeries([], calendar: calendar)
        XCTAssertEqual(series.count, 7)
        XCTAssertTrue(series.allSatisfy { $0.count == 0 && $0.ml == 0 })
    }

    func testWeeklySeriesLengthAndOrder() {
        let series = FeedingStats.weeklySeries([], weeks: 2, calendar: calendar)
        XCTAssertEqual(series.count, 14)
        // 오래된 날부터 오름차순
        XCTAssertEqual(series.first!.day, calendar.date(byAdding: .day, value: -13, to: calendar.startOfDay(for: Date()))!)
        XCTAssertEqual(series.last!.day, calendar.startOfDay(for: Date()))
    }

    func testWeeklySeriesAggregatesPerDay() {
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let feedings = [
            feeding(.formula, start: today.addingTimeInterval(3600), end: today.addingTimeInterval(4200), ml: 60),
            feeding(.formula, start: today.addingTimeInterval(7200), end: today.addingTimeInterval(7800), ml: 40),
            feeding(.formula, start: yesterday.addingTimeInterval(3600), end: yesterday.addingTimeInterval(4200), ml: 100),
        ]
        let series = FeedingStats.weeklySeries(feedings, calendar: calendar)
        XCTAssertEqual(series.count, 7)
        XCTAssertEqual(series.last!.count, 2)
        XCTAssertEqual(series.last!.ml, 100)
        XCTAssertEqual(series.dropLast().last!.count, 1)
        XCTAssertEqual(series.dropLast().last!.ml, 100)
        XCTAssertEqual(series.dropLast(2).reduce(0) { $0 + $1.count }, 0)
    }

    func testWeeklySeriesExcludesActive() {
        let today = calendar.startOfDay(for: Date())
        let feedings = [
            feeding(.breastLeft, start: today.addingTimeInterval(3600), end: nil),
        ]
        let series = FeedingStats.weeklySeries(feedings, calendar: calendar)
        XCTAssertEqual(series.last!.count, 0)
    }

    // MARK: - hourHistogram

    func testHourHistogramEmpty() {
        XCTAssertTrue(FeedingStats.hourHistogram([], calendar: calendar).isEmpty)
    }

    func testHourHistogramCountsPerStartHour() {
        let feedings = [
            feeding(.formula, start: dayAt(2026, 9, 26, 2), end: dayAt(2026, 9, 26, 2, 10), ml: 50),
            feeding(.formula, start: dayAt(2026, 9, 26, 2, 40), end: dayAt(2026, 9, 26, 2, 50), ml: 30),
            feeding(.breastLeft, start: dayAt(2026, 9, 26, 14), end: dayAt(2026, 9, 26, 14, 15)),
            feeding(.formula, start: dayAt(2026, 9, 25, 2), end: dayAt(2026, 9, 25, 2, 10), ml: 20), // 다른 날 같은 시간도 누적
        ]
        let histogram = FeedingStats.hourHistogram(feedings, calendar: calendar)
        XCTAssertEqual(histogram[2], 3)
        XCTAssertEqual(histogram[14], 1)
        XCTAssertEqual(histogram[0], nil)
        XCTAssertEqual(histogram.values.reduce(0, +), 4)
    }

    func testHourHistogramIncludesActiveStart() {
        let feedings = [
            feeding(.breastRight, start: dayAt(2026, 9, 26, 5), end: nil),
        ]
        let histogram = FeedingStats.hourHistogram(feedings, calendar: calendar)
        XCTAssertEqual(histogram[5], 1)
    }

    // MARK: - lastFeedingGap

    func testLastFeedingGapEmptyReturnsNil() {
        XCTAssertNil(FeedingStats.lastFeedingGap([], now: referenceDay))
    }

    func testLastFeedingGapNilWhenNoFinishedFeedings() {
        let feedings = [
            feeding(.breastLeft, start: dayAt(2026, 9, 26, 10), end: nil),
        ]
        XCTAssertNil(FeedingStats.lastFeedingGap(feedings, now: referenceDay))
    }

    func testLastFeedingGapUsesLatestEndedAt() {
        let now = referenceDay
        let feedings = [
            feeding(.formula, start: dayAt(2026, 9, 26, 8), end: dayAt(2026, 9, 26, 8, 30), ml: 70), // -3.5h
            feeding(.breastLeft, start: dayAt(2026, 9, 26, 10), end: dayAt(2026, 9, 26, 10, 15)),    // -1.75h ← 최신
        ]
        let gap = FeedingStats.lastFeedingGap(feedings, now: now)
        XCTAssertEqual(gap!, 3600 * 1.75, accuracy: 0.5)
    }

    func testLastFeedingGapActiveFeedingDoesNotInterfere() {
        // 진행 중 수유(시작이 가장 최근)가 있어도 종료된 것 기준으로 간격 계산
        let now = referenceDay
        let feedings = [
            feeding(.formula, start: dayAt(2026, 9, 26, 9), end: dayAt(2026, 9, 26, 9, 30), ml: 50),
            feeding(.breastLeft, start: dayAt(2026, 9, 26, 11, 30), end: nil),
        ]
        let gap = FeedingStats.lastFeedingGap(feedings, now: now)
        XCTAssertEqual(gap!, 3600 * 2.5, accuracy: 0.5)
    }

    func testLastFeedingGapFutureEndedAtNegativeIsReturned() {
        // 시계 오류 등으로 종료 시각이 미래면 음수 간격 — 그대로 반환 (호출자가 판단)
        let now = referenceDay
        let feedings = [
            feeding(.formula, start: dayAt(2026, 9, 26, 12), end: dayAt(2026, 9, 26, 13), ml: 50),
        ]
        let gap = FeedingStats.lastFeedingGap(feedings, now: now)
        XCTAssertEqual(gap!, -3600, accuracy: 0.5)
    }

    // MARK: - dayKey / totalMlPerDay / daySectionHeaders

    func testDayKeyGroupsByCalendarDayMidnightBoundary() {
        // 자정 전후 10분은 서로 다른 dayKey
        let beforeMidnight = dayAt(2026, 9, 25, 23, 50)
        let afterMidnight = dayAt(2026, 9, 26, 0, 10)
        XCTAssertNotEqual(
            FeedingStats.dayKey(beforeMidnight, calendar: calendar),
            FeedingStats.dayKey(afterMidnight, calendar: calendar)
        )
        // 같은 날 같은 키
        XCTAssertEqual(
            FeedingStats.dayKey(beforeMidnight, calendar: calendar),
            FeedingStats.dayKey(dayAt(2026, 9, 25, 12), calendar: calendar)
        )
    }

    func testTotalMlPerDayEmptyInput() {
        XCTAssertTrue(FeedingStats.totalMlPerDay([], calendar: calendar).isEmpty)
    }

    func testTotalMlPerDayAggregatesFormulaAndPumpML() {
        let feedings = [
            feeding(.formula, start: dayAt(2026, 9, 26, 9), end: dayAt(2026, 9, 26, 9, 10), ml: 80),
            feeding(.formula, start: dayAt(2026, 9, 26, 15), end: dayAt(2026, 9, 26, 15, 10), ml: 120),
            feeding(.pumpLeft, start: dayAt(2026, 9, 26, 13), end: dayAt(2026, 9, 26, 13, 30), ml: 60),
            feeding(.breastLeft, start: dayAt(2026, 9, 26, 6), end: dayAt(2026, 9, 26, 6, 20)), // ml 없음
            feeding(.formula, start: dayAt(2026, 9, 25, 20), end: dayAt(2026, 9, 25, 20, 10), ml: 100),
        ]
        let perDay = FeedingStats.totalMlPerDay(feedings, calendar: calendar)
        // 모유(분만)는 totalML 불포함 — dailySummary 로직과 동일
        XCTAssertEqual(perDay[FeedingStats.dayKey(dayAt(2026, 9, 26), calendar: calendar)], 260)
        XCTAssertEqual(perDay[FeedingStats.dayKey(dayAt(2026, 9, 25), calendar: calendar)], 100)
        XCTAssertEqual(perDay.count, 2)
    }

    func testTotalMlPerDayMidnightCrossingGoesToEndDay() {
        // 자정 걸친 수유는 종료일에 귀속 (isFeed와 동일)
        let feedings = [
            feeding(.formula, start: dayAt(2026, 9, 25, 23, 50), end: dayAt(2026, 9, 26, 0, 10), ml: 40),
        ]
        let perDay = FeedingStats.totalMlPerDay(feedings, calendar: calendar)
        XCTAssertEqual(perDay[FeedingStats.dayKey(dayAt(2026, 9, 26), calendar: calendar)], 40)
        XCTAssertNil(perDay[FeedingStats.dayKey(dayAt(2026, 9, 25), calendar: calendar)])
    }

    func testTotalMlPerDayExcludesActiveFeeding() {
        let feedings = [
            feeding(.formula, start: dayAt(2026, 9, 26, 9), end: nil, ml: 50),
        ]
        let perDay = FeedingStats.totalMlPerDay(feedings, calendar: calendar)
        XCTAssertEqual(perDay[FeedingStats.dayKey(dayAt(2026, 9, 26), calendar: calendar)], 0)
    }

    func testDaySectionHeaderTodayYesterdayAndPlain() {
        // today = 2026-09-27(일)
        let today = dayAt(2026, 9, 27, 10)
        XCTAssertEqual(
            FeedingStats.daySectionHeader(today, now: dayAt(2026, 9, 27, 15), calendar: calendar),
            "오늘 · 9월 27일(일)"
        )
        XCTAssertEqual(
            FeedingStats.daySectionHeader(dayAt(2026, 9, 26, 10), now: today, calendar: calendar),
            "어제 · 9월 26일(토)"
        )
        XCTAssertEqual(
            FeedingStats.daySectionHeader(dayAt(2026, 9, 25, 10), now: today, calendar: calendar),
            "9월 25일(금)"
        )
    }

    func testDaySectionHeaderMonthBoundary() {
        // 10월 4일(일) — 월이 바뀌어도 'M월 d일(E)' 형식 유지
        XCTAssertEqual(
            FeedingStats.daySectionHeader(dayAt(2026, 10, 4, 10), now: dayAt(2026, 10, 8, 10), calendar: calendar),
            "10월 4일(일)"
        )
    }
}
