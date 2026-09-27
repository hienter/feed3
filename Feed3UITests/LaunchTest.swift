import XCTest

/// E2E: 런치 → 온보딩(아기 등록) → 분유 기록 → 타임라인 표시 확인.
/// 신규 설치 상태를 가정하되, 기존 상태(온보딩 완료)에서도 통과하도록 온보딩 단계는 조건부로 수행한다.
final class LaunchTest: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingAndFormulaRecordFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // 1) 온보딩: 아기가 0마리면 등록 폼이 먼저 뜬다. 이미 등록된 설치라면 건너뛴다.
        let nameField = app.textFields["babyNameField"]
        if nameField.waitForExistence(timeout: 5) {
            nameField.tap()
            nameField.typeText("테스트")
            // 생년월일은 기본값 그대로 사용
            let saveButton = app.buttons["saveBabyButton"]
            XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "저장 버튼 없음")
            saveButton.tap()
        }

        // 2) 홈 진입 확인: 하단 버튼 노출
        let formulaButton = app.buttons["formulaButton"]
        XCTAssertTrue(formulaButton.waitForExistence(timeout: 10), "홈 진입 실패 — 분유 버튼 없음")

        // 3) 분유 기록: 시트 열기 → ml 기본값 확인 → 저장
        formulaButton.tap()

        let amountField = app.textFields["ml"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 10), "분유 ml 입력칸 없음")
        let defaultValue = amountField.value as? String
        XCTAssertEqual(defaultValue, "120", "분유 ml 기본값이 120이 아님: \(defaultValue ?? "nil")")

        let saveFormula = app.buttons["saveFormulaButton"]
        XCTAssertTrue(saveFormula.waitForExistence(timeout: 5), "분유 저장 버튼 없음")
        saveFormula.tap()

        // 4) 타임라인에 새 기록 표시 확인
        let row = app.descendants(matching: .any).matching(identifier: "timelineRow").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "저장 후 타임라인에 새 기록이 표시되지 않음")
    }
}
