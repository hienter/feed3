import XCTest
@testable import Feed3

/// App Group JSON 공유 계층(인코딩/디코딩/라운드트립/손상 복구) 테스트.
final class DDaySharedTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dday-shared-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    private func item(
        title: String = "테스트",
        year: Int = 2026,
        month: Int = 10,
        dayNumber: Int = 5,
        recurrence: DDayRecurrence = .none
    ) -> DDayItem {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = DDayMath.seoulTimeZone
        let date = calendar.date(from: DateComponents(year: year, month: month, day: dayNumber))!
        return DDayItem(title: title, date: date, recurrence: recurrence)
    }

    // MARK: - 저장/로드 라운드트립

    func testSaveAndLoadRoundTrip() throws {
        let items = [
            item(title: "생일", recurrence: .annually),
            item(title: "시험", year: 2026, month: 11, dayNumber: 1),
        ]
        try DDayShared.save(items, directory: tempDirectory)
        let loaded = DDayShared.load(directory: tempDirectory)
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(Set(loaded.map(\.title)), Set(["생일", "시험"]))
        XCTAssertEqual(loaded.first { $0.title == "생일" }?.recurrence, .annually)
    }

    func testLoadMissingFileReturnsEmpty() {
        XCTAssertTrue(DDayShared.load(directory: tempDirectory).isEmpty)
    }

    func testLoadCorruptedFileReturnsEmptyNotCrash() throws {
        try Data("not json at all {{{".utf8).write(to: DDayShared.fileURL(directory: tempDirectory))
        XCTAssertTrue(DDayShared.load(directory: tempDirectory).isEmpty)
    }

    func testSaveCreatesMissingDirectory() throws {
        let nested = tempDirectory.appendingPathComponent("a/b/c")
        try DDayShared.save([item()], directory: nested)
        XCTAssertEqual(DDayShared.load(directory: nested).count, 1)
    }

    func testRemoveAllDeletesFile() throws {
        try DDayShared.save([item()], directory: tempDirectory)
        DDayShared.removeAll(directory: tempDirectory)
        XCTAssertTrue(DDayShared.load(directory: tempDirectory).isEmpty)
    }

    // MARK: - 인코딩 형식

    func testEncodedJSONContainsExpectedKeys() throws {
        let data = try JSONEncoder().encode([item(title: "여행")])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let first = try XCTUnwrap(object.first)
        XCTAssertEqual(first["title"] as? String, "여행")
        XCTAssertNotNil(first["id"])
        XCTAssertNotNil(first["date"])
        XCTAssertNotNil(first["createdAt"])
        XCTAssertEqual(first["recurrence"] as? String, DDayRecurrence.none.rawValue)
    }

    func testDecodeLegacyJSONWithoutRecurrenceFallsBackToNone() throws {
        // 구버전(반복 필드 없는) JSON도 깨지지 않고 읽혀야 한다.
        let legacy = """
        [{"title":"옛 항목","date":650000000.0}]
        """
        let decoded = try JSONDecoder().decode([DDayItem].self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.first?.title, "옛 항목")
        XCTAssertEqual(decoded.first?.recurrence, .none)
    }

    // MARK: - 공유 파일 위치

    func testFileURLAppendsFileName() {
        let url = DDayShared.fileURL(directory: URL(fileURLWithPath: "/tmp/example"))
        XCTAssertEqual(url.lastPathComponent, DDayShared.fileName)
    }

    func testAppGroupIDMatchesEntitlements() {
        // entitlements와 위젯 확장이 같은 App Group ID를 쓰는지 확인하는 회귀 방어.
        XCTAssertEqual(DDayShared.appGroupID, "group.com.hienter.feed3.dday")
    }
}
