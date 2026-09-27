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
            if app.buttons["formulaButton"].waitForExistence(timeout: 15)
                || app.buttons["welcomeNextButton"].waitForExistence(timeout: 5)
                || app.textFields["babyNameField"].waitForExistence(timeout: 5) {
                launched = true
                break
            }
            // 실패 원인 진단: 계층 텍스트 + 스크린샷을 xcresult에 남긴다
            print("Feed3UIT-diag: launchCount=\(app.launchArguments) state=\(app.state.rawValue)")
            print("Feed3UIT-diag debugDescription:\n\(app.debugDescription.prefix(3000))")
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "launch-failure"
            shot.lifetime = .keepAlways
            add(shot)
            app.terminate()
            sleep(3)
        }
        XCTAssertTrue(launched, "3회 재시도 후에도 앱 런치 실패(시뮬레이터 인프라 문제)")

        // 1) 온보딩: WelcomeView(3페이지) → '다음' 2회 → '기록 시작하기' → 아기 등록 폼.
        //    이미 온보딩이 끝난 설치(재실행)라면 건너뛴다.
        let nextButton = app.buttons["welcomeNextButton"]
        if nextButton.waitForExistence(timeout: 10) {
            nextButton.tap()
            nextButton.tap()
            let startButton = app.buttons["welcomeNextButton"]
            XCTAssertTrue(startButton.waitForExistence(timeout: 5), "시작 버튼 없음")
            // 마지막 페이지에서 문구가 '기록 시작하기'로 바뀐다
            XCTAssertTrue(startButton.label.contains("기록 시작하기"), "마지막 페이지 문구가 '기록 시작하기'가 아님: \(startButton.label)")
            startButton.tap()
        }

        let nameField = app.textFields["babyNameField"]
        if nameField.waitForExistence(timeout: 10) {
            nameField.tap()
            nameField.typeText("테스트")
            // 생년월일은 기본값(오늘) 그대로 사용
            let saveButton = app.buttons["saveBabyButton"]
            XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "저장 버튼 없음")
            XCTAssertEqual(saveButton.label, "완료", "저장 버튼 문구가 '완료'가 아님")
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

    /// 건너뛰기 경로: 두번째 페이지에서 '건너뛰기' → 아기 폼 없이 바로 홈(분유 버튼 노출).
    /// 앞 테스트(testOnboardingAndFormulaRecordFlow)가 온보딩을 완료했을 수 있으므로
    /// 앱을 삭제해 신규 설치 상태로 복원한 뒤 실행한다(WelcomeView가 반드시 떠야 함).
    func testOnboardingSkipGoesStraightHome() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset"]  // 신규 설치 상태 복원(이전 테스트가 온보딩 완료 상태로 남김)
        app.launch()

        let nextButton = app.buttons["welcomeNextButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 15), "WelcomeView 진입 실패")

        // 1페이지엔 건너뛰기 없음 → 다음으로
        nextButton.tap()

        // 2페이지: 우상단 건너뛰기
        let skipButton = app.buttons["welcomeSkipButton"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5), "건너뛰기 버튼 없음")
        skipButton.tap()

        // 기본 아기로 바로 홈 진입 확인 (아기 폼이 아닌 홈이 바로 떠야 한다)
        let nameField = app.textFields["babyNameField"]
        let formulaButton = app.buttons["formulaButton"]
        let homeReached = formulaButton.waitForExistence(timeout: 15)
        XCTAssertFalse(nameField.exists, "건너뛰기 시 아기 등록 폼이 떠서는 안 됨")
        XCTAssertTrue(homeReached, "건너뛰기 후 홈 진입 실패 — 분유 버튼 없음")
    }
}
