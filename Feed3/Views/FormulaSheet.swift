import SwiftUI
import SwiftData

/// 분유 기록 시트: ml 스테퍼(10 단위, 10~300) + 직접 입력.
/// 마지막 입력값을 @AppStorage("lastFormulaML")로 기억한다.
struct FormulaSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("lastFormulaML") private var lastFormulaML = 120
    @AppStorage(BabiesView.currentBabyIDKey) private var currentBabyID: String = ""
    @Query private var babies: [Baby]

    @State private var amountML: Int = 0
    @State private var textValue: String = ""
    @State private var recordDate: Date = Date()
    @State private var isCustomDate = false

    private var currentBaby: Baby? {
        Baby.current(from: babies, appStorage: currentBabyID)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                HStack(spacing: 20) {
                    stepperButton(icon: "minus") { amountML = max(10, amountML - 10) }

                    TextField("ml", text: $textValue)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(maxWidth: 160)
                        .onChange(of: textValue) { _, newValue in
                            let digits = newValue.filter(\.isNumber)
                            if let value = Int(digits) {
                                amountML = min(300, max(0, value))
                            } else if digits.isEmpty {
                                amountML = 0
                            }
                            if digits != newValue {
                                textValue = digits
                            }
                        }

                    stepperButton(icon: "plus") { amountML = min(300, amountML + 10) }
                }

                Text("ml")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // 기록 날짜: 기본 '지금'. 토글하면 이전 날짜/시각 지정 가능.
                VStack(spacing: 8) {
                    Toggle("다른 날짜로 기록", isOn: $isCustomDate.animation())
                        .font(.subheadline)
                        .tint(Color.feed3Accent)
                    if isCustomDate {
                        DatePicker(
                            "날짜·시각",
                            selection: $recordDate,
                            in: ...Date.now,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                        .font(.subheadline)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                Button {
                    save()
                } label: {
                    Text("저장")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(Color.feed3Accent, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 20)
                .disabled(amountML < 10)
                .opacity(amountML < 10 ? 0.4 : 1)
                .accessibilityIdentifier("saveFormulaButton")
            }
            .padding(.vertical, 20)
            .background(Color.feed3Background)
            .navigationTitle("분유 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
            }
            .onAppear {
                amountML = lastFormulaML
                textValue = String(lastFormulaML)
            }
        }
    }

    private func stepperButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            textValue = String(amountML)
        }) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .frame(width: 64, height: 64)
        }
        .buttonStyle(.plain)
        .background(Color.feed3Accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
        .foregroundStyle(Color.feed3Accent)
    }

    private func save() {
        let date = isCustomDate ? recordDate : Date()
        let feeding = Feeding(type: .formula, startedAt: date, endedAt: date, amountML: amountML, baby: currentBaby)
        modelContext.insert(feeding)
        lastFormulaML = amountML
        try? modelContext.save()
        dismiss()
    }
}
