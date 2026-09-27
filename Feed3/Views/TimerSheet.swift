import SwiftUI
import SwiftData

/// 모유/유축용 타이머 시트.
/// 시작 → Feeding insert(endedAt: nil), 종료 → endedAt = now 저장.
struct TimerSheet: View {
    enum Mode: String, CaseIterable, Identifiable {
        case breast
        case pump
        var id: String { rawValue }
    }

    enum Side: String, CaseIterable, Identifiable {
        case left
        case right
        var id: String { rawValue }

        var label: String { self == .left ? "왼쪽" : "오른쪽" }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var feedings: [Feeding]
    @Query private var babies: [Baby]

    @AppStorage(BabiesView.currentBabyIDKey) private var currentBabyID: String = ""

    @State private var mode: Mode = .breast
    @State private var side: Side = .left
    @State private var now = Date()

    private var currentBaby: Baby? {
        Baby.current(from: babies, appStorage: currentBabyID)
    }

    private var activeFeeding: Feeding? {
        feedings.first(where: \.isActive)
    }

    private var feedType: FeedType {
        switch (mode, side) {
        case (.breast, .left): return .breastLeft
        case (.breast, .right): return .breastRight
        case (.pump, .left): return .pumpLeft
        case (.pump, .right): return .pumpRight
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Picker("종류", selection: $mode) {
                    Text("모유").tag(Mode.breast)
                    Text("유축").tag(Mode.pump)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                Picker("방향", selection: $side) {
                    ForEach(Side.allCases) { side in
                        Text(side.label).tag(side)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                Spacer()

                if let active = activeFeeding {
                    Text(Feed3Format.elapsedText(from: active.startedAt, to: now))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                } else {
                    Text("00:00")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    activeFeeding == nil ? start() : stop()
                } label: {
                    Text(activeFeeding == nil ? "시작" : "종료")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.plain)
                .foregroundStyle(activeFeeding == nil ? .white : Color.feed3Accent)
                .background(
                    activeFeeding == nil ? AnyShapeStyle(Color.feed3Accent) : AnyShapeStyle(Color.feed3Accent.opacity(0.12)),
                    in: RoundedRectangle(cornerRadius: 20)
                )
                .padding(.horizontal, 20)
                .animation(.easeInOut(duration: 0.15), value: activeFeeding == nil)
            }
            .padding(.vertical, 20)
            .background(Color.feed3Background)
            .navigationTitle("수유 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
    }

    private func start() {
        let feeding = Feeding(type: feedType, startedAt: Date(), endedAt: nil, baby: currentBaby)
        modelContext.insert(feeding)
        try? modelContext.save()
    }

    private func stop() {
        guard let active = activeFeeding else { return }
        active.endedAt = Date()
        try? modelContext.save()
    }
}
