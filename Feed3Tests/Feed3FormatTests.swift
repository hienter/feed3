import XCTest
@testable import Feed3

/// UI 표시용 포맷 순수 로직 테스트.
final class Feed3FormatTests: XCTestCase {

    // MARK: - relativeGapText

    func testGapUnderOneMinute() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let date = now.addingTimeInterval(-30)
        XCTAssertEqual(Feed3Format.relativeGapText(from: date, to: now), "방금")
    }

    func testGapMinutesOnly() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let date = now.addingTimeInterval(-15 * 60)
        XCTAssertEqual(Feed3Format.relativeGapText(from: date, to: now), "15분 전")
    }

    func testGapHoursOnly() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let date = now.addingTimeInterval(-2 * 3600)
        XCTAssertEqual(Feed3Format.relativeGapText(from: date, to: now), "2시간 전")
    }

    func testGapHoursAndMinutes() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let date = now.addingTimeInterval(-(2 * 3600 + 15 * 60))
        XCTAssertEqual(Feed3Format.relativeGapText(from: date, to: now), "2시간 15분 전")
    }

    func testGapFutureClampsToZero() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let date = now.addingTimeInterval(60)
        XCTAssertEqual(Feed3Format.relativeGapText(from: date, to: now), "방금")
    }

    // MARK: - clockText / elapsedText

    func testClockMinutesSeconds() {
        XCTAssertEqual(Feed3Format.clockText(seconds: 754), "12:34")
    }

    func testClockHours() {
        XCTAssertEqual(Feed3Format.clockText(seconds: 3661), "1:01:01")
    }

    func testElapsedTextMatchesClock() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let now = start.addingTimeInterval(125)
        XCTAssertEqual(Feed3Format.elapsedText(from: start, to: now), "02:05")
    }

    // MARK: - durationText

    func testDurationUnderOneMinute() {
        XCTAssertEqual(Feed3Format.durationText(seconds: 45), "1분 미만")
    }

    func testDurationMinutes() {
        XCTAssertEqual(Feed3Format.durationText(seconds: 12 * 60), "12분")
    }

    func testDurationHoursAndMinutes() {
        XCTAssertEqual(Feed3Format.durationText(seconds: 65 * 60), "1시간 5분")
    }

    func testDurationExactHour() {
        XCTAssertEqual(Feed3Format.durationText(seconds: 2 * 3600), "2시간")
    }

    // MARK: - typeLabel

    func testTypeLabels() {
        XCTAssertEqual(Feed3Format.typeLabel(.breastLeft), "모유 · 왼쪽")
        XCTAssertEqual(Feed3Format.typeLabel(.breastRight), "모유 · 오른쪽")
        XCTAssertEqual(Feed3Format.typeLabel(.formula), "분유")
        XCTAssertEqual(Feed3Format.typeLabel(.pumpLeft), "유축 · 왼쪽")
        XCTAssertEqual(Feed3Format.typeLabel(.pumpRight), "유축 · 오른쪽")
    }
}
