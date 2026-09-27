import SwiftUI

/// 온보딩 완주율 로깅. 로컬 print만 사용(Analytics 미연동). 나중에 집계를 위해 [ONBOARD] 태그 통일.
enum OnboardingEvent: String {
    case welcomeViewed = "welcome_viewed"
    case welcomeSkipped = "welcome_skipped"
    case formViewed = "form_viewed"
    case formCompleted = "form_completed"

    static func log(_ event: OnboardingEvent) {
        print("[ONBOARD] \(event.rawValue)")
    }
}

/// 3페이지 풀 온보딩: p1 가치 제안 → p2 아기 정보 안내 → p3 기록 흐름 미리보기.
/// 하단 '다음'/'기록 시작하기' 풀버튼 + 2페이지부터 우상단 '건너뛰기'.
struct WelcomeView: View {
    /// 완료(마지막 페이지) 시 호출 — HomeView에서 BabyFormSheet(isOnboarding: true)로 이어진다.
    var onComplete: () -> Void
    /// 건너뛰기 시 호출 — 기본 아기 생성 후 바로 홈.
    var onSkip: () -> Void

    @State private var page = 0
    @State private var previewType: FeedType?
    private let pageCount = 3

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                TabView(selection: $page) {
                    welcomePage(
                        icon: "hand.tap.fill",
                        title: "수유 기록, 이제 한 손으로",
                        message: "버튼 한 번이면 기록이 끝나요. 새벽에 눈 뜨고도 쓸 수 있어요."
                    )
                    .tag(0)

                    welcomePage(
                        icon: "figure.2.and.child",
                        title: "왜 아기 정보를 물어볼까요?",
                        message: "생년월일을 알면 수유량이 적당한지 알려줄 수 있어요. 입력은 10초, 나중에 언제든 고칠 수 있어요."
                    )
                    .tag(1)

                    previewPage
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .accessibilityIdentifier("welcomePages")

                if page > 0 {
                    Button("건너뛰기") {
                        OnboardingEvent.log(.welcomeSkipped)
                        onSkip()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .accessibilityIdentifier("welcomeSkipButton")
                }
            }

            // 하단 풀폭 액션: 마지막 페이지에서만 '기록 시작하기'
            Button {
                if page >= pageCount - 1 {
                    OnboardingEvent.log(.formViewed)
                    onComplete()
                } else {
                    withAnimation { page += 1 }
                }
            } label: {
                Text(page >= pageCount - 1 ? "기록 시작하기" : "다음")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .background(Color.feed3Accent, in: RoundedRectangle(cornerRadius: 18))
            .foregroundStyle(Color.feed3Background)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .accessibilityIdentifier("welcomeNextButton")
        }
        .background(Color.feed3Background.ignoresSafeArea())
        .onAppear {
            OnboardingEvent.log(.welcomeViewed)
        }
    }

    // MARK: - 공통 페이지 레이아웃

    private func welcomePage(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(Color.feed3Accent)
                .padding(28)
                .background(Color.feed3Accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
            Text(title)
                .font(.system(.title, design: .serif).weight(.bold))
                .foregroundStyle(Color.feed3Ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - p3: 기록 흐름 미리보기 (모유/분유/유축 — 장식용, 탭해도 온보딩 종료 아님)

    private var previewPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("기록은 이렇게 흘러가요")
                .font(.system(.title, design: .serif).weight(.bold))
                .foregroundStyle(Color.feed3Ink)
                .multilineTextAlignment(.center)
            Text("홈 하단 버튼을 누르면 바로 기록돼요.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                previewButton(title: "모유", icon: "figure.2.arms.open", type: .breastLeft)
                previewButton(title: "분유", icon: "babybottle", type: .formula)
                previewButton(title: "유축", icon: "drop.fill", type: .pumpLeft)
            }
            .padding(.horizontal, 8)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func previewButton(title: String, icon: String, type: FeedType) -> some View {
        Button {
            // 선택 피드백만 — 온보딩 종료 신호가 아니다.
            previewType = type
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 72)
        }
        .buttonStyle(.plain)
        .background(
            (previewType == type ? Color.feed3Accent.opacity(0.22) : Color.feed3Accent.opacity(0.10)),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .foregroundStyle(Color.feed3Accent)
        .accessibilityIdentifier("welcomePreview_\(title)")
    }
}

#Preview {
    WelcomeView(onComplete: {}, onSkip: {})
}
