import SwiftUI
import SwiftData

/// 분유 기록 시트: ml 스테퍼(10 단위, 10~300) + 직접 입력.
/// 마지막 입력값을 @AppStorage("lastFormulaML")로 기억한다.
struct FormulaSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("lastFormulaML") private var lastFormulaML = 120

    @State private var amountML: Int = 0
    @State private var textValue: String = ""

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
        let now = Date()
        let feeding = Feeding(type: .formula, startedAt: now, endedAt: now, amountML: amountML)
        modelContext.insert(feeding)
        lastFormulaML = amountML
        try? modelContext.save()
        dismiss()
    }
}
