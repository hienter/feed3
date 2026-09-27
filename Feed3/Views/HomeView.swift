import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Feeding.startedAt, order: .reverse) private var feedings: [Feeding]
    @Query(sort: \Baby.createdAt) private var babies: [Baby]

    @AppStorage(BabiesView.currentBabyIDKey) private var currentBabyID: String = ""
    @AppStorage(Baby.onboardingCompletedKey) private var onboardingCompleted = false

    @State private var now = Date()
    @State private var showTimerSheet = false
    @State private var showFormulaSheet = false
    @State private var editing: Feeding?

    /// 현재 아기: @AppStorage의 UUID 문자열을 저장소와 대조. 없으면 nil(기록은 baby nil).
    private var currentBaby: Baby? {
        Baby.current(from: babies, appStorage: currentBabyID)
    }

    private var activeFeeding: Feeding? {
        feedings.first(where: \.isActive)
    }

    private var lastFinished: Feeding? {
        feedings.first(where: { !$0.isActive })
    }

    var body: some View {
        NavigationStack {
            // 첫 실행 온보딩: 아기가 0마리면 홈 대신 등록 폼(기록에 baby 연결 필요)
            if onboardingCompleted && !babies.isEmpty {
                homeContent
            } else {
                BabyFormSheet(isOnboarding: true)
            }
        }
        .sheet(isPresented: $showTimerSheet) {
            TimerSheet()
        }
        .sheet(isPresented: $showFormulaSheet) {
            FormulaSheet()
        }
        .sheet(item: $editing) { feeding in
            RecordEditSheet(feeding: feeding)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
    }

    private var homeContent: some View {
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
                HStack(spacing: 4) {
                    NavigationLink {
                        BabiesView()
                    } label: {
                        Image(systemName: "person.2")
                    }
                    .accessibilityIdentifier("babiesNav")
                    NavigationLink {
                        StatsView()
                    } label: {
                        Image(systemName: "chart.bar")
                    }
                    .accessibilityLabel("통계")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            actionButtons
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

    // MARK: - 타임라인 (오늘/어제/그제 섹션 + 스와이프 수정/삭제)

    private var timeline: some View {
        let sections = daySections
        return Group {
            if sections.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text("기록이 없습니다")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sections, id: \.title) { section in
                        Section {
                            ForEach(section.feedings, id: \.id) { feeding in
                                TimelineRow(feeding: feeding, now: now)
                                    .accessibilityIdentifier("timelineRow")
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        // 삭제: 확인 다이얼로그 없이 즉시 — 속도가 정체성
                                        Button(role: .destructive) {
                                            delete(feeding)
                                        } label: {
                                            Label("삭제", systemImage: "trash")
                                        }
                                        Button {
                                            editing = feeding
                                        } label: {
                                            Label("수정", systemImage: "pencil")
                                        }
                                        .tint(Color.feed3Accent)
                                    }
                            }
                        } header: {
                            Text(section.title)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }

    struct DaySection {
        let title: String
        let feedings: [Feeding]
    }

    /// 최근 3일(오늘/어제/그제) 섹션. 각 섹션은 최신순.
    private var daySections: [DaySection] {
        let calendar = Calendar.current
        let titles = ["오늘", "어제", "그제"]
        var sections: [DaySection] = []
        for (offset, title) in titles.enumerated() {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let start = calendar.startOfDay(for: day)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { continue }
            // 종료 시점 기준으로 귀속(자정 걸친 수유 포함). 진행 중은 시작 시점 기준.
            let inDay = feedings.filter { feeding in
                if feeding.isActive { return feeding.startedAt >= start && feeding.startedAt < end }
                guard let endedAt = feeding.endedAt else { return false }
                return endedAt >= start && endedAt < end
            }
            if !inDay.isEmpty {
                sections.append(DaySection(title: title, feedings: inDay))
            }
        }
        return sections
    }

    private func delete(_ feeding: Feeding) {
        modelContext.delete(feeding)
        try? modelContext.save()
    }

    // MARK: - 하단 3버튼

    private var actionButtons: some View {
        HStack(spacing: 12) {
            bigButton(title: "모유", icon: "figure.2.arms.open", id: "breastButton") {
                showTimerSheet = true
            }
            bigButton(title: "분유", icon: "babybottle", id: "formulaButton") {
                showFormulaSheet = true
            }
            bigButton(title: "유축", icon: "drop.fill", id: "pumpButton") {
                showTimerSheet = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func bigButton(title: String, icon: String, id: String, action: @escaping () -> Void) -> some View {
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
        .accessibilityIdentifier(id)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Feeding.self, Baby.self], inMemory: true)
}
