import SwiftUI
import SwiftData

@main
struct Feed3App: App {

    /// CloudKit 자동 동기화 시도, 실패 시 로컬 전용 폴백.
    /// - 이름 없는 ModelConfiguration을 써서 기본 default.store 위치를 유지한다
    ///   (기존 데이터 호환 — 이름 있는 store는 새 파일이 되어 마이그레이션 발생).
    /// - 현재 배포 프로비저닝 프로파일에 iCloud capability가 없어 entitlements는
    ///   빈 dict로 유지한다(아카이브 실패 폴백, 2026-09 기준). iCloud capability가
    ///   추가되면 entitlements에 icloud-services(CloudKit)/containers(iCloud.hienter.feed3)를
    ///   복원할 것.
    /// - 로컬 우선 원칙: CloudKit 사용 불가(CI 무서명, iCloud 미로그인, entitlement 누락)해도
    ///   앱의 모든 기능은 로컬 SwiftData로 정상 동작해야 한다(출시 블록 아님).
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([Feeding.self, Baby.self])

        // 신규 설치 시 Application Support 디렉토리가 없으면 addPersistentStore가
        // "Failed to create file (code 2)"로 실패하며 앱이 런치 직후 죽는다.
        // 컨테이너 생성 전에 디렉토리를 보장한다.
        let supportDir = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first
        if let dir = supportDir {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        do {
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            #if DEBUG
            print("Feed3: CloudKit container init failed, falling back to local. \(error)")
            #endif
            do {
                return try ModelContainer(
                    for: schema,
                    configurations: [ModelConfiguration(schema: schema)]
                )
            } catch {
                fatalError("Feed3: local SwiftData container init failed: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .modelContainer(Self.sharedContainer)
                .task {
                    // UI 테스트용: XCUIApplication.delete()가 없는 환경에서
                    // 신규 설치 상태를 재현하기 위한 리셋 런치 아규먼트.
                    if ProcessInfo.processInfo.arguments.contains("-uitest-reset") {
                        Self.resetForUITest(Self.sharedContainer)
                    }
                }
        }
    }

    @MainActor
    static let sharedContainer: ModelContainer = makeContainer()

    /// 온보딩/기록/아기 데이터를 전부 지워 신규 설치와 동일한 상태로 만든다.
    @MainActor
    private static func resetForUITest(_ container: ModelContainer) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Baby.onboardingCompletedKey)
        defaults.removeObject(forKey: "homeTipShown")
        defaults.removeObject(forKey: "currentBabyID")
        let context = ModelContext(container)
        let feedings = (try? context.fetch(FetchDescriptor<Feeding>())) ?? []
        feedings.forEach(context.delete)
        let babies = (try? context.fetch(FetchDescriptor<Baby>())) ?? []
        babies.forEach(context.delete)
        try? context.save()
    }
}
