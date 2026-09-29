import Foundation
import WidgetKit

/// WidgetCenter.reloadAllTimelines()의 유일한 호출 지점.
/// DDayStore는 이 래퍼만 알고, WidgetKit 세부사항은 여기에 갇혀 있다.
enum WidgetCenterWrapper {
    static func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
