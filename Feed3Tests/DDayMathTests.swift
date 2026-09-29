import XCTest
@testable import Feed3

/// 디데이 계산 순수 로직 테스트. 모든 기준 시각은 서울 시간대 자정 근처로
/// 고정해 CI 러너의 로컬 시간대(UTC)와 무관하게 동작한다.
final class DDayMathTests: XCTestCase {

    private let calendar = DDayMath.seoulCalendar()

    /// 서울 시간대 특정 날짜(자정)의 Date를 만든다.
    private func day(_ year: Int, _ month: Int, _ dayNumber: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: dayNumber, hour: hour))!
    }

    // MARK: - dayOffset

    func testDayOffsetTodayIsZero() {
        let today = day(2026, 10, 1, hour: 15)
        XCTAssertEqual(DDayMath.dayOffset(from: today, to: today), 0)
    }

    func testDayOffsetFutureIsPositive() {
        XCTAssertEqual(DDayMath.dayOffset(from: day(2026, 10, 1), to: day(2026, 10, 31)), 30)
    }

    func testDayOffsetPastIsNegative() {
        XCTAssertEqual(DDayMath.dayOffset(from: day(2026, 10, 31), to: day(2026, 10, 1)), -30)
    }

    func testDayOffsetAcrossMonthBoundary() {
        XCTAssertEqual(DDayMath.dayOffset(from: day(2026, 9, 30), to: day(2026, 10, 1)), 1)
    }

    func testDayOffsetAcrossYearBoundary() {
        XCTAssertEqual(DDayMath.dayOffset(from: day(2026, 12, 31), to: day(2027, 1, 1)), 1)
    }

    func testDayOffsetLeapDayFromJanuary() {
        // 2024는 윤년. 1/1 → 2/29는 59일.
        XCTAssertEqual(DDayMath.dayOffset(from: day(2024, 1, 1), to: day(2024, 2, 29)), 59)
    }

    func testDayOffsetNonLeapYearFebruary() {
        // 2025는 평년. 2/27 → 3/1은 2일(2/29 없음).
        XCTAssertEqual(DDayMath.dayOffset(from: day(2025, 2, 27), to: day(2025, 3, 1)), 2)
    }

    func testDayOffsetIgnoresTimeOfDay() {
        // 오늘 23시 → 내일 1시도 1일 차이. 시각 성분이 아니라 날짜 경계로 판정.
        let from = day(2026, 10, 1, hour: 23)
        let to = day(2026, 10, 2, hour: 1)
        XCTAssertEqual(DDayMath.dayOffset(from: from, to: to), 1)
    }

    func testDayOffsetSeoulMidnightVsUTC() {
        // 서울 10/2 00:30은 UTC 10/1 15:30 — 서울 기준으로는 10/2여야 한다.
        let seoulOct2 = day(2026, 10, 2, hour: 0).addingTimeInterval(30 * 60)
        XCTAssertEqual(calendar.component(.day, from: seoulOct2), 2)
    }

    // MARK: - ddayLabel

    func testDdayLabelToday() {
        XCTAssertEqual(DDayMath.ddayLabel(target: day(2026, 10, 1), reference: day(2026, 10, 1)), "D-DAY")
    }

    func testDdayLabelFuture() {
        XCTAssertEqual(DDayMath.ddayLabel(target: day(2026, 10, 31), reference: day(2026, 10, 1)), "D-30")
    }

    func testDdayLabelPast() {
        XCTAssertEqual(DDayMath.ddayLabel(target: day(2026, 9, 1), reference: day(2026, 10, 1)), "D+30")
    }

    func testDdayLabelDayBeforeYearEnd() {
        XCTAssertEqual(
            DDayMath.ddayLabel(target: day(2026, 12, 31), reference: day(2026, 12, 30)),
            "D-1"
        )
    }

    func testDdayLabelNewYearDay() {
        XCTAssertEqual(
            DDayMath.ddayLabel(target: day(2027, 1, 1), reference: day(2026, 12, 31)),
            "D-1"
        )
    }

    // MARK: - nextOccurrence / 반복

    func testNextOccurrenceNoRecurrenceReturnsFixedDate() {
        let fixed = day(2025, 5, 10)
        let result = DDayMath.nextOccurrence(of: fixed, recurrence: .none, reference: day(2026, 10, 1))
        XCTAssertEqual(result, fixed)
    }

    func testNextOccurrenceAnnuallyThisYearNotPassed() {
        // 올해 12/25가 아직 안 지났으면 올해 날짜.
        let birthday = day(2000, 12, 25)
        let result = DDayMath.nextOccurrence(of: birthday, recurrence: .annually, reference: day(2026, 10, 1))
        XCTAssertEqual(result, day(2026, 12, 25))
    }

    func testNextOccurrenceAnnuallyRolledToNextYear() {
        // 올해 3/1은 지났으니 내년 3/1로 롤링.
        let anniversary = day(2019, 3, 1)
        let result = DDayMath.nextOccurrence(of: anniversary, recurrence: .annually, reference: day(2026, 10, 1))
        XCTAssertEqual(result, day(2027, 3, 1))
    }

    func testNextOccurrenceAnnuallyTodayCountsAsToday() {
        // 오늘이 생일이면 오늘(0일)이 다음 occurrence.
        let birthday = day(2000, 10, 1)
        let result = DDayMath.nextOccurrence(of: birthday, recurrence: .annually, reference: day(2026, 10, 1))
        XCTAssertEqual(result, day(2026, 10, 1))
    }

    func testNextOccurrenceAnnuallyFeb29RelaxesToFeb28InNonLeapYear() {
        // 윤년 2/29 생일 → 평년(2027)에서는 2/28로 완화.
        let leapBirthday = day(2024, 2, 29)
        let result = DDayMath.nextOccurrence(of: leapBirthday, recurrence: .annually, reference: day(2026, 10, 1))
        XCTAssertEqual(result, day(2027, 2, 28))
    }

    func testNextOccurrenceAnnuallyFeb29KeptInLeapYear() {
        let leapBirthday = day(2024, 2, 29)
        let result = DDayMath.nextOccurrence(of: leapBirthday, recurrence: .annually, reference: day(2026, 10, 1))
        // 2028은 윤년이므로 2/29 그대로.
        let nextLeap = DDayMath.nextOccurrence(of: leapBirthday, recurrence: .annually, reference: day(2028, 1, 1))
        XCTAssertEqual(nextLeap, day(2028, 2, 29))
    }

    // MARK: - 정렬

    func testSortsByNearestUpcoming() {
        let items = [
            DDayItem(title: "먼 미래", date: day(2026, 12, 25)),
            DDayItem(title: "곧", date: day(2026, 10, 5)),
            DDayItem(title: "더 먼 미래", date: day(2027, 1, 1)),
        ]
        let sorted = DDayMath.sorted(items, reference: day(2026, 10, 1))
        XCTAssertEqual(sorted.map(\.title), ["곧", "먼 미래", "더 먼 미래"])
    }

    func testSortPlacesPastFixedDateLast() {
        let items = [
            DDayItem(title: "지난 날", date: day(2026, 1, 1)),
            DDayItem(title: "다가오는 날", date: day(2026, 11, 1)),
        ]
        let sorted = DDayMath.sorted(items, reference: day(2026, 10, 1))
        XCTAssertEqual(sorted.map(\.title), ["다가오는 날", "지난 날"])
    }

    func testSortAnnualOverridesOldDate() {
        // 고정 과거날짜보다 매년 반복되는 항목이 가까우면 반복 항목이 먼저.
        let items = [
            DDayItem(title: "고정 과거", date: day(2026, 10, 2)),
            DDayItem(title: "매년 10/3", date: day(2000, 10, 3), recurrence: .annually),
        ]
        let sorted = DDayMath.sorted(items, reference: day(2026, 10, 1))
        XCTAssertEqual(sorted.map(\.title), ["매년 10/3", "고정 과거"])
    }

    func testSortTieBreaksByCreatedAt() {
        let earlier = Date(timeIntervalSince1970: 1_000)
        let later = Date(timeIntervalSince1970: 2_000)
        let items = [
            DDayItem(title: "나중", date: day(2026, 10, 5), createdAt: later),
            DDayItem(title: "먼저", date: day(2026, 10, 5), createdAt: earlier),
        ]
        let sorted = DDayMath.sorted(items, reference: day(2026, 10, 1))
        XCTAssertEqual(sorted.map(\.title), ["먼저", "나중"])
    }

    func testSortEmptyArrayStaysEmpty() {
        XCTAssertTrue(DDayMath.sorted([], reference: day(2026, 10, 1)).isEmpty)
    }

    // MARK: - nearest (위젯용)

    func testNearestPicksSoonestUpcoming() {
        let items = [
            DDayItem(title: "a", date: day(2026, 12, 25)),
            DDayItem(title: "b", date: day(2026, 10, 5)),
        ]
        XCTAssertEqual(DDayMath.nearest(from: items, reference: day(2026, 10, 1))?.title, "b")
    }

    func testNearestEmptyReturnsNil() {
        XCTAssertNil(DDayMath.nearest(from: [], reference: day(2026, 10, 1)))
    }

    func testNearestAllPastReturnsMostRecentPast() {
        let items = [
            DDayItem(title: "오래된", date: day(2026, 1, 1)),
            DDayItem(title: "최근", date: day(2026, 9, 30)),
        ]
        XCTAssertEqual(DDayMath.nearest(from: items, reference: day(2026, 10, 1))?.title, "최근")
    }
}
