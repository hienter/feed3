import Foundation
import SwiftUI

/// 디데이 목록의 단일 진실 공급원.
/// - 기존 Feed3는 SwiftData를 썼지만, 이 앱은 디데이 목록이라는 단일 배열
///   도메인이라 JSON 파일 지속화(App Group 공유 컨테이너)로 단순화했다.
///   같은 파일을 위젯 확장이 읽어 위젯 데이터 공유가 공짜가 된다.
/// - 저장에 성공하면 위젯 타임라인을 리로드해 위젯을 즉시 갱신한다.
@MainActor
@Observable
final class DDayStore {
    private(set) var items: [DDayItem] = []

    private let directory: URL
    private let widgetReloader: () -> Void

    /// 실제 앱 런타임 초기화: App Group 컨테이너 + WidgetKit 리로드 훅.
    nonisolated init() {
        let dir = DDayShared.containerDirectory()
        self.directory = dir
        self.items = DDayShared.load(directory: dir)
        self.widgetReloader = {
            WidgetCenterBridge.reloadAll()
        }
    }

    /// 테스트 전용 초기화: 디렉토리와 위젯 훅을 주입한다.
    init(directory: URL, widgetReloader: @escaping () -> Void = {}) {
        self.directory = directory
        self.widgetReloader = widgetReloader
        self.items = DDayShared.load(directory: directory)
    }

    /// 추가 또는 수정(같은 id면 교체). 저장 + 위젯 리로드.
    func upsert(_ item: DDayItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        persistAndReloadWidget()
    }

    /// 삭제. 저장 + 위젯 리로드.
    func remove(_ item: DDayItem) {
        items.removeAll { $0.id == item.id }
        persistAndReloadWidget()
    }

    private func persistAndReloadWidget() {
        do {
            try DDayShared.save(items, directory: directory)
        } catch {
            // 저장 실패는 치명적이지 않다(다음 편집 시 재시도). 로그만 남긴다.
            #if DEBUG
            print("DDay: save failed \(error)")
            #endif
        }
        widgetReloader()
    }

    /// UI 테스트용: 공유 JSON 파일을 지워 신규 설치와 동일한 상태로 만든다.
    nonisolated static func resetForUITest() {
        DDayShared.removeAll(directory: DDayShared.containerDirectory())
    }
}

/// WidgetKit 의존성을 뷰/스토어 코드에서 떼어내기 위한 얇은 브리지.
/// 실제 WidgetCenter 호출은 앱 타깃의 WidgetCenterWrapper.swift로 격리돼 있다.
enum WidgetCenterBridge {
    static func reloadAll() {
        WidgetCenterWrapper.reloadAll()
    }
}
