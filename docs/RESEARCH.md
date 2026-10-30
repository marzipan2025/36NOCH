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

### 1.3 회사 맥 상태 (2026-10-30 직접 확인)

| 항목 | 값 |
|---|---|
| 기기 | MacBookPro18,3 (M1 Pro 14″), 내장 Liquid Retina XDR 3024×1964, 보이는 해상도 1800×1169pt |
| macOS | 27.0.1 |
| 노치 | 있음. 220 × 38pt (`safeAreaInsets.top` = 38, 양옆 보조 영역 각 790pt) |
| 외부 모니터 | DELL U2718Q (노치 없음) |
| NotchNook | 1.6.2 설치됨 (설정은 아직 안 봄) |
| Swift | 6.4 |

### 1.4 제품 정보 (웹)

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

모서리 곡선은 API가 없다. 2026-10-30 회사 맥에서 노치 둘레에 형광선을 그려(`Sources/NOCH/main.swift`) 눈으로 맞춰 본 결과, 아래 값이 잘 맞았다.

- 아래 두 모서리(볼록): 반지름 **10pt** (원을 베지어로 근사, k=0.5523)
- 위 끝, 화면 테두리와 만나는 곳(오목): 반지름 **6pt**
- 너비·높이 보정 0 — API 측정값이 실제 노치와 일치
- 선은 가장자리 바로 바깥에 그려야 한다(가장자리 위에 그리면 절반이 노치 밑에 가려짐)

집 맥(16″ 추정, Mac17,9)에서도 같은 값이 맞는지 확인할 것.

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

### 3.5 Siri 팝업식 패널 (2026-10-30 회사 맥 조사)

**배경 (웹, 대부분 WWDC 전 보도)**: iOS 27 / macOS 27에서 Siri가 화면 전체 대신 다이내믹 아일랜드(맥은 노치·Spotlight 쪽)에서 펼쳐지는 카드로 바뀌었다. 다크 모드에서 둘레에 Siri 색의 얇은 빛이 돈다는 보도가 있다. macOS 27의 Liquid Glass는 뒤 내용을 더 흐리게 바뀌었고, 시스템 설정에 투명("ultraclear")↔진한 틴트 슬라이더가 생겼다. 검정 그라데이션 처리를 설명한 공식 자료는 찾지 못했다 → 아래는 사진(iPhone 홍보 이미지)을 보고 한 분석.

**모양 분석**

- 바탕은 Liquid Glass. 아래 가장자리에 유리 특유의 밝은 테두리·굴절이 보인다.
- 위쪽은 완전한 검정이라 아일랜드(맥은 노치)와 경계 없이 이어진다.
- 검정이 사라지는 경계가 **수평선이 아니라 패널 아래 모서리 곡선을 따라 휜다**. 가운데는 아래까지 검정이 내려오고, 양옆 모서리 쪽은 곡선을 따라 일찍 투명해진다.
- → 세로 `LinearGradient`로는 이 모양이 안 나온다. 검정의 투명도가 "패널 모양의 아래 가장자리까지 거리"를 따라야 한다(모양 기반 페이드).

**구현 방법**

| 방법 | 내용 | 장단점 |
|---|---|---|
| A. 흐린 모양 덮개 (시제품에 씀) | 패널과 같은 계열 모양을 위로 끌어올려 검정으로 채우고 `.blur`, 패널 모양으로 `mask`. 흐린 경계가 모양의 아래 모서리를 따라 휜다 | SwiftUI만으로 됨. 조절 값: 끌어올림, 흐림, 검정 모서리 반지름, 양옆 들임 |
| B. Metal 셰이더 | `.colorEffect`/`.layerEffect`로 둥근 사각형의 거리 함수(SDF)를 계산해 alpha = smoothstep(아래 가장자리까지 거리) | 곡선·감쇠 곡선을 정확히 제어. `.metal` 파일과 ShaderLibrary 필요(SwiftPM CLI 빌드에서 metal 처리 확인 필요) |
| C. 유리 틴트만 | `Glass.regular.tint(.black)` | 전체가 고르게 어두워질 뿐 그라데이션이 안 됨. A·B와 섞어 쓰는 용도 |

**API (macOS 27 SDK에서 확인)**

- SwiftUI: `.glassEffect(_ glass: Glass = .regular, in: some Shape)`, `Glass.regular / .clear / .identity`, `.tint(Color?)`, `.interactive()`, `GlassEffectContainer`, `.glassEffectID`, `.glassEffectUnion`, `.glassEffectTransition(.matchedGeometry / .materialize)` — 모두 macOS 26+
- AppKit: `NSGlassEffectView`(contentView, cornerRadius, tintColor, style .regular/.clear; macOS 27에서 `effectIsInteractive` 추가), `NSGlassEffectContainerView`
- 펼침 애니메이션은 `glassEffectID` + `matchedGeometry`로 노치 모양 ↔ 패널 모양을 이을 수 있을 것으로 보임(미시험)

**첫 시제품의 문제 (사용자 확인)**: 유리 위에 흐린 검정을 덮었더니 매트한 그라데이션으로만 보였다. 유리 자체도 뿌옇게(매트) 보였는데, 창이 key가 아니라 비활성 모양으로 그려졌을 가능성이 있다.

**바꾼 방향 — 방울 팝업** (`.build/debug/NOCH siri`, `Sources/NOCH/SiriDemo.swift`)

1. 노치가 너비 +100, 높이 +12로 커진다(검정, 스프링).
2. 커진 노치에서 Liquid Glass 방울이 맺혀 아래로 떨어지며 팝업이 된다. 팝업 너비 = 커진 노치 너비, 노치 아래로 살짝 떨어진 위치.
3. 검정 그라데이션 덮개는 버리고 유리 그대로(기본 `.clear`) 보이게 한다.

방울 느낌은 `GlassEffectContainer(spacing:)`에 맡긴다. 같은 컨테이너 안의 유리 모양은 spacing 거리 안에서 액체처럼 붙고, 멀어지면 목이 늘어나다 끊어진다. 노치 모양에도 유리를 깔고 그 위를 검정으로 덮어서, 노치와 방울 사이의 목만 유리로 보이게 했다. 매트 문제는 패널을 key로 만드는 토글로 비교한다(조절 창은 key를 가져가지 않는 패널).

**사용자가 맞춘 방울 값 (고정, `DropFixed`)**: 노치 +100 × +12, 커진 노치 아래 모서리 16, 팝업 높이 150, 팝업 모서리 28, 노치와 간격 18, spacing 24, `.clear` 유리, 틴트 0, 패널 key 켬, 노치 커짐 0.2초, 대기 0, 떨어짐 1.0초, 튕김 0.5.

**다음 실험 — 팝업 안 검정과 그림자**: 위 방울 팝업 안에 위에서 내려오는 검정을 다시 깐다(§3.5 방법 A, 팝업 모양 기준). 검정 위에 유리 테두리 빛(위 밝게→옆 희미→아래 살짝)을 다시 그려서 검정 부분도 유리처럼 보이게 하고, 노치+팝업 전체에 바깥 그림자를 준다. 그림자는 모양 자체를 오려 내서(`destinationOut`) 투명한 유리 안이 어두워지지 않게 했다. 맞는 값을 찾으면 여기 기록.

**매트하게 보이는 원인 (2026-10-30)**: 패널을 key로 만들어도 매트했다. 시스템 설정(투명도 줄이기, 대비 높이기)은 기본값. 원인은 검정을 유리 *위에* 덮은 것 — 유리의 굴절·반사가 검정에 가려져 평면이 된다. 검정을 유리 *아래*에 깔도록 바꿨다(유리는 같은 창 안 뒤쪽 내용도 굴절시킨다). 그러면 가장자리에서 유리 렌즈 효과로 검정이 모서리를 따라 휘어 보일 것으로 기대 — 처음 사진에서 본 "검정이 모서리 곡선을 따라 휨"의 정체도 이것일 가능성이 높다. 또 유리 뒤가 흰 창처럼 밋밋하면 굴절할 무늬가 없어서 어떤 설정이든 매트에 가깝게 보인다.

**진짜 원인 — 앱 비활성 (2026-10-30 해결)**: 검정을 아래로 옮겨도, 띄운 직후엔 유리였다가 다른 앱을 만지는 순간 매트로 바뀌고 돌아오지 않았다. 유리는 창이 "활성 모양"이 아니면 가라앉은(subdued) 모양으로 그려진다.

| 시도 | 결과 |
|---|---|
| 패널을 key로(`canBecomeKey`, `makeKey`) | 처음만 유리, 다른 앱 만지면 매트 |
| SwiftUI `.environment(\.appearsActive, true)`, `.environment(\.controlActiveState, .key)` + `isKeyWindow`/`isMainWindow` 항상 true | 그래도 매트 |
| **NSWindow 비공개 메서드 덮어쓰기**: `_hasActiveAppearance`, `_hasActiveAppearanceIgnoringKeyFocus`, `_hasKeyAppearance`, `_hasMainAppearance`, `hasKeyAppearance`, `hasMainAppearance` → 항상 true | **유리 유지** |

- 이름은 macOS 27.0.1에서 `class_copyMethodList`로 확인. `NSGlassEffectView`에는 `_windowChangedKeyState`, `_subduedState`가 있어서, 유리가 창의 활성 모양 판단을 따른다고 추정.
- 비공개라 OS 업데이트 때 깨질 수 있다. 깨지면 같은 방법으로 이름을 다시 찾거나, 유리 뷰의 `_subduedState`를 직접 끄는 방법을 시도.
- 집 맥(macOS 26.6.2)에서도 같은 이름이 있는지 확인할 것.

---

## 4. 출처

- AppleInsider, macOS 27 Golden Gate: https://appleinsider.com/articles/26/06/08/macos-27-golden-gate-delivers-more-liquid-glass-and-updated-siri
- Cult of Mac, macOS 27 new features: https://www.cultofmac.com/news/macos-27-new-features-beyond-siri-ai
- 9to5Mac, iOS 27 Siri 디자인 유출: https://9to5mac.com/2026/05/28/ios-27-leak-reveals-new-siri-design-camera-app-more/
- iClarified, Siri 다이내믹 아일랜드 통합: https://www.iclarified.com/100841/ios-27-to-bring-massive-siri-redesign-dynamic-island-integration

- MacUpdate, NotchNook vs Alcove: https://www.macupdate.com/comparisons/notchnook-vs-alcove-whats-the-best-macbook-notch-app-in-2026
- Lowyat, NotchNook: https://www.lowyat.net/2024/327211/notchnook-dynamic-island-macbooks-us25/
- AlternativeTo, NotchNook: https://alternativeto.net/software/notchnook/about
- AlternativeTo, The Boring Notch: https://alternativeto.net/software/the-boring-notch/about
- boring.notch: https://github.com/TheBoredTeam/boring.notch
- DynamicNotch: https://github.com/jackson-storm/dynamicnotch
- DynamicNotchKit: https://github.com/MrKai77/DynamicNotchKit
- macOS notch UI 가이드(커뮤니티): https://skills.cat/skills/fayazara/macos-app-skills/macos-notch-ui
- Product Hunt, islet 2(NSPanel·CGSSpace 언급): https://www.producthunt.com/posts/islet-2
