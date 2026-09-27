import SwiftUI
import SwiftData

@main
struct Feed3App: App {

    /// CloudKit 자동 동기화 시도, 실패 시 로컬 전용 폴백.
    /// - 현재 배포 프로비저닝 프로파일에 iCloud capability가 없어 entitlements는
    ///   빈 dict로 유지한다(아카이브 실패 폴백, 2026-09 기준). iCloud capability가
    ///   추가되면 entitlements에 icloud-services(CloudKit)/containers(iCloud.hienter.feed3)를
    ///   복원할 것.
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
