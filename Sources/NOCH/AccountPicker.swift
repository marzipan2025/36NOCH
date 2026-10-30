import SwiftUI

/// 팝업 안 계정 고르기. 시계 자리(팝업 위쪽)에 맥 캘린더 앱의 계정 목록을 띄우고, 누르면 바로 고른다.
/// 아래 캡슐(하단 영역)에는 AccountTrayButtons가 들어간다.
struct AccountPicker: View {
    @ObservedObject var calendar: CalendarFeed
    let textSize: CGFloat
    @State private var hovered: String?

    /// 계정 한 줄 높이(이름 + 캘린더 줄 + 위아래 여백 + 줄 사이). 화면에서 잰 값. 팝업 높이 계산에 쓴다.
    static let rowHeight: CGFloat = 40

    private static let light = Color(red: 0xcc / 255, green: 0xcc / 255, blue: 0xdd / 255)  // #ccccdd
    private static let dim = Color(red: 0x9a / 255, green: 0x9c / 255, blue: 0xb8 / 255)    // #9A9CB8. 아래쪽 유리 위에서도 읽히게

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(calendar.status == .denied ? "Calendar access" : "Choose calendar account")
                .font(.system(size: textSize, weight: .light))
                .foregroundStyle(Self.light)
            if calendar.status == .denied {
                Text("36NOCH needs access to your calendars to show the next meeting.")
                    .font(.system(size: textSize + 2, weight: .regular))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            } else if calendar.accounts.isEmpty {
                Text("No accounts in Calendar yet. Add one below.")
                    .font(.system(size: textSize + 2, weight: .regular))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(calendar.accounts) { row($0) }
                    }
                }
                .defaultScrollAnchor(.top)  // 처음엔 맨 위부터
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// 계정 한 줄: 이름(지금 쓰는 계정이면 금색 점) 아래에 캘린더 이름들. 마우스를 올리면 바탕이 살짝 밝아진다.
    private func row(_ account: CalendarFeed.Account) -> some View {
        let current = account.id == calendar.selectedID
        return Button { calendar.choose(account) } label: {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(account.title)
                        .font(.system(size: textSize + 2, weight: .medium))
                        .foregroundStyle(.white)
                    if current {
                        Circle().fill(Color(red: 1, green: 0xd7 / 255, blue: 0)).frame(width: 5, height: 5)
                    }
                }
                Text(account.calendars.joined(separator: " · "))
                    .font(.system(size: textSize - 1, weight: .light))
                    .foregroundStyle(hovered == account.id ? Self.light : Self.dim)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(hovered == account.id ? 0.08 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .focusEffectDisabled()
        .onHover { hovered = $0 ? account.id : (hovered == account.id ? nil : hovered) }
        .padding(.horizontal, -8)  // 글은 팝업 글 여백에 맞추고 밝아지는 바탕만 바깥으로
    }
}

/// 하단 캡슐 안 두 버튼. 왼쪽: 계정 추가(권한 거부면 시스템 설정 열기), 오른쪽: 나중에.
struct AccountTrayButtons: View {
    @ObservedObject var calendar: CalendarFeed
    let textSize: CGFloat
    @State private var hovered: Int?

    var body: some View {
        HStack {
            if calendar.status == .denied {
                button(0, "Open Settings") { calendar.openPrivacySettings() }
            } else {
                button(0, "+ Add account") { calendar.openInternetAccounts() }
            }
            Spacer()
            button(1, "Later") { calendar.later() }
        }
    }

    private func button(_ id: Int, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: textSize + 1, weight: .medium))
                .foregroundStyle(hovered == id ? .white : Color(red: 0xcc / 255, green: 0xcc / 255, blue: 0xdd / 255))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                // 하단 캡슐은 뒤 화면이 비쳐 밝을 수 있어서 버튼마다 어두운 캡슐을 깐다
                .background(Capsule().fill(Color.black.opacity(hovered == id ? 0.8 : 0.55)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .focusEffectDisabled()
        .onHover { hovered = $0 ? id : (hovered == id ? nil : hovered) }
    }
}
