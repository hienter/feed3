import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Feeding.startedAt, order: .reverse) private var feedings: [Feeding]

    @State private var now = Date()
    @State private var showTimerSheet = false
    @State private var showFormulaSheet = false

    private var activeFeeding: Feeding? {
        feedings.first(where: \.isActive)
    }

    private var lastFinished: Feeding? {
        feedings.first(where: { !$0.isActive })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                timeline
            }
            .background(Color.feed3Background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("수유3초")
                        .font(.system(.headline, design: .serif).weight(.bold))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        StatsView()
                    } label: {
                        Image(systemName: "chart.bar")
                    }
                    .accessibilityLabel("통계")
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionButtons
            }
        }
        .sheet(isPresented: $showTimerSheet) {
            TimerSheet()
        }
        .sheet(isPresented: $showFormulaSheet) {
            FormulaSheet()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
    }

    // MARK: - 상단: 마지막 수유 간격 / 진행중 수유

    private var header: some View {
        VStack(spacing: 6) {
            if let active = activeFeeding {
                // 진행 중 수유: 앱 재시작 후에도 이어서 경과 표시
                VStack(spacing: 4) {
                    Text("지금 수유 중")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.feed3Accent)
                    Text(Feed3Format.elapsedText(from: active.startedAt, to: now))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(Feed3Format.typeLabel(active.type))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if let last = lastFinished {
                VStack(spacing: 4) {
                    Text("마지막 수유")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Feed3Format.relativeGapText(from: last.endedAt ?? last.startedAt, to: now))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 4) {
                    Text("첫 수유를 기록해 보세요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            }
        }
    }

    // MARK: - 오늘 타임라인

    private var timeline: some View {
        let todayFeedings = todayList
        return Group {
            if todayFeedings.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text("오늘 기록이 없습니다")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach(todayFeedings, id: \.id) { feeding in
                            TimelineRow(feeding: feeding, now: now)
                        }
                    } header: {
                        Text("오늘")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var todayList: [Feeding] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        return feedings.filter { $0.startedAt >= start || ($0.endedAt.map { $0 >= start } ?? false) }
    }

    // MARK: - 하단 3버튼

    private var actionButtons: some View {
        HStack(spacing: 12) {
            bigButton(title: "모유", icon: "figure.2.arms.open") {
                showTimerSheet = true
            }
            bigButton(title: "분유", icon: "babybottle") {
                showFormulaSheet = true
            }
            bigButton(title: "유축", icon: "drop.fill") {
                showTimerSheet = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func bigButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 72)
        }
        .buttonStyle(.plain)
        .background(Color.feed3Accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
        .foregroundStyle(Color.feed3Accent)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Feeding.self, Baby.self], inMemory: true)
}
