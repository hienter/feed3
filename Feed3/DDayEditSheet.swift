import SwiftUI

/// 디데이 추가/편집 시트. 새 항목(item == nil)이면 오늘 기준 기본값으로 시작한다.
struct DDayEditSheet: View {
    /// 편집 대상. nil이면 새로 만들기.
    let item: DDayItem?

    @Environment(DDayStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var recurrence: DDayRecurrence = .none

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("제목", text: $title)
                        .accessibilityIdentifier("titleField")
                    DatePicker(
                        "날짜",
                        selection: $date,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .accessibilityIdentifier("datePicker")
                } header: {
                    Text("디데이")
                        .ddaySectionCaption()
                }

                Section {
                    Picker("반복", selection: $recurrence) {
                        ForEach(DDayRecurrence.allCases, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("recurrencePicker")
                } header: {
                    Text("반복")
                        .ddaySectionCaption()
                } footer: {
                    Text("매년을 선택하면 같은 날짜가 올해/내년으로 자동 계산됩니다.")
                        .ddaySectionCaption()
                }
            }
            .navigationTitle(item == nil ? "새 디데이" : "편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                        .accessibilityIdentifier("cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("saveButton")
                }
            }
            .onAppear(perform: loadInitialValues)
        }
        .presentationDetents([.large])
    }

    private func loadInitialValues() {
        guard let item else {
            date = DDayMath.startOfDay(Date())
            return
        }
        title = item.title
        date = item.date
        recurrence = item.recurrence
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalizedDate = DDayMath.startOfDay(date)
        let updated = DDayItem(
            id: item?.id ?? UUID(),
            title: trimmed,
            date: normalizedDate,
            recurrence: recurrence,
            createdAt: item?.createdAt ?? Date()
        )
        store.upsert(updated)
        dismiss()
    }
}
