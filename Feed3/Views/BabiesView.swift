import SwiftUI
import SwiftData

/// 아기 목록·추가·전환 화면.
/// 현재 아기는 @AppStorage("currentBabyID")에 UUID 문자열로 저장하고,
/// 저장소의 Baby와 대조해 유효할 때만 사용한다.
struct BabiesView: View {
    static let currentBabyIDKey = "currentBabyID"

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @AppStorage(BabiesView.currentBabyIDKey) private var currentBabyID: String = ""

    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(babies) { baby in
                    Button {
                        currentBabyID = baby.id.uuidString
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(baby.name)
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                                Text("생일 \(baby.birthDate.formatted(date: .numeric, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if baby.id.uuidString == currentBabyID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.feed3Accent)
                            }
                        }
                    }
                    .foregroundStyle(Color.feed3Ink)
                    .accessibilityIdentifier("baby_\(baby.name)")
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("아기 관리")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("addBaby")
                }
            }
            .sheet(isPresented: $showAddSheet) {
                BabyFormSheet()
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let baby = babies[index]
            // 현재 아기가 삭제되면 선택 해제 (기록의 baby는 nil로 남는다)
            if baby.id.uuidString == currentBabyID {
                currentBabyID = ""
            }
            modelContext.delete(baby)
        }
        try? modelContext.save()
    }
}

/// 아기 추가 폼: 이름 + 생년월일. 온보딩과 추가 모두에서 재사용.
struct BabyFormSheet: View {
    /// 온보딩 모드: 저장 후 이 값이 true로 바뀌어 첫 실행 화면이 사라진다.
    var isOnboarding = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(BabiesView.currentBabyIDKey) private var currentBabyID: String = ""
    @AppStorage(Baby.onboardingCompletedKey) private var onboardingCompleted = false

    @State private var name = ""
    @State private var birthDate = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("아기 정보") {
                    TextField("이름", text: $name)
                        .accessibilityIdentifier("babyNameField")
                    DatePicker(
                        "생년월일",
                        selection: $birthDate,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("birthDatePicker")
                }
                .accessibilityIdentifier("onboardingForm")

                Button {
                    save()
                } label: {
                    Text("저장")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("saveBabyButton")
            }
            .navigationTitle(isOnboarding ? "아기 등록" : "아기 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isOnboarding {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("닫기") { dismiss() }
                    }
                }
            }
        }
        .interactiveDismissDisabled(isOnboarding)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let baby = Baby(name: trimmed, birthDate: birthDate)
        modelContext.insert(baby)
        currentBabyID = baby.id.uuidString
        onboardingCompleted = true
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - 현재 아기 헬퍼

extension Baby {
    static let onboardingCompletedKey = "onboardingCompleted"

    /// 저장소에서 현재 선택된 아기를 찾는다. 없거나 삭제된 경우 nil.
    @MainActor
    static func current(from babies: [Baby], appStorage currentBabyID: String) -> Baby? {
        guard !currentBabyID.isEmpty else { return nil }
        return babies.first(where: { $0.id.uuidString == currentBabyID })
    }
}

// TODO: CKShare 공유 (2차) — 부부 공유(UDbC)는 1차 범위 밖. CloudKit 공유 DB + CKShare + UICloudSharingController 연계 예정.
