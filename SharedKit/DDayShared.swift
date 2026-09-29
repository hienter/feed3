import Foundation

/// 메인 앱 ↔ 위젯 확장 데이터 공유 계층.
///
/// 저장 방식으로 JSON 파일 + Codable을 선택한 이유:
/// - 데이터가 단일 배열(디데이 항목 목록)이라 관계형 모델이 필요 없다.
/// - SwiftData/SQLite 대비 의존성·마이그레이션 부담이 없고, 파일 하나를
///   App Group 컨테이너에 두기만 하면 위젯 확장이 동일 코드로 읽을 수 있다.
/// - 저장 시점은 사용자 편집(add/update/delete)뿐이라 쓰기 빈도가 낮아
///   파일 전체 재작성으로 충분하다(atomic write로 손상 방지).
enum DDayShared {

    /// 메인 앱과 위젯 확장이 공유하는 App Group.
    /// App Store 등록 시 TeamID(SME94477V2) 계정에 동일 ID로 등록해야 한다.
    static let appGroupID = "group.com.hienter.feed3.dday"

    /// App Group 컨테이너 안의 공유 JSON 파일명.
    static let fileName = "dday-items.json"

    /// App Group 컨테이너 URL. App Group을 못 쓰는 환경(시뮬레이터 일부,
    /// 단위 테스트, 서명 없는 실행)에서는 Documents로 폴백한다 —
    /// 위젯 공유는 불가하지만 앱 자체 기능은 정상 동작한다(로컬 우선 원칙).
    static func containerDirectory(fileManager: FileManager = .default) -> URL {
        if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return groupURL
        }
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// 지정 디렉토리 기준 공유 JSON 파일 URL.
    static func fileURL(directory: URL) -> URL {
        directory.appendingPathComponent(fileName)
    }

    /// 목록 로드. 파일이 없거나 손상돼 파싱에 실패하면 빈 배열로 복구한다
    /// (부실 데이터 때문에 앱/위젯이 크래시하는 것을 막는다).
    static func load(directory: URL, fileManager: FileManager = .default) -> [DDayItem] {
        guard let data = try? Data(contentsOf: fileURL(directory: directory)) else { return [] }
        do {
            return try makeDecoder().decode([DDayItem].self, from: data)
        } catch {
            return []
        }
    }

    /// 목록 저장. 디렉토리가 없으면 만들고, 임시 파일 → 원자적 교체로 쓴다.
    static func save(_ items: [DDayItem], directory: URL, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try makeEncoder().encode(items)
        try data.write(to: fileURL(directory: directory), options: .atomic)
    }

    /// 공유 파일 삭제(UI 테스트 리셋용).
    static func removeAll(directory: URL, fileManager: FileManager = .default) {
        try? fileManager.removeItem(at: fileURL(directory: directory))
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
