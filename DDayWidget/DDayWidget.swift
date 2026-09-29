import WidgetKit
import SwiftUI

/// 위젯 확장 진입점. 홈 화면(systemSmall/systemMedium)과
/// 잠금 화면(accessoryCircular/accessoryRectangular/accessoryInline)을
/// 하나의 위젯이 전부 지원한다.
@main
struct DDayWidgetBundle: WidgetBundle {
    var body: some Widget {
        DDayWidget()
    }
}

/// 타임라인 엔트리에 실리는 표시 스냅샷. 데이터 없음 상태도 표현한다.
struct DDayWidgetSnapshot: Equatable {
    let title: String
    let label: String
    let hasContent: Bool

    static let empty = DDayWidgetSnapshot(title: "", label: "", hasContent: false)
}

struct DDayWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: DDayWidgetSnapshot
}

struct DDayWidgetProvider: TimelineProvider {
    /// 위젯 갤러리/프리뷰용 자리표시자.
    func placeholder(in context: Context) -> DDayWidgetEntry {
        DDayWidgetEntry(
            date: Date(),
            snapshot: DDayWidgetSnapshot(title: "생일", label: "D-12", hasContent: true)
        )
    }

    /// 위젯 갤러리 첫 화면. 실제 데이터가 있으면 그것을 쓴다.
    func getSnapshot(in context: Context, completion: @escaping (DDayWidgetEntry) -> Void) {
        completion(makeEntry(date: Date()))
    }

    /// 오늘 + 이후 자정 시점 엔트리들. 디데이는 자정에 바뀌므로
    /// 매일 자정마다 갱신되도록 엔트리를 나열하고 끝에서 atEnd 정책으로 재생성한다.
    func getTimeline(in context: Context, completion: @escaping (Timeline<DDayWidgetEntry>) -> Void) {
        let calendar = DDayMath.seoulCalendar()
        let today = DDayMath.startOfDay(Date())
        let entries = (0...3).map { offset -> DDayWidgetEntry in
            let entryDate = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            return makeEntry(date: offset == 0 ? Date() : entryDate)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makeEntry(date: Date) -> DDayWidgetEntry {
        let directory = DDayShared.containerDirectory()
        let items = DDayShared.load(directory: directory)
        guard let nearest = DDayMath.nearest(from: items, reference: date) else {
            return DDayWidgetEntry(date: date, snapshot: .empty)
        }
        let next = DDayMath.nextOccurrence(of: nearest.date, recurrence: nearest.recurrence, reference: date)
        return DDayWidgetEntry(
            date: date,
            snapshot: DDayWidgetSnapshot(
                title: nearest.title,
                label: DDayMath.ddayLabel(target: next, reference: date),
                hasContent: true
            )
        )
    }
}

/// 위젯 뷰. WidgetKit 기본 템플릿 스타일(containerBackground + 시스템 폰트)만 사용.
struct DDayWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: DDayWidgetEntry

    var body: some View {
        content
            .containerBackground(for: .widget) { Color.clear }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            DDayCircularContent(snapshot: entry.snapshot)
        case .accessoryInline:
            DDayInlineContent(snapshot: entry.snapshot)
        case .accessoryRectangular:
            DDayRectangularContent(snapshot: entry.snapshot)
        default:
            DDayHomeContent(snapshot: entry.snapshot)
        }
    }
}

/// 홈 화면(small/medium): 가장 가까운 디데이 제목 + D-day 라벨.
private struct DDayHomeContent: View {
    let snapshot: DDayWidgetSnapshot

    var body: some View {
        if snapshot.hasContent {
            VStack(alignment: .leading, spacing: DDayWidgetStyles.stackSpacing) {
                Text(snapshot.title)
                    .font(DDayWidgetStyles.title)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Text(snapshot.label)
                    .font(DDayWidgetStyles.label)
                    .fontWeight(.bold)
                    .foregroundStyle(.tint)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            DDayWidgetStyles.emptyHint
        }
    }
}

/// 잠금 화면 circular: 일수(D-123)만.
private struct DDayCircularContent: View {
    let snapshot: DDayWidgetSnapshot

    var body: some View {
        if snapshot.hasContent {
            Text(snapshot.label)
                .font(DDayWidgetStyles.lockLabel)
                .fontWeight(.semibold)
                .monospacedDigit()
                .minimumScaleFactor(0.5)
        } else {
            Text("-")
                .font(DDayWidgetStyles.lockLabel)
        }
    }
}

/// 잠금 화면 rectangular: 라벨 + 제목.
private struct DDayRectangularContent: View {
    let snapshot: DDayWidgetSnapshot

    var body: some View {
        if snapshot.hasContent {
            VStack(alignment: .leading, spacing: 0) {
                Text(snapshot.label)
                    .font(DDayWidgetStyles.lockLabel)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text(snapshot.title)
                    .font(.subheadline)
            }
        } else {
            Text("디데이 없음")
                .font(.subheadline)
        }
    }
}

/// 잠금 화면 inline: "제목 D-123" 한 줄.
private struct DDayInlineContent: View {
    let snapshot: DDayWidgetSnapshot

    var body: some View {
        if snapshot.hasContent {
            Text("\(snapshot.title) \(snapshot.label)")
        } else {
            Text("디데이 없음")
        }
    }
}

struct DDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: DDayWidgetStyles.kind, provider: DDayWidgetProvider()) { entry in
            DDayWidgetView(entry: entry)
        }
        .configurationDisplayName("디데이")
        .description("가장 가까운 디데이를 홈 화면과 잠금 화면에서 보여 줍니다.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

/// 위젯 스타일 상수(시스템 프리셋만 사용 — 인라인 스타일링 금지 규칙 준수).
enum DDayWidgetStyles {
    static let kind = "DDayWidget"
    static let stackSpacing: CGFloat = 4

    static let title: Font = .headline
    static let label: Font = .title2
    static let lockLabel: Font = .headline

    static var emptyHint: some View {
        Text("디데이를 추가하세요")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
