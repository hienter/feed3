import SwiftUI

/// 라이트 프리미엄 테마: 오프화이트 배경 · 잉크블랙 텍스트 · 포인트 1색.
/// 계층 = 타이포 크기 차이 + 카드(화이트) + 소프트 섀도. 장식 최소.
enum Feed3Theme {
    /// 포인트 컬러 (딥 그린)
    static let accent = Color(red: 0.16, green: 0.45, blue: 0.34)
    /// 오프화이트 배경
    static let background = Color(red: 0.98, green: 0.97, blue: 0.94)
    /// 잉크블랙 텍스트
    static let ink = Color(red: 0.12, green: 0.13, blue: 0.14)
    /// 카드 표면 (퓨어 화이트)
    static let surface = Color.white
    /// 액센트 연한 틴트 (배지/칩 배경)
    static let accentTint = Color(red: 0.16, green: 0.45, blue: 0.34).opacity(0.10)
}

extension Color {
    static let feed3Accent = Feed3Theme.accent
    static let feed3Background = Feed3Theme.background
    static let feed3Ink = Feed3Theme.ink
    static let feed3Surface = Feed3Theme.surface
    static let feed3AccentTint = Feed3Theme.accentTint
}

/// 프리미엄 카드 모디파이어: 화이트 표면 + 라운드 24 + 이중 소프트 섀도.
struct Feed3Card: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Feed3Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
            .shadow(color: Feed3Theme.accent.opacity(0.05), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func feed3Card() -> some View { modifier(Feed3Card()) }
}
