import SwiftUI
import SwiftData

/// 타임라인 한 줄: 시각 · 타입 · ml 배지/지속시간.
/// 계층: 타입(잉크 semibold) → 시각(caption secondary) → ml 배지(액센트 틴트).
struct TimelineRow: View {
    let feeding: Feeding
    let now: Date

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Feed3Format.typeLabel(feeding.type))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.feed3Ink)
                Text(timeText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            Spacer(minLength: 8)
            detailText
        }
        .padding(.vertical, 3)
    }

    private var timeText: String {
        let start = feeding.startedAt.formatted(date: .omitted, time: .shortened)
        if let end = feeding.endedAt {
            return "\(start) – \(end.formatted(date: .omitted, time: .shortened))"
        }
        return start
    }

    @ViewBuilder
    private var detailText: some View {
        if feeding.isActive {
            // 진행 중: 시작 기준 경과시간 실시간 표시 (액센트)
            Text(Feed3Format.elapsedText(from: feeding.startedAt, to: now))
                .font(.system(.body, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.feed3Accent)
        } else if let ml = feeding.amountML, feeding.type.isFormula || feeding.type.isPump {
            // 분유·유축 ml: 배지로 강조
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(ml)")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text("ml")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.feed3Accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.feed3AccentTint, in: Capsule())
        } else if let seconds = feeding.finishedDurationSeconds {
            // 모유 등: 지속시간만
            Text(Feed3Format.durationText(seconds: seconds))
                .font(.system(.body, design: .rounded).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Color.feed3Ink)
        } else {
            EmptyView()
        }
    }
}
