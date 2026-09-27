import SwiftUI
import SwiftData
import Charts

/// 시간대 히스토그램 막대 데이터 (타입 체커 부하 감소용 사전 계산 모델)
private struct HourBar {
    let hour: Int
    let count: Int
    let floor: Double
    let opacity: Double
}

/// 통계 뷰: 주간 막대(횟수 + ml 오버레이), 시간대 히스토그램, 오늘 요약 카드.
struct StatsView: View {
    @Query(sort: \Feeding.startedAt, order: .reverse) private var feedings: [Feeding]

    @State private var now = Date()

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                todayCard
                weeklyChart
                hourChart
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.feed3Background)
        .navigationTitle("통계")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
    }

    // MARK: - 오늘 요약 카드

    private var todaySummary: FeedingStats.DailySummary {
        FeedingStats.dailySummary(feedings, day: now, calendar: calendar)
    }

    /// 오늘 모유류(모유+유축) 기록 중 모유(젖) 분율. 기록 없으면 0.
    private var breastRatio: Double {
        let summary = todaySummary
        let breastCount = feedings.filter { feeding in
            feeding.type.isBreast || feeding.type.isPump
        }
        .filter { feeding in
            guard let endedAt = feeding.endedAt else { return false }
            let start = calendar.startOfDay(for: now)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return false }
            return endedAt >= start && endedAt < end
        }
        .count
        guard summary.count > 0 else { return 0 }
        return Double(breastCount) / Double(summary.count)
    }

    private var todayCard: some View {
        let summary = todaySummary
        return VStack(alignment: .leading, spacing: 12) {
            Text("오늘")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.secondary)

            HStack {
                statBlock(value: "\(summary.count)", unit: "회")
                Divider().frame(height: 40)
                statBlock(value: "\(summary.totalML)", unit: "ml")
                Divider().frame(height: 40)
                statBlock(value: "\(Int((breastRatio * 100).rounded()))", unit: "% 모유")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private func statBlock(value: String, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.feed3Ink)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 주간 막대 (횟수 BarMark + ml LineMark 오버레이)

    private var weekPoints: [FeedingStats.WeekPoint] {
        FeedingStats.weeklySeries(feedings, weeks: 1, calendar: calendar)
    }

    private var weeklyChart: some View {
        let points = weekPoints
        let maxML = max(1, points.map(\.ml).max() ?? 1)
        return VStack(alignment: .leading, spacing: 8) {
            Text("최근 7일")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.secondary)
            Chart {
                ForEach(points, id: \.day) { point in
                    BarMark(
                        x: .value("날짜", point.day, unit: .day),
                        y: .value("횟수", point.count)
                    )
                    .foregroundStyle(Color.feed3Accent)
                    .cornerRadius(4)
                }
                ForEach(points, id: \.day) { point in
                    LineMark(
                        x: .value("날짜", point.day, unit: .day),
                        y: .value("ml", Double(point.ml) / Double(maxML) * Double(max(1, points.map(\.count).max() ?? 1)))
                    )
                    .foregroundStyle(Color.feed3Ink.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 180)

            HStack(spacing: 12) {
                legendDot(Color.feed3Accent, "횟수")
                legendDot(Color.feed3Ink.opacity(0.5), "ml (ml은 오른쪽 눈금 비례)")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - 시간대 히스토그램 (24칸, 농도 = count)

    private var histogram: [Int: Int] {
        FeedingStats.hourHistogram(feedings, calendar: calendar)
    }

    private var hourChart: some View {
        let histogram = histogram
        let maxCount = max(1, histogram.values.max() ?? 1)
        // 미리 계산한 데이터 모델로 단순화 — 타입 체커 부하 제거
        let bars: [HourBar] = (0..<24).map { hour in
            let count = histogram[hour, default: 0]
            let opacity: Double = count == 0 ? 0.08 : 0.25 + 0.75 * Double(count) / Double(maxCount)
            return HourBar(hour: hour, count: count, floor: count == 0 ? 0.02 : 0, opacity: opacity)
        }
        return VStack(alignment: .leading, spacing: 8) {
            Text("시간대 분포")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.secondary)
            Chart(bars, id: \.hour) { bar in
                BarMark(
                    x: .value("시간", bar.hour),
                    y: .value("횟수", bar.count > 0 ? bar.count : bar.floor)
                )
                .foregroundStyle(Color.feed3Accent.opacity(bar.opacity))
                .cornerRadius(2)
            }
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                    AxisValueLabel {
                        if let hour = value.as(Int.self) {
                            Text("\(hour)시")
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 140)
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}
