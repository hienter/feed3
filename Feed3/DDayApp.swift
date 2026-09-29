import SwiftUI

@main
struct DDayApp: App {
    @State private var store = DDayStore()

    var body: some Scene {
        WindowGroup {
            DDayListView()
                .environment(store)
            // UI 테스트용: 기존 설치 데이터를 지우고 신규 설치 상태를 재현한다.
                .task {
                    if ProcessInfo.processInfo.arguments.contains("-uitest-reset") {
                        DDayStore.resetForUITest()
                    }
                }
        }
    }
}
