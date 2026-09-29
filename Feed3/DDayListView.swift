import SwiftUI

/// 디데이 목록 화면. iOS 기본 컴포넌트(List + insetGrouped, NavigationStack)만 사용.
struct DDayListView: View {
    @Environment(DDayStore.self) private var store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var editingItem: DDayItem?
    @State private var isShowingNewSheet = false

    /// 반복을 반영한 가까운 순(다음 날짜 오름차순) 목록.
    private var sortedItems: [DDayItem] {
        DDayMath.sorted(store.items)
    }

    var body: some View {
        NavigationStack {
            List {
                if store.items.isEmpty {
                    EmptyStateSection()
                } else {
                    ForEach(sortedItems) { item in
                        DDayRow(item: item)
                            .ddayRow()
                            .accessibilityIdentifier("ddayCard")
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    store.remove(item)
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                                Button {
                                    editingItem = item
                                } label: {
                                    Label("편집", systemImage: "pencil")
                                }
                            }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .ddayConstrainedWidth(horizontalSizeClass == .regular)
            .navigationTitle("디데이")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingNewSheet = true
                    } label: {
                        Label("추가", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addButton")
                }
            }
            .sheet(isPresented: $isShowingNewSheet) {
                DDayEditSheet(item: nil)
            }
            .sheet(item: $editingItem) { item in
                DDayEditSheet(item: item)
            }
        }
    }
}

/// 목록 행: 제목(최우선 가독) + 남은/지난 일수 + 기준일 요약.
private struct DDayRow: View {
    let item: DDayItem

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: DDayStyles.Row.textSpacing) {
                Text(item.title)
                    .font(DDayStyles.Row.title)
                Text(DDayFormat.long(item.date))
                    .font(DDayStyles.Row.detail)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: DDayStyles.Row.spacerMin)
            Text(DDayMath.ddayLabel(target: DDayMath.nextOccurrence(of: item.date, recurrence: item.recurrence)))
                .font(DDayStyles.Row.badge)
                .monospacedDigit()
                .foregroundStyle(.tint)
        }
        .contentShape(Rectangle())
    }
}

/// 빈 상태: 첫 사용자 안내.
private struct EmptyStateSection: View {
    var body: some View {
        Section {
            VStack(spacing: DDayStyles.EmptyState.spacing) {
                Image(systemName: "calendar.badge.plus")
                    .font(DDayStyles.EmptyState.icon)
                    .foregroundStyle(.tint)
                Text("디데이를 추가하세요")
                    .font(DDayStyles.EmptyState.title)
                Text("생일, 시험, 여행 등 중요한 날까지 남은 일수를 한눈에 보여 드립니다.")
                    .font(DDayStyles.EmptyState.detail)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DDayStyles.EmptyState.verticalPadding)
        }
        .accessibilityIdentifier("emptyState")
    }
}
