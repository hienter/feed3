import XCTest
@testable import Feed3

final class FeedingTests: XCTestCase {
    private func date(_ secondsAgo: TimeInterval, from reference: Date = Date(timeIntervalSince1970: 1_760_000_000)) -> Date {
        reference.addingTimeInterval(-secondsAgo)
    }

    // MARK: - durationSeconds

    func testDurationSecondsForFinishedFeeding() {
        let startedAt = date(600)
        let endedAt = date(300)
        let feeding = Feeding(type: .breastLeft, startedAt: startedAt, endedAt: endedAt)

        XCTAssertEqual(feeding.durationSeconds, 300, accuracy: 0.001)
    }

    func testDurationSecondsForActiveFeedingUsesNow() {
        let startedAt = Date().addingTimeInterval(-120)
        let feeding = Feeding(type: .formula, startedAt: startedAt, endedAt: nil)

        // 진행 중: 시작~지금 경과 시간이며, 최소한 120초에 가까움 (실행 지연 허용)
        XCTAssertGreaterThanOrEqual(feeding.durationSeconds, 119.0)
        XCTAssertLessThan(feeding.durationSeconds, 125.0)
    }

    func testFinishedDurationNilWhileActive() {
        let feeding = Feeding(type: .breastRight, startedAt: date(100))
        XCTAssertNil(feeding.finishedDurationSeconds)
        XCTAssertTrue(feeding.isActive)
    }

    func testFinishedDurationValueAfterEnd() {
        var feeding = Feeding(type: .pumpLeft, startedAt: date(500))
        feeding.endedAt = date(200)
        XCTAssertEqual(feeding.finishedDurationSeconds, 300, accuracy: 0.001)
        XCTAssertFalse(feeding.isActive)
    }

    func testNegativeDurationClampedToZero() {
        // 이상 데이터: 종료가 시작보다 앞 — 음수가 되지 않아야 함
        let feeding = Feeding(type: .breastLeft, startedAt: date(100), endedAt: date(200))
        XCTAssertEqual(feeding.finishedDurationSeconds, 0, accuracy: 0.001)
        XCTAssertEqual(feeding.durationSeconds, 0, accuracy: 0.001)
    }

    // MARK: - FeedType 좌우 합산 판정

    func testFeedTypeClassification() {
        XCTAssertTrue(FeedType.breastLeft.isBreast)
        XCTAssertTrue(FeedType.breastRight.isBreast)
        XCTAssertTrue(FeedType.pumpLeft.isPump)
        XCTAssertTrue(FeedType.pumpRight.isPump)
        XCTAssertTrue(FeedType.formula.isFormula)

        XCTAssertFalse(FeedType.formula.isBreast)
        XCTAssertFalse(FeedType.formula.isPump)
        XCTAssertFalse(FeedType.breastLeft.isPump)
    }

    func testOppositeSideSumsUpSides() {
        XCTAssertEqual(FeedType.breastLeft.oppositeSide, .breastRight)
        XCTAssertEqual(FeedType.breastRight.oppositeSide, .breastLeft)
        XCTAssertEqual(FeedType.pumpLeft.oppositeSide, .pumpRight)
        XCTAssertEqual(FeedType.pumpRight.oppositeSide, .pumpLeft)
        XCTAssertNil(FeedType.formula.oppositeSide)
    }

    func testEnumRawValuesStableForPersistence() {
        // String 원시값 저장 — 원시값이 바뀌면 기존 레코드가 깨지므로 고정 검증
        XCTAssertEqual(FeedType.breastLeft.rawValue, "breastLeft")
        XCTAssertEqual(FeedType.breastRight.rawValue, "breastRight")
        XCTAssertEqual(FeedType.formula.rawValue, "formula")
        XCTAssertEqual(FeedType.pumpLeft.rawValue, "pumpLeft")
        XCTAssertEqual(FeedType.pumpRight.rawValue, "pumpRight")
        XCTAssertEqual(FeedType.allCases.count, 5)
    }

    func testOptionalFieldsDefault() {
        let feeding = Feeding(type: .formula, startedAt: date(60))
        XCTAssertNil(feeding.amountML)
        XCTAssertNil(feeding.note)
        XCTAssertNil(feeding.baby)
        XCTAssertNotNil(feeding.id)
    }
}
