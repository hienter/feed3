import SwiftUI

/// 라이트 프리미엄 테마: 오프화이트 배경 · 잉크블랙 텍스트 · 포인트 1색.
enum Feed3Theme {
    /// 포인트 컬러 (딥 그린)
    static let accent = Color(red: 0.16, green: 0.45, blue: 0.34)
    /// 오프화이트 배경
    static let background = Color(red: 0.98, green: 0.97, blue: 0.94)
    /// 잉크블랙 텍스트
    static let ink = Color(red: 0.12, green: 0.13, blue: 0.14)
}

extension Color {
    static let feed3Accent = Feed3Theme.accent
    static let feed3Background = Feed3Theme.background
    static let feed3Ink = Feed3Theme.ink
}
