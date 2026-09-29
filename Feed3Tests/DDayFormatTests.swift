import XCTest
@testable import Feed3

/// 표시 포맷 중앙 상수 테스트 — 라벨이 서울 시간대/한국어 로캘로 고정되는지 확인.
final class DDayFormatTests: XCTestCase {

    private let calendar = DDayMath.seoulCalendar()

    private func day(_ year: Int, _ month: Int, _ dayNumber: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: dayNumber))!
    }

    func testLongFormatContainsYearMonthDay() {
        let text = DDayFormat.long(day(2026, 10, 23))
        XCTAssertTrue(text.contains("2026"), "\(text)")
        XCTAssertTrue(text.contains("10"), "\(text)")
        XCTAssertTrue(text.contains("23"), "\(text)")
    }

    func testLongFormatContainsWeekday() {
        // 2026-10-23은 금요일.
        let text = DDayFormat.long(day(2026, 10, 23))
        XCTAssertTrue(text.contains("금"), "\(text)")
    }

    func testShortFormatIsMonthAndDay() {
        let text = DDayFormat.short(day(2026, 10, 23))
        XCTAssertTrue(text.contains("10"), "\(text)")
        XCTAssertTrue(text.contains("23"), "\(text)")
        XCTAssertFalse(text.contains("2026"), "짧은 포맷에 연도가 없어야 함: \(text)")
    }

    func testTimeZoneIsSeoulNotUTC() {
        XCTAssertEqual(DDayFormat.timeZone.identifier, "Asia/Seoul")
    }

    func testUTCInstantRendersAsSeoulCalendarDate() {
        // UTC 2026-10-01 15:30 = 서울 2026-10-02 00:30 → 서울 기준 10/2로 표시.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let instant = utc.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 15, minute: 30))!
        let text = DDayFormat.short(instant)
        XCTAssertTrue(text.contains("2"), "서울 날짜(10/2)로 표시되어야 함: \(text)")
    }
}
