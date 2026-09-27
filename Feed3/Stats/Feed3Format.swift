import Foundation

/// UI 표시용 시간 포맷 헬퍼. 순수 함수로만 구성해 테스트 대상으로 삼는다.
enum Feed3Format {

    /// "2시간 15분 전" / "15분 전" / "방금" 형태의 상대 시간 문구.
    static func relativeGapText(from date: Date, to now: Date) -> String {
        let gap = max(0, now.timeIntervalSince(date))
        let totalMinutes = Int(gap / 60)
        if totalMinutes < 1 { return "방금" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes)분 전" }
        if minutes == 0 { return "\(hours)시간 전" }
        return "\(hours)시간 \(minutes)분 전"
    }

    /// 진행 중 수유 경과시간: "12:34" (mm:ss, 1시간 이상이면 h:mm:ss)
    static func elapsedText(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return clockText(seconds: seconds)
    }

    /// 종료된 수유 지속시간: "12분" / "1시간 5분"
    static func durationText(seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        if totalMinutes < 1 { return "1분 미만" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes)분" }
        if minutes == 0 { return "\(hours)시간" }
        return "\(hours)시간 \(minutes)분"
    }

    /// mm:ss / h:mm:ss 시계 문자열
    static func clockText(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    /// FeedType의 한국어 라벨
    static func typeLabel(_ type: FeedType) -> String {
        switch type {
        case .breastLeft: return "모유 · 왼쪽"
        case .breastRight: return "모유 · 오른쪽"
        case .formula: return "분유"
        case .pumpLeft: return "유축 · 왼쪽"
        case .pumpRight: return "유축 · 오른쪽"
        }
    }
}
