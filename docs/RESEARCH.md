# 36NOCH 조사 기록

2026-10-29 집 맥에서 조사. 웹 자료는 대부분 제3자 목록·비교 사이트라 수치(가격, 별 수, 최소 macOS)는 원 출처에서 다시 확인할 것.

---

## 1. NotchNook (lo.cafe)

### 1.1 집 맥 설치 상태 (직접 확인)

| 항목 | 값 |
|---|---|
| 버전 | 1.6.2 |
| 번들 ID | `lo.cafe.NotchNook` |
| 최소 macOS | 14.6 |
| 내장 프레임워크 | `Lottie`(애니메이션), `MediaRemoteAdapter`(재생 정보), `Sparkle`(자동 업데이트) |
| 기기 | Mac17,9 MacBook Pro, 내장 Liquid Retina XDR 3024×1964, macOS 26.6.2 |

`MediaRemoteAdapter`가 들어 있다는 점이 중요하다. macOS 15.4부터 일반 앱이 비공개 MediaRemote 프레임워크로 '지금 재생 중' 정보를 읽는 것이 막혀서, 우회용 어댑터를 쓰는 것으로 보인다(§3.3).

### 1.2 집 맥에서 쓰는 설정 (`defaults read lo.cafe.NotchNook`)

- 마우스를 올리면 노치가 열림(`alwaysOpenNotchOnHover`)
- 노치 없는 화면에서도 켜짐(`enableOnNonNotchScreens`) — 외부 모니터에서도 씀
- 열린 화면(Nook) 위젯: 미디어, 캘린더, 메모, 카메라 거울(mirror)
- 노치에 작게 뜨는 표시(Live Activities): 업데이트 알림, 트레이, 미디어, 캘린더. 10초 동안 활동이 없으면 숨김
- 볼륨·밝기 표시창 대체(HUD replacement): 꺼 둠
- 단축어 위젯: `DOPL에 URL (AGNI)`, `Ok Google` — 내 앱(04DOPL)과 연결하는 유일한 통로가 단축어
- 파일 트레이(드래그 앤 드롭 보관함) 사용

→ 36NOCH가 이 기능들을 다시 만들 필요는 없다. 다만 노치 하나를 두 앱이 같이 쓰면 겹치므로, 같이 켤지 하나를 끌지 정해야 한다(SPEC §5).

### 1.3 제품 정보 (웹)

- 가격 약 $25. 2024년 기사 기준 5대 영구 라이선스, 또는 2대 월 $3 구독. 현재 조건은 lo.cafe에서 확인 필요.
- 기능: 미디어 제어, 캘린더, 파일 트레이(AirDrop 포함), 단축어, 시스템 모니터 등.
- 회사 맥에도 같은 라이선스로 설치할 수 있을 가능성이 높음(5대).

---

## 2. 오픈소스 대안

| 이름 | 라이선스 | 특징 |
|---|---|---|
| [boring.notch](https://github.com/TheBoredTeam/boring.notch) | GPL-3.0 | 가장 유명(별 약 7.9천). 미디어 제어, 음악 시각화, 파일 선반, 캘린더 |
| [DynamicNotch](https://github.com/jackson-storm/dynamicnotch) | — | SwiftUI+AppKit. 노치 없는 화면에서는 떠 있는 캡슐. macOS 14.6+ |
| Notchly | MIT(보도 기준) | SwiftUI, macOS 15.6+ |
| NotchFlow | MIT | Swift, macOS 14+ |
| Notchii | MIT | 노치 없는 맥에 가상 노치 |
| Isle | 오픈소스 | 음악 시각화, 재생 제어 |

- boring.notch는 GPL-3.0이라 고쳐서 배포하면 소스 공개 의무가 있다. 개인용으로만 쓰면 문제없음.
- 코드를 가져다 쓰기보다 **구조를 참고하는 용도**로 보는 것이 좋다(노치 모양 Path, 열림/닫힘 애니메이션, 마우스 감지).

---

## 3. 구현 기술

### 3.1 노치 위에 창 띄우기 (공개 API만으로 가능)

- 테두리 없는 투명 `NSPanel` 서브클래스: `styleMask = [.borderless, .nonactivatingPanel]`, `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false`
- 창 레벨을 메뉴 막대보다 위로: `.statusBar` 이상, 또는 `CGShieldingWindowLevel()`
- `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`
- 위치 계산은 `NSScreen.frame`(전체) 기준. `visibleFrame`은 메뉴 막대를 빼므로 쓰면 안 됨
- 닫혀 있을 때는 클릭을 통과시키고(`ignoresMouseEvents`), 마우스가 노치 영역에 들어오면 받도록 전환
- 창을 먼저 보이게 한 뒤 SwiftUI 내용을 애니메이션해야 함(뷰가 계층에 있어야 애니메이션됨)

### 3.2 노치 크기 재기

macOS 12+의 `NSScreen` API:

- `safeAreaInsets.top` — 노치 높이(노치 없으면 0)
- `auxiliaryTopLeftArea`, `auxiliaryTopRightArea` — 노치 양옆 메뉴 막대 영역
- 노치 너비 = `frame.width - auxiliaryTopLeftArea.width - auxiliaryTopRightArea.width`

맥마다 노치 크기가 다르므로(14″/16″) 하드코딩하지 말고 이 값으로 계산한다.

### 3.3 까다로운 부분

| 항목 | 상황 | 판단 |
|---|---|---|
| 지금 재생 중 정보 | macOS 15.4+에서 MediaRemote 직접 호출 차단. NotchNook은 `MediaRemoteAdapter`로 우회 | 처음엔 빼고, 내 앱(04DOPL 등)은 직접 상태를 알려 주는 방식으로 |
| 전체 화면 앱 위 표시 | 문서화 안 된 CGS Space API 필요 | 빼거나 나중에 |
| 볼륨·밝기 HUD 대체 | 시스템 HUD 숨기기·키 가로채기 필요 | 하지 않음 |

### 3.4 라이브러리

[DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) (SwiftPM)

- SwiftUI 뷰를 노치에서 펼치고 접는 기능. 노치 없는 화면은 떠 있는 창으로 대체.
- 버전에 따라 API가 다름(`show(for:)`/`hide()` → `await notch.expand()`). 최신 README 확인.
- 최소 macOS 12 또는 13(출처마다 다름).

직접 만들지(§3.1) 라이브러리를 쓸지는 1단계에서 둘 다 짧게 시험해 보고 결정(SPEC §4).

---

## 4. 출처

- MacUpdate, NotchNook vs Alcove: https://www.macupdate.com/comparisons/notchnook-vs-alcove-whats-the-best-macbook-notch-app-in-2026
- Lowyat, NotchNook: https://www.lowyat.net/2024/327211/notchnook-dynamic-island-macbooks-us25/
- AlternativeTo, NotchNook: https://alternativeto.net/software/notchnook/about
- AlternativeTo, The Boring Notch: https://alternativeto.net/software/the-boring-notch/about
- boring.notch: https://github.com/TheBoredTeam/boring.notch
- DynamicNotch: https://github.com/jackson-storm/dynamicnotch
- DynamicNotchKit: https://github.com/MrKai77/DynamicNotchKit
- macOS notch UI 가이드(커뮤니티): https://skills.cat/skills/fayazara/macos-app-skills/macos-notch-ui
- Product Hunt, islet 2(NSPanel·CGSSpace 언급): https://www.producthunt.com/posts/islet-2
