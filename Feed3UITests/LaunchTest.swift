import XCTest

/// E2E: 앱 런치 → 크래시 없음 → 빈 상태 안내 표시 확인.
/// 기존 Feed3 LaunchTest의 런치 재시도 패턴을 유지한다.
@MainActor
final class LaunchTest: XCTestCase {

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testLaunchShowsEmptyStateWithoutCrash() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset"]

        // 시뮬레이터 인프라 플레이크(런치 실패/조기 종료) 대비 3회 재시도.
        var launched = false
        for _ in 0..<3 {
            app.launch()
            if app.buttons["addButton"].waitForExistence(timeout: 15) {
                launched = true
                break
            }
            // 실패 원인 진단: 계층 텍스트 + 스크린샷을 xcresult에 남긴다
            print("DDayUIT-diag: state=\(app.state.rawValue) args=\(app.launchArguments)")
            print("DDayUIT-diag debugDescription:\n\(app.debugDescription.prefix(3000))")
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "launch-failure"
            shot.lifetime = .keepAlways
            add(shot)
            app.terminate()
            sleep(3)
        }
        XCTAssertTrue(launched, "3회 재시도 후에도 앱 런치 실패(시뮬레이터 인프라 문제)")

        // 빈 상태 안내 표시 확인(신규 설치이므로 디데이가 없다).
        let emptyState = app.otherElements["emptyState"].firstMatch
        let emptyByText = app.staticTexts["디데이를 추가하세요"].firstMatch
        let emptyShown = emptyState.waitForExistence(timeout: 8)
            || emptyByText.waitForExistence(timeout: 3)
            || app.cells.containing(
                NSPredicate(format: "label CONTAINS %@", "디데이를 추가")
            ).firstMatch.exists
        XCTAssertTrue(emptyShown, "빈 상태 안내가 표시되지 않음")

        // 추가 버튼이 접근 가능하고 활성 상태인지 확인.
        let addButton = app.buttons["addButton"]
        XCTAssertTrue(addButton.exists, "추가 버튼 없음")
        XCTAssertTrue(addButton.isEnabled, "추가 버튼 비활성")
    }
}
