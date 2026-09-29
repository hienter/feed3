import XCTest
@testable import Feed3

/// DDayStore CRUD·지속화·위젯 리로드 훅 테스트.
@MainActor
final class DDayStoreTests: XCTestCase {

    private var tempDirectory: URL!
    private var reloadedCount = 0

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dday-store-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        reloadedCount = 0
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    private func makeStore() -> DDayStore {
        DDayStore(directory: tempDirectory) { [weak self] in
            self?.reloadedCount += 1
        }
    }

    private func makeItem(title: String) -> DDayItem {
        DDayItem(title: title, date: DDayMath.startOfDay(Date()))
    }

    func testUpsertAddsNewItem() {
        let store = makeStore()
        store.upsert(makeItem(title: "첫 항목"))
        XCTAssertEqual(store.items.count, 1)
    }

    func testUpsertSameIDReplacesNotDuplicates() {
        let store = makeStore()
        var item = makeItem(title: "원래")
        store.upsert(item)
        item.title = "수정됨"
        store.upsert(item)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.title, "수정됨")
    }

    func testRemoveDeletesItem() {
        let store = makeStore()
        let item = makeItem(title: "지울 것")
        store.upsert(item)
        store.remove(item)
        XCTAssertTrue(store.items.isEmpty)
    }

    func testUpsertPersistsToFile() throws {
        let store = makeStore()
        store.upsert(makeItem(title: "영속 확인"))
        let reloaded = DDayShared.load(directory: tempDirectory)
        XCTAssertEqual(reloaded.map(\.title), ["영속 확인"])
    }

    func testRemovePersistsToFile() throws {
        let store = makeStore()
        let item = makeItem(title: "삭제 확인")
        store.upsert(item)
        store.remove(item)
        XCTAssertTrue(DDayShared.load(directory: tempDirectory).isEmpty)
    }

    func testInitLoadsExistingFile() throws {
        let existing = [makeItem(title: "기존 데이터")]
        try DDayShared.save(existing, directory: tempDirectory)
        let store = makeStore()
        XCTAssertEqual(store.items.map(\.title), ["기존 데이터"])
    }

    func testUpsertTriggersWidgetReload() {
        let store = makeStore()
        store.upsert(makeItem(title: "위젯"))
        XCTAssertEqual(reloadedCount, 1)
    }

    func testRemoveTriggersWidgetReload() {
        let store = makeStore()
        let item = makeItem(title: "위젯2")
        store.upsert(item)
        store.remove(item)
        XCTAssertEqual(reloadedCount, 2)
    }

    func testStartOfDayNormalizesTimeComponents() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = DDayMath.seoulTimeZone
        let afternoon = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 18, minute: 44))!
        let normalized = DDayMath.startOfDay(afternoon)
        let components = calendar.dateComponents([.hour, .minute, .second], from: normalized)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
        XCTAssertEqual(calendar.component(.day, from: normalized), 15)
    }
}
