import SwiftUI

/// 팝업 안 계정 고르기. 시계 자리(팝업 위쪽)에 맥 캘린더 앱의 계정 목록을 띄우고, 누르면 바로 고른다.
/// 계정 추가·나중에 같은 버튼은 두지 않는다(나중에 설정에 넣을 것). 팝업 아래 유리는 평소처럼 투명하고,
/// 계정마다 둥근 검정 상자(0.1, 롤오버 0.8)에 담아서 투명한 곳까지 목록을 내려도 읽힌다.
struct AccountPicker: View {
    @ObservedObject var calendar: CalendarFeed
    let textSize: CGFloat
    @State private var hovered: String?

    /// 위 제목과 첫 계정 사이, 계정과 계정 사이
    static let titleGap: CGFloat = 18
    static let rowGap: CGFloat = 10
    /// 계정 한 줄 높이(이름 + 캘린더 줄 + 위아래 여백). 화면에서 잰 값. 팝업 높이 계산에 쓴다.
    static let rowHeight: CGFloat = 50

    private static let light = Color(red: 0xcc / 255, green: 0xcc / 255, blue: 0xdd / 255)  // #ccccdd
    private static let dim = Color(red: 0x9a / 255, green: 0x9c / 255, blue: 0xb8 / 255)    // #9A9CB8

    var body: some View {
        VStack(alignment: .leading, spacing: Self.titleGap) {
            Text(calendar.status == .denied ? "Calendar access" : "Choose calendar account")
                .font(.system(size: textSize, weight: .light))
                .foregroundStyle(Self.light)
            if calendar.status == .denied {
                // 누르면 시스템 설정 > 개인정보 보호 및 보안 > 캘린더
                message("36NOCH needs access to your calendars. Click to open System Settings.") {
                    calendar.openPrivacySettings()
                }
            } else if calendar.accounts.isEmpty {
                // 누르면 시스템 설정 > 인터넷 계정
                message("No accounts in Calendar yet. Click to add one in System Settings.") {
                    calendar.openInternetAccounts()
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Self.rowGap) {
                        ForEach(calendar.accounts) { row($0) }
                    }
                }
                .defaultScrollAnchor(.top)  // 처음엔 맨 위부터
                // 둥근 상자가 글 여백 바깥으로 10 나온다. 스크롤 뷰가 잘라 내지 않게 스크롤 뷰 자체를 넓힌다.
                .padding(.horizontal, -10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func message(_ text: String, action: @escaping () -> Void) -> some View {
        Text(text)
            .font(.system(size: textSize + 2, weight: .regular))
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }

    /// 계정 한 칸: 12pt 둥근 상자(검정 0.1, 롤오버 0.8) 안에 이름(지금 쓰는 계정이면 금색 점)과 캘린더 이름들.
    private func row(_ account: CalendarFeed.Account) -> some View {
        let current = account.id == calendar.selectedID
        return Button { calendar.choose(account) } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(account.title)
                        .font(.system(size: textSize + 6, weight: .medium))
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
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(hovered == account.id ? 0.8 : 0.1)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .focusEffectDisabled()
        .onHover { hovered = $0 ? account.id : (hovered == account.id ? nil : hovered) }
    }
}
