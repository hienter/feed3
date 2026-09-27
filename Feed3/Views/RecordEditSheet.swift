import SwiftUI
import SwiftData

/// 기록 수정 시트: 시각(DatePicker) · 분량 · 타입 편집 후 저장.
struct RecordEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// 수정 대상. 시트가 닫힌 뒤에도 안전하게 편집할 수 있도록 id로 보관했다가 다시 fetch한다.
    @Query private var allFeedings: [Feeding]
    private let feedingID: UUID

    @State private var type: FeedType = .formula
    @State private var startedAt = Date()
    @State private var endedAt: Date?
    @State private var amountText: String = ""
    @State private var loaded = false

    init(feeding: Feeding) {
        self.feedingID = feeding.id
        _allFeedings = Query()
    }

    private var feeding: Feeding? {
        allFeedings.first(where: { $0.id == feedingID })
    }

    private var showsAmount: Bool {
        type.isFormula || type.isPump
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("종류") {
                    Picker("종류", selection: $type) {
                        Text("모유 · 왼쪽").tag(FeedType.breastLeft)
                        Text("모유 · 오른쪽").tag(FeedType.breastRight)
                        Text("분유").tag(FeedType.formula)
                        Text("유축 · 왼쪽").tag(FeedType.pumpLeft)
                        Text("유축 · 오른쪽").tag(FeedType.pumpRight)
                    }
                    .pickerStyle(.menu)
                }

                Section("시각") {
                    DatePicker("시작", selection: $startedAt)
                    if let end = Binding($endedAt) {
                        DatePicker("종료", selection: end)
                    }
                }

                if showsAmount {
                    Section("분량") {
                        HStack {
                            TextField("ml", text: $amountText)
                                .keyboardType(.numberPad)
                                .monospacedDigit()
                            Text("ml")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("기록 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") { save() }
                        .font(.body.weight(.semibold))
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded, let feeding else { return }
        type = feeding.type
        startedAt = feeding.startedAt
        endedAt = feeding.endedAt
        amountText = feeding.amountML.map(String.init) ?? ""
        loaded = true
    }

    private func save() {
        guard let feeding else { return }
        feeding.type = type
        feeding.startedAt = startedAt
        if let endedAt {
            feeding.endedAt = max(endedAt, startedAt)
        }
        feeding.amountML = showsAmount ? Int(amountText.filter(\.isNumber)) : nil
        try? modelContext.save()
        dismiss()
    }
}
