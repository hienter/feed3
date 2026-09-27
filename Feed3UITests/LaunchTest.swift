import XCTest

/// E2E: 런치 → 온보딩(아기 등록) → 분유 기록 → 타임라인 표시 확인.
/// 신규 설치 상태를 가정하되, 온보딩이 이미 끝난 설치(재실행)에서도 통과하도록
/// 온보딩 단계는 폼이 떠 있을 때만 수행한다.
@MainActor
final class LaunchTest: XCTestCase {

    override func setUp() async throws {
        continueAfterFailure = false
    }

    /// 값이 기대와 같아질 때까지 폴링(onAppear 등 늦은 초기화 대비).
    private func waitValue(
        _ element: XCUIElement,
        expected: String,
        timeout: TimeInterval
    ) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        var last: String?
        while Date() < deadline {
            last = element.value as? String
            if last == expected { return last }
            _ = element.waitForExistence(timeout: 0.5)
        }
        return last
    }

    func testOnboardingAndFormulaRecordFlow() throws {
        let app = XCUIApplication()
        var launched = false
        for _ in 0..<3 {
            app.launch()
            if app.buttons["formulaButton"].waitForExistence(timeout: 15) || app.textFields["babyNameField"].waitForExistence(timeout: 15) {
                launched = true
                break
            }
            app.terminate()
            sleep(3)
        }
        XCTAssertTrue(launched, "3회 재시도 후에도 앱 런치 실패(시뮬레이터 인프라 문제)")

        // 1) 온보딩: 아기가 0마리면 등록 폼이 먼저 뜬다. 이미 등록된 설치라면 건너뛴다.
        let nameField = app.textFields["babyNameField"]
        if nameField.waitForExistence(timeout: 10) {
            nameField.tap()
            nameField.typeText("테스트")
            // 생년월일은 기본값 그대로 사용
            let saveButton = app.buttons["saveBabyButton"]
            XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "저장 버튼 없음")
            saveButton.tap()
        }

        // 2) 홈 진입 확인: 하단 버튼 노출
        let formulaButton = app.buttons["formulaButton"]
        XCTAssertTrue(formulaButton.waitForExistence(timeout: 15), "홈 진입 실패 — 분유 버튼 없음")

        // 3) 분유 기록: 시트 열기 → ml 기본값 확인 → 저장
        formulaButton.tap()

        let amountField = app.textFields["ml"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 15), "분유 ml 입력칸 없음")
        // onAppear에서 lastFormulaML(기본 120)로 세팅될 때까지 폴링
        let defaultValue = waitValue(amountField, expected: "120", timeout: 10)
        XCTAssertEqual(defaultValue, "120", "분유 ml 기본값이 120이 아님: \(defaultValue ?? "nil")")

        let saveFormula = app.buttons["saveFormulaButton"]
        XCTAssertTrue(saveFormula.waitForExistence(timeout: 5), "분유 저장 버튼 없음")
        XCTAssertTrue(saveFormula.isEnabled, "분유 저장 버튼 비활성")
        saveFormula.tap()

        // 4) 타임라인에 새 기록 표시 확인.
        //    우선 식별자로, 없으면 '분유' 라벨을 담은 셀로 재확인.
        let byIdentifier = app.cells["timelineRow"].firstMatch
        let byPredicate = app.cells.containing(
            NSPredicate(format: "label CONTAINS %@", "분유")
        ).firstMatch
        let rowFound = byIdentifier.waitForExistence(timeout: 12) || byPredicate.exists
        XCTAssertTrue(rowFound, "저장 후 타임라인에 새 기록이 표시되지 않음")
    }
}
