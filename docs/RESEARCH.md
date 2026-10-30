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
| 캘린더 앱 계정 | 구글은 회사 계정(byeongsu.kim@welaaa.com) 하나뿐. 개인 계정 artbrainbyeongsu@gmail.com 캘린더는 없음(2026-10-30). 회사 계정 안에 `artbrainbyeongsu`라는 위임 계정이 보이지만 캘린더가 0개 |

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

**커진 노치의 모서리 반지름 (회사 맥 기준, 커진 노치 320×50pt)**: 노치가 커질 때 아래(볼록)·위(오목) 반지름도 함께 애니메이션한다(`NotchShape.animatableData`).

| 기준 | 아래 모서리 | 설명 |
|---|---|---|
| 하드웨어 비율 | 약 13 | 원래 노치 10/38을 높이 50에 그대로 적용. 가장 "노치다운" 값 |
| 권장 상한 | 25 | 높이 절반. 넘으면 옆면 직선이 거의 없어지고 아래가 반원처럼 늘어져 노치보다 물방울·캡슐처럼 보임 |
| 기하 최대 | 42 | 높이 − 위 반지름(8). 옆면 직선이 0이 되는 한계. 코드에서 이 값으로 잘라 냄 |

위(오목) 반지름은 원래 6. 같은 비율이면 약 8. 너무 키우면(12 이상) 메뉴 막대 쪽으로 검정이 번져 보일 수 있음(미확인).

**1차 설정 (2026-10-30 회사 맥, `DropTuning.applyFirstPreset`)**: 노치 +100 × +8, 커진 노치 아래 26 · 위 12 / 팝업 높이 204, 모서리 26, 간격 11, spacing 16, 출발 높이 34 / clear 유리, 틴트 0 / 검정 끌어올림 36.5, 흐림 35.5, 모서리 61, 양옆 −30, 불투명 1 / 덧그린 테두리 끔 / 그림자 0.3, 번짐 28, 아래 14.5 / 글 15, 여백 22·18 / 노치 커짐 0.6초 튕김 0.2, 대기 0.1, 떨어짐 0.65초 튕김 0.5, 닫힘 배율 0.55.

팝업은 커진 노치 너비 그대로, 노치가 다 커진 뒤(커짐 시간 + 대기) 커진 노치 밑에서 내려온다. 처음 구현은 작은 알갱이가 노치가 커지는 도중에 맺혀 넓어지며 내려와서 의도와 달랐다.

**2차 설정 (2026-10-30 회사 맥, 지금 기본값, `DropTuning.applySecondPreset`)**: 노치 +100 × +8, 커진 노치 아래 26 · 위 12 / 팝업 높이 204, 모서리 26, 간격 11, spacing 16 / 대기 높이 34, 대기 너비 줄임 4 / 검정 빠지기 시작 0, 검정→유리 0.65초, 목도 검정 켬 / clear 유리, 틴트 0 / 검정 끌어올림 35.5, 흐림 22.5, 모서리 74.5, 양옆 −30, 불투명 1 / 덧그린 테두리 0.05, 굵기 1, 번짐 1.5 / 그림자 0.3, 번짐 28, 아래 14.5 / 글 15, 여백 22·18 / 노치 커짐 0.6초 튕김 0.2, 팝업 시작 −0.7(노치가 커지는 도중 시작), 떨어짐 0.75초 튕김 0.4, 닫힘 속도 배율 0.5.

1차 → 2차 사이에 바뀐 연출:

- **대기 중 팝업을 투명하게 숨기기 → 취소.** 커진 노치 밑을 잘라 내고 투명도로 숨겼더니 모양이 여전히 보이고 이상한 타이밍에 나타나 왜곡돼 보였다.
- **검정 방울**: 팝업은 노치와 같은 완전한 검정으로 출발해서 떨어지며 유리로 바뀐다(`inked`). 노치와 방울 사이 목도 유리에 검정 틴트를 줘서 검게 잇는다.
- **대기 위치는 하드웨어 노치 밑**: 실제 노치보다 4pt 좁고 아래 끝이 2pt 위. 하드웨어 노치가 불투명하니 완전히 가려진다. 떨어지면서 커진 노치 너비까지 넓어진다.
- **닫힘 = 열림의 정확한 역재생**: 열림에서 [s, s+d]의 움직임을 닫힘에서는 [T−s−d, T−s]에 놓고, 스프링은 시간을 뒤집어 재생한다(`ReversedSpring`: value − s(D − t), D = settlingDuration). 처음에는 닫힘이 다른 순서·곡선이어서 열림만큼 개운하지 않았다. 닫힘 속도 배율은 역재생 전체를 균일하게 빠르게 한다.
  - 스프링 길이는 `settlingDuration`이 아니라 목표와의 차이가 이동 거리의 0.5% 안에 들기까지(`Spring.visibleDuration`)로 잡는다. `settlingDuration`은 안 보이는 잔떨림 꼬리까지 포함해(튕김 0.4, 0.75초 스프링이면 1.73초 vs 보이는 1.09초) 역재생하면 닫기 시작에 0.5초쯤 아무것도 안 움직이는 공백이 생겼다.
- 정확한 값은 앱이 종료될 때 표준 출력에 한 줄로 나온다. 슬라이더 표시는 반올림이라 믿지 말 것.

**마우스 호버와 설정 아이콘 (2026-10-30)**

- 앱을 띄워도 펼치지 않는다. 마우스가 실제 노치 둘레 **40pt** 안에 오면 열린다(12pt는 너무 가까워야 열렸음). 커진 노치+팝업 영역 둘레 8pt 안이면 유지하고, 벗어나면 역재생으로 닫히며 노치도 원래 크기로.
- 마우스 위치는 `NSEvent.mouseLocation`을 1/60초마다 읽는다(전역 이벤트 감시와 달리 손쉬운 사용 권한 불필요). 열려 있을 때만 `ignoresMouseEvents = false`.
- 설정창은 숨겨 두고, 커진 노치 오른쪽 검정 영역(하드웨어 노치 오른쪽 끝 ~ 커진 노치 오른쪽 끝) 한가운데의 12×12pt 톱니바퀴(#666666)로 연다. 설정창이 떠 있는 동안은 펼친 채 유지(토글).
- 비활성 패널에서 첫 클릭이 버튼에 가도록 `NSHostingView.acceptsFirstMouse`를 true로.
- 노치 패널(1000×620)은 펼쳐져 있어도 마우스가 커진 노치+팝업 위일 때만 클릭을 받는다. 창 전체가 받게 했더니 겹친 설정창의 제목 막대·버튼 클릭을 가로채서 설정창을 닫을 수 없었다.
- 노치 패널은 "마지막 창"으로 세지 않아서, `applicationShouldTerminateAfterLastWindowClosed`가 true면 설정창을 닫는 순간 앱이 종료됐다(닫기 모션 없이 사라짐). 방울 팝업 모드에서는 false.

**3차 설정 (2026-10-30 회사 맥, 지금 기본값, `DropTuning.applyThirdPreset`)**: 2차에서 검정 모서리 74.5 → **60**, 양옆 −30 → **−10**, 유리 위 덧칠 **0.5**(새 항목)만 바뀜.

- **유리 위 덧칠**: 검정을 유리 아래에만 깔면 유리가 빛을 더해 회색빛으로 들뜬다. 같은 흐린 검정 모양을 유리 위에도 반투명으로 한 번 더 얹는다. 1이면 매트한 평면과 같아짐.
- **값 저장**: 조절 값은 UserDefaults(`dropTuning` 사전)에 저장(바꾸고 0.3초 뒤, 종료할 때). 다음 실행은 저장된 값으로 시작. 맥마다 따로이고, `.app`(com.artbrain.noch)과 `swift build` 실행 파일도 따로.

**메뉴 막대 앱 (2026-10-30)**: 독 아이콘 없음(`.accessory`, Info.plist `LSUIElement`). 메뉴 막대 아이콘(`Resources/menubarIcon.png`, 템플릿 이미지 16pt) 메뉴에 설정…(⌘,)·종료(⌘Q). 앱 아이콘은 `Resources/AppIcon.png` → `build-app.sh`가 icns로.

**하단 영역 (2026-10-30)**: 팝업 아래쪽 280×60 둥근 사각형(좌우·아래 여백 20, 좌우 완전한 반원, 흰색 0.1). 검정 덮개를 그 모양만큼 오려 내서 안에 검정이 없다. 팝업 등장이 끝나기 0.2초 전부터 0.3초에 걸쳐 나타나고, 닫을 때는 닫힘 시작과 함께 사라진다(역재생에 넣으면 닫힘이 그만큼 늦어짐). 팝업 아래 두 모서리는 이 반원과 같은 중심(30 + 20 = 50), 위 두 모서리는 26.

**4차 설정 (2026-10-30 회사 맥, 지금 기본값, `DropTuning.applyFourthPreset`)**: 3차에서 노치–팝업 간격 11 → **10**, 유리 붙는 거리 16 → **14**, 떨어지는 시간 0.75 → **0.55**, 떨어지는 튕김 0.4 → **0.2**. 나머지(팝업 220, 하단 캡슐, 닫힌 노치 +48 등)는 그대로.

### 3.6 구글 캘린더 (2026-10-30)

- **방식**: 구글 API를 직접 쓰지 않고, 맥 캘린더 앱에 넣어 둔 구글 계정을 EventKit으로 읽는다(`CalendarFeed`). OAuth·클라우드 프로젝트가 필요 없고 두 맥이 같은 방식. 시스템 설정 > 인터넷 계정에 구글 계정(캘린더 켬)이 있어야 한다.
- **권한**: Info.plist `NSCalendarsFullAccessUsageDescription`(macOS 14+)과 `requestFullAccessToEvents`. 문구가 없는 `swift build` 실행 파일에서는 요청하면 죽으므로 건너뛴다. 메뉴 막대 앱은 비활성이라 권한 창이 처음엔 안 떴고, 요청 직전에 `NSApp.activate()`를 하니 떴다.
- **계정 찾기**: 캘린더 앱은 구글 계정 이름(`EKSource.title`)을 이메일이 아니라 "Google"로 둔다. 기본 캘린더 이름이 이메일 주소이므로 그 캘린더를 가진 계정을 찾는다. 집 맥은 기본 캘린더 이름이 "Byeongsu Kim"이라 이렇게는 못 찾아서, 캘린더가 있는 "Google" 계정이 하나뿐이면 그 계정을 쓴다(2026-10-30).
- **계정 고르기(2026-10-31)**: 계정은 노치 팝업 안에서 고른다(`AccountPicker`). 고른 계정은 `EKSource.sourceIdentifier`를 UserDefaults `calendarSourceID`에 저장(맥마다 다르므로 맥마다 한 번). 고른 적이 없으면 위 "계정 찾기" 규칙으로 찾아 저절로 저장하고, 못 찾을 때(첫 실행, 고른 계정이 사라짐)와 권한을 거부했을 때만 고르기로 바꾼다. 고를 계정이 있으면 고르는 동안 마우스와 상관없이 팝업이 열려 있고(계정을 눌러야 닫힘), 팝업은 목록이 다 들어가게 높아진다(아래 여백은 위와 같은 18, 화면 높이 절반·패널 620 안). 하단 캡슐은 그리지 않는다. 목록에는 캘린더가 있는 계정만, 이름(17pt) 아래 캘린더 이름(구글은 계정 이름이 "Google"뿐이라 캘린더로 알아봄). 제목과 첫 계정 사이 18, 계정 사이 10, 계정마다 24pt 둥근 상자(검정 0.1, 롤오버 0.8, 팝업 좌우 끝에서 24, 안 여백 좌우 16·위아래 11)에 담아 아래 투명한 유리 위에서도 읽힌다. 목록 맨 끝은 평소 상자 없는 "Choose later" 글자(검정, 계정 이름 크기 세미볼드, 롤오버면 계정 상자 평소와 같은 검정 0.1 상자, 글자는 검정 그대로). 위 제목은 상자 안 글자와 왼쪽 맞춤 — 누르면 고르지 않고 팝업을 닫고, 이번 실행 동안은 저절로 다시 띄우지 않는다. 계정 추가 버튼은 없다(나중에 설정에 넣을 것). 권한 거부·계정 없음이면 안내 글만 보이고 누르면 시스템 설정(개인정보 보호 > 캘린더 / 인터넷 계정)을 연다. 메뉴 막대 "캘린더 계정…"으로 다시 고른다. 시험: `--test-account-picker`.
- **동기화**: 앱은 맥 캘린더 저장소만 읽는다. 저장소가 바뀌면(`EKEventStoreChanged`) 바로, 그리고 팝업을 열 때마다 다시 읽는다. 폰·웹에서 넣은 일정은 macOS가 구글에서 받아오는 주기(캘린더 앱 설정 > 계정 > 새로 고침)만큼 늦을 수 있다.
- **화면(임시)**: 왼쪽에 다음 회의(종일 제외, 60일 안)까지 남은 시간을 Distro Mix 금색 시계로, 그 아래 제목(시계 색 70%). 오른쪽에 날짜·시각 두 줄. 시계는 너비 204 고정에 숫자마다 같은 폭 칸(가장 넓은 0 기준)이라 초가 바뀌어도 흔들리지 않고, 1시간 미만 `MM:SS`(금색), 100시간 미만 `HH:MM`(초 버림, #686B88), 그 이상 `N days`(#686B88) — 되도록 네 자리 — 글자 수가 줄면 커져서 아래로 늘어난다. 글·시계 위치 값은 확정해서 설정창에서 뺐다.
- **알림**: 10분 전에 10초간, 5분 전부터 시작 뒤 10초까지 팝업을 저절로 열고 시계를 붉게(#ff3b30). 시작하면 10초간 00:00을 깜빡이고, 닫힘 모션 뒤(시작 + 12초) 다음 회의로 넘어간다. 평일 18:00:00에는 10초간 하늘색 `18:00`을 깜빡이고, 제목 "Go home Now!". 시험: `open build/36NOCH.app --args --test-gohome`(실행 3초 뒤 한 번).
- **시계 숫자 글꼴**: 숫자마다 DistroLight·DistroMix·Distro-Bold·DistroHeavy 중 하나를 무작위로, 그 자리 숫자가 바뀔 때만 다시 뽑는다(`DigitFonts`). 같은 크기에서 숫자 높이가 Light 69·Mix 72·Bold 77·Heavy 72(100pt 기준)로 달라 위 끝이 흔들렸으므로, 글꼴마다 크기에 `DistroMix 대문자 높이 / 그 글꼴 대문자 높이`를 곱한다. 칸 너비는 배율 적용한 네 글꼴 숫자 중 가장 넓은 폭. 바닥선 맞춤(HStack `.lastTextBaseline`)은 줄 위 끝이 가장 높은 글꼴의 ascender를 따라가 Light가 섞일 때마다 시계가 약 1pt 오르내렸으므로, 칸 높이를 DistroMix 줄 높이로 고정하고 글꼴마다 ascender 차이만큼 내려 바닥선을 맞춘다. 콜론은 DistroMix. 1시간 미만(`MM:SS`)일 때 콜론이 초마다 깜빡인다(앞 0.5초 보임). 집 맥(2026-10-30)에도 네 글꼴이 있다.
- Distro Mix는 회사 맥에 따로 깔린 글꼴이다. 집 맥에 없으면 시스템 글꼴로 나온다.
- `open --stderr 파일 build/36NOCH.app`으로 띄우면 찾은 계정·캘린더 목록과 다음 회의가 로그에 나온다.

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
