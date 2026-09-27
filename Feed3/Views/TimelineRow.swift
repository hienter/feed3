import SwiftUI
import SwiftData

/// 타임라인 한 줄: 시각 · 타입 · 지속시간/ml 표시.
struct TimelineRow: View {
    let feeding: Feeding
    let now: Date

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(Feed3Format.typeLabel(feeding.type))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.feed3Ink)
                Text(timeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            detailText
                .font(.system(.body, design: .rounded).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(feeding.isActive ? Color.feed3Accent : Color.feed3Ink)
        }
        .padding(.vertical, 2)
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
            // 진행 중: 시작 기준 경과시간 실시간 표시
            Text(Feed3Format.elapsedText(from: feeding.startedAt, to: now))
        } else if let seconds = feeding.finishedDurationSeconds {
            Text(Feed3Format.durationText(seconds: seconds))
        } else {
            EmptyView()
        }
    }
}
