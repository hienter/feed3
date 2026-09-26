# 수유 트래커 "수유3초" (Feed3) — 설계 문서

날짜: 2026-09-26
상태: 승인됨 (사용자 확정: iOS Swift / MVP+통계+동기화 / 완전무료 / 신생아 부모 / 차별화=기록 속도)

## 1. 목적

신생아(0-6개월) 부모가 피곤한 새벽에도 한 손으로 3초 안에 수유를 기록할 수 있는 iOS 앱.
불특정 다수 대상 앱스토어 출시. 완전 무료(수익 모델 없음, 나중에 재검토).

## 2. 핵심 가치 제안

"가장 빠른 수유 기록" — 앱 열림 → 기록 완료까지 3초.
경쟁(마더스프렌드 등)은 기능이 많아 첫 화면이 무겁다. 우리는 기록 속도 하나로 승부.

성공 기준: 핵심 유저(신생아 부모)가 매일 5회 이상 기록하고 앱을 안 지운다.

## 3. 기능 범위 (1차 출시)

### 포함
- **수유 기록 3종**
  - 모유 직접: 좌/우 선택, 타이머(시작-종료), 종료 시 지속시간 자동 저장
  - 분유: ml 입력(스테퍼+직접입력, 기본값 기억)
  - 유축: 좌/우 + ml (1차에 포함 — 수유 패턴 파악에 필수라 판단, 신생아 필수 유즈케이스)
- **빠른 기록 UX**
  - 앱 실행 → 첫 화면에 즉시 3개 버튼(모유/분유/유축), 네비게이션 없음
  - 수유 간격 표시: "마지막 수유 2시간 15분 전"
  - 타이머는 백그라운드 진입 후 복귀 시 보정(기록 시각 기준)
- **타임라인**
  - 오늘 기록 목록(최신순), 스와이프 수정/삭제
  - 어제/그제 구분 표시
- **통계**
  - 일별 요약: 오늘 총 횟수·총 ml·모유/분유 비율
  - 주간 그래프: 최근 7일 횟수+용량 (Swift Charts)
  - 시간대 히트맵: 하루 24시간 중 수유 분포(새벽 패턴 파악)
- **다중 아기**: 아기 프로필(이름·생년월일) 복수 등록, 전환
- **iCloud 동기화**: CloudKit. 부부 공유(CKShare). 로컬 우선 저장.

### 제외 (YAGNI — 나중 버전)
수면, 기저귀, 성장곡선, 이유식, AI 상담, 커뮤니티, 위젯, Apple Watch, 알림(간격 경고), Android.

## 4. 기술 설계

### 스택
- iOS 18+, SwiftUI, Swift 6 (strict concurrency)
- SwiftData (로컬 DB) + CloudKit 동기화 (`\ModelConfiguration` 클라우드 옵션)
- Swift Charts (통계)
- 서드파티 의존성 0개
- 최소 지원: iOS 18 (SwiftData+CloudKit 안정화 기준)

### 데이터 모델 (SwiftData)
```
@Model Baby: id(UUID), name, birthDate, createdAt
@Model Feeding: id, baby(FetchableRecord 관계), type(enum: breastLeft/breastRight/formula/pumpLeft/pumpRight),
               startedAt, endedAt?, amountML(Int?), note(String?), createdAt
```
- type을 좌우 분리 enum으로 저장(쿼리 단순화), 통계에서 좌우 합산

### 화면 구조 (SwiftUI TabView 없음 — 단일 스택)
```
App
 ├─ HomeView (기록 버튼 3개 + 간격 표시 + 오늘 타임라인 상단)
 ├─ TimerSheet (모유/유축: 좌우 토글 + 타이머 + 저장)
 ├─ FormulaSheet (분유: ml 스테퍼 + 저장)
 ├─ StatsView (일별/주간/시간대)
 ├─ BabiesView (아기 관리 + iCloud 공유)
 └─ RecordEditSheet (기록 수정)
```

### 성능 목표
- 콜드 스타트 → 첫 버튼 탭 가능: 1.5초 이내 (앱 시작 지연 허용치의 핵심)
- 기록 저장 완료: 탭 후 200ms 이내 (로컬 저장이므로 동기식)

### iCloud 정책
- 로컬 저장 우선, CloudKit은 백그라운드 동기화 (오프라인에서도 전 기능 동작)
- 동기화 실패는 조용히 재시도 (사용자에게 에러 UI 띄우지 않음)
- 부부 공유: CKShare로 Baby 엔티티 공유 (1차 출시 포함하되 실패해도 출시 블록 아님)

## 5. 개인정보·심사

- 서버 없음, 계정 없음, 분석 없음 → 개인정보 수집 0건 (심사 매우 유리)
- App Privacy: "데이터 수집 안 함"
- 건강 데이터가 iCloud로만 감 — Privacy Manifest에 NSHealthShareUsageDescription 불필요(HealthKit 미사용)
- 연령: 4+

## 6. 오류 처리

- 로컬 저장 실패(디스크 풀 등): 저장 재시도 + 배너. 데이터 유실 금지가 최우선
- CloudKit 미로그인: 동기화 비활성 상태로 동작 (배너 1회, 이후 침묵)
- 타이머 백그라운드: 종료 시각 기준 역산이므로 백그라운드 제한 무관

## 7. 테스트 전략

- XCTest 단위: Feeding 모델(지속시간 계산, 간격 계산, 일별 집계, 시간대 분포 집계)
- 통계 집계 로직은 순수 함수로 분리해 ViewModel 없이 테스트
- UI 테스트(XCUITest): 런치→모유 기록→타임라인 표시 (E2E 1개만, CI macos 러너)
- GitHub Actions: MyCarwash/AgentBrowser testflight.yml 패턴 재사용 (macos-26, Xcode 26)

## 8. 저장소·배포

- GitHub: hienter/feed3 (private), gh = ~/bin/gh
- 커밋: `git -c user.name=hienter -c user.email=hienter@users.noreply.github.com`
- CI: 빌드+테스트 → TestFlight 업로드 (기존 testflight.yml 워크플로 재사용)
- ⚠️ 알려진 블로커: ASC 앱 비번 만료로 TestFlight 업로드 실패 예정 — 빌드 검증까지만, 업로드는 비번 재발급 후

## 9. 마일스톤

1. 프로젝트 셋업 + 모델 + 단위테스트 (로컬 swift 없음 → 서브에이전트가 macOS CI로 검증)
2. HomeView + 기록 플로우 (타이머/분유/유축)
3. 타임라인 + 수정/삭제
4. 통계 (Swift Charts)
5. 아기 관리 + CloudKit 동기화
6. CI 파이프라인 + 최종 검증
