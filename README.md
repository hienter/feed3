# DDay (디데이)

중요한 날까지 남은/지난 일수를 한눈에 보여 주는 iOS 디데이 카운트다운 앱.

> 이 저장소는 이전 수유 기록 앱 **Feed3**였으며, 같은 번들 ID·CI·TestFlight
> 인프라를 유지한 채 디데이 앱으로 전면 교체되었습니다. Xcode 타깃/스킴 이름은
> 빌드 인프라 호환을 위해 `Feed3`를 유지합니다.

## 기능 (MVP)

- **디데이 목록**: 카드 리스트 — 제목, 기준일, `D-123` / `D+45` / `D-DAY` 표시.
  반복을 반영해 가까운 순(다음 날짜 오름차순)으로 정렬됩니다.
- **추가/편집 시트**: 제목, 날짜(그래픽 DatePicker), 반복 옵션(없음/매년).
- **반복(매년)**: 생일·기념일처럼 올해 날짜가 지나면 자동으로 내년으로 계산.
  윤년 2/29는 평년에 2/28로 완화됩니다.
- **스와이프 제스처**: 오른쪽 스와이프로 삭제(전체 스와이프=삭제)/편집 진입.
- **위젯**: 홈 화면 small/medium + 잠금 화면 circular/rectangular/inline.
  가장 가까운 디데이를 표시하며, 매일 자정(서울) 기준으로 갱신되고
  목록 편집 시 즉시 리로드됩니다.
- **빈 상태**: 첫 사용자 안내.

## 기술

- Swift 6 · SwiftUI · iOS 17+ (프로젝트 배포 타깃 18.0) · 외부 의존성 없음
- 저장: **JSON 파일 + Codable** — 데이터가 단일 배열이라 SQLite/SwiftData가
  불필요하고, App Group 컨테이너의 파일 하나를 위젯 확장과 직접 공유할 수 있어
  선택했습니다(원자적 쓰기, 손상 시 빈 배열 복구).
- 데이터 공유: App Group `group.com.hienter.feed3.dday`
  (메인 앱 + DDayWidget 확장. App Store Connect에서 App Group 등록 필요)
- 날짜 계산: 모든 D-day 판정은 **아시아/서울 시간대 자정** 기준
  (`SharedKit/DDayMath.swift`). UTC 러너·해외 사용자 기기에서도 한국 날짜 기준 유지.
- 폴더블(iPhone Duo 7.6″ 등 regular 폭 화면) 대응: `horizontalSizeClass`가
  regular일 때 본문 최대 폭 제한(520pt) 적용.

## 프로젝트 구조

```
Feed3/            메인 앱 타깃 (Xcode 타깃명 유지)
  DDayApp.swift         앱 진입점
  DDayListView.swift    목록 화면 + 빈 상태
  DDayEditSheet.swift   추가/편집 시트
  DDayStore.swift       목록 상태 + JSON 지속화 + 위젯 리로드
  DDayStyles.swift      스타일 ViewModifier (뷰 = 구조만, 스타일 = 모듈)
  DDayStyleConstants.swift  타이포/간격/폭 상수
SharedKit/        앱·위젯·테스트 공유 소스 (동기화 그룹으로 3곳에 컴파일)
  DDayItem.swift        도메인 모델 (Codable)
  DDayMath.swift        D-day 계산/반복/정렬 순수 로직
  DDayShared.swift      App Group JSON 공유 계층
  DDayFormat.swift      날짜 포맷 중앙 상수
DDayWidget/       WidgetKit 확장 타깃
Feed3Tests/       단위 테스트 (44개)
Feed3UITests/     UI 테스트 (런치 + 빈 상태)
```

## 빌드/테스트

GitHub Actions(macOS 러너)에서 자동 실행됩니다:

- **CI** (`.github/workflows/ci.yml`): `xcodebuild test -project Feed3.xcodeproj -scheme Feed3`
  — 단위 테스트 + UI 테스트 전부 실행.
- **TestFlight** (`.github/workflows/testflight.yml`): archive 시 DDayWidget 확장이
  앱 번들에 자동 포함됩니다. 수동 배포용 App Group/위젯 프로비저닝 프로파일 갱신 필요.

로컬에서 (macOS):

```bash
xcodebuild test -project Feed3.xcodeproj -scheme Feed3 \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## 테스트 (52개)

- `DDayMathTests` (28): D-day 계산(오늘/과거/미래/월·연말 경계/윤년/시각 무시),
  매년 반복 롤링(올해/내년/오늘/윤년 2/29 완화), 정렬(가까운 순·과거 마지막·
  반복 우선·생성순 타이브레이크), 위젯 nearest 선택.
- `DDaySharedTests` (9): App Group JSON 저장/로드 라운드트립, 손상 파일 복구,
  구버전 JSON 하위 호환 디코딩, App Group ID 회귀 방어.
- `DDayStoreTests` (9): CRUD, 파일 지속화, 위젯 리로드 훅, 자정 정규화.
- `DDayFormatTests` (5): 서울 시간대/한국어 로캘 포맷 고정.
- `LaunchTest` (UI, 1): 런치 크래시 없음 + 빈 상태 표시.

## 앱 이름

- 번들 ID: `com.hienter.feed3` (기존 유지 — TestFlight 앱 레코드 호환)
- 표시 이름: **디데이**
