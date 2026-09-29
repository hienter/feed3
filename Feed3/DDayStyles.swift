import SwiftUI

/// 스타일 모듈: 뷰는 구조만 남기고 타이포·간격·포맷은 이곳 상수로 관리한다(스타일 = 모듈).
/// iOS 기본 컴포넌트(List, DatePicker 등)의 시스템 프리셋만 사용하며,
/// 커스텀 폰트·커스텀 배경·그라데이션·하드코딩 폰트 크기는 금지(사용자 확정 규칙).
enum DDayStyles {

    // MARK: - 레이아웃 상수

    /// 넓은 화면(iPhone Duo 내부 7.6″ 등 regular 폭 화면)에서 목록 본문이
    /// 무한히 퍼지지 않도록 제한하는 최대 폭. 일반 아이폰(≤440pt)에서는 미적용.
    static let contentMaxWidth: CGFloat = 520

    enum Row {
        static let title: Font = .title3.weight(.semibold)
        static let detail: Font = .subheadline
        static let badge: Font = .title2
        static let textSpacing: CGFloat = 4
        static let spacerMin: CGFloat = 12
    }

    enum EmptyState {
        static let icon: Font = .largeTitle
        static let title: Font = .headline
        static let detail: Font = .subheadline
        static let spacing: CGFloat = 12
        static let verticalPadding: CGFloat = 32
    }

    // MARK: - ViewModifier

    /// 목록/본문 컨테이너 공용: 가운데 정렬 + 최대 폭 제한.
    /// width가 max보다 큰 화면(폴더블 내부 화면)에서만 실질적으로 동작한다.
    struct ConstrainedWidth: ViewModifier {
        var isActive: Bool

        func body(content: Content) -> some View {
            if isActive {
                content
                    .frame(maxWidth: DDayStyles.contentMaxWidth)
                    .frame(maxWidth: .infinity)
            } else {
                content
            }
        }
    }

    /// 디데이 목록 행(List row) 프리셋.
    struct RowStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
        }
    }

    /// 폼 섹션 헤더/푸터 문구 프리셋(시스템 대문자 변환 끔).
    struct SectionCaption: ViewModifier {
        func body(content: Content) -> some View {
            content.textCase(nil)
        }
    }
}

extension View {
    /// horizontalSizeClass가 regular인 폭 넓은 화면에서만 본문 폭을 제한한다.
    func ddayConstrainedWidth(_ isActive: Bool) -> some View {
        modifier(DDayStyles.ConstrainedWidth(isActive: isActive))
    }

    /// 목록 행 프리셋 적용.
    func ddayRow() -> some View {
        modifier(DDayStyles.RowStyle())
    }

    /// 폼 섹션 헤더 문구 프리셋 적용.
    func ddaySectionCaption() -> some View {
        modifier(DDayStyles.SectionCaption())
    }
}
