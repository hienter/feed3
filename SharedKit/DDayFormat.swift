import Foundation

/// 날짜 표시 포맷 중앙 상수(앱 · 위젯 공용).
/// 뷰에서 DateFormatter를 개별 생성/포맷 지정하지 않도록 한곳에 모은다.
///
/// DateFormatter는 Sendable하지 않아 Swift 6 strict concurrency에서
/// 전역 static let 공유가 불가하므로, 호출 시점에 새로 만드는 팩토리 함수로
/// 제공한다(디데이 라벨 렌더링 빈도에서 비용은 무시할 수준).
enum DDayFormat {
    /// 표시 시간대는 계산 로직(DDayMath)과 동일하게 서울로 고정.
    static let timeZone = TimeZone(identifier: "Asia/Seoul")!
    static let locale = Locale(identifier: "ko_KR")

    /// 기준일 상세 표기: "2026. 10. 23. (금)"
    static func long(_ date: Date) -> String {
        format(date, "yyyy. M. d. (EEE)")
    }

    /// 짧은 표기: "10. 23."
    static func short(_ date: Date) -> String {
        format(date, "M. d")
    }

    private static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = pattern
        formatter.timeZone = timeZone
        formatter.locale = locale
        return formatter.string(from: date)
    }
}
