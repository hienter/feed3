import SwiftUI
import SwiftData

@main
struct Feed3App: App {

    /// CloudKit 자동 동기화 시도, 실패 시 로컬 전용 폴백.
    /// - CloudKit를 쓰는 이유: 기기 간 동기화(iCloud.hienter.feed3)
    /// - 로컬 우선 원칙: CloudKit 사용 불가(CI 무서명, iCloud 미로그인, entitlement 누락)해도
    ///   앱의 모든 기능은 로컬 SwiftData로 정상 동작해야 한다(출시 블록 아님).
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([Feeding.self, Baby.self])
        do {
            let config = ModelConfiguration(
                "Feed3",
                schema: schema,
                cloudKitDatabase: .automatic
            )
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            #if DEBUG
            print("Feed3: CloudKit container init failed, falling back to local. \(error)")
            #endif
            do {
                return try ModelContainer(
                    for: schema,
                    configurations: [ModelConfiguration("Feed3", schema: schema)]
                )
            } catch {
                fatalError("Feed3: local SwiftData container init failed: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(Self.makeContainer())
    }
}
