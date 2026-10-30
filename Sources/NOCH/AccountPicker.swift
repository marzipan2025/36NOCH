import SwiftUI

/// 팝업 안 계정 고르기. 시계 자리(팝업 위쪽)에 맥 캘린더 앱의 계정 목록을 띄우고, 누르면 바로 고른다.
/// 계정 추가·나중에 같은 버튼은 두지 않는다(나중에 설정에 넣을 것). 팝업 아래 유리는 평소처럼 투명하고,
/// 계정마다 둥근 검정 상자(0.1, 롤오버 0.8)에 담아서 투명한 곳까지 목록을 내려도 읽힌다.
struct AccountPicker: View {
    @ObservedObject var calendar: CalendarFeed
    let textSize: CGFloat
    /// 목록 끝 "Later"를 눌렀을 때(고르기를 끝내고 팝업을 닫는다)
    let onLater: () -> Void
    @State private var hovered: String?

    /// 위 제목과 첫 계정 사이, 계정과 계정 사이
    static let titleGap: CGFloat = 18
    static let rowGap: CGFloat = 10
    /// 계정 한 줄 높이(이름 + 캘린더 줄 + 위아래 여백). 화면에서 잰 값. 팝업 높이 계산에 쓴다.
    static let rowHeight: CGFloat = 58
    /// 목록 끝 "Later" 줄 높이(상자 없음)
    static let laterHeight: CGFloat = 42
    /// 계정 상자와 팝업 좌우 끝 사이, 상자 안 좌우·위아래 여백
    static let sideMargin: CGFloat = 24
    static let innerH: CGFloat = 16
    static let innerV: CGFloat = 11

    private static let light = Color(red: 0xcc / 255, green: 0xcc / 255, blue: 0xdd / 255)  // #ccccdd
    private static let dim = Color(red: 0x9a / 255, green: 0x9c / 255, blue: 0xb8 / 255)    // #9A9CB8

    var body: some View {
        VStack(alignment: .leading, spacing: Self.titleGap) {
            Text(calendar.status == .denied ? "Calendar access" : "Choose calendar account")
                .font(.system(size: textSize, weight: .light))
                .foregroundStyle(Self.light)
                .padding(.leading, Self.innerH)  // 계정 상자 안 글자와 왼쪽을 맞춘다
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
                        laterRow
                    }
                }
                .defaultScrollAnchor(.top)  // 처음엔 맨 위부터

            }
        }
        // 팝업 글 여백(22)에서 2 더 들여, 계정 상자가 팝업 좌우 끝에서 24 떨어지게. 위 제목도 상자 끝에 맞춘다.
        .padding(.horizontal, Self.sideMargin - 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// 목록 맨 끝: 평소엔 상자 없이 "Choose later" 글자만(검정, 계정 이름과 같은 크기 굵게).
    /// 마우스를 올리면 계정 상자와 같은 모양의 상자가 보인다. 글자가 검정이라 상자는 흰색(0.8)으로. 누르면 고르지 않고 닫는다.
    private var laterRow: some View {
        Button(action: onLater) {
            Text("Choose later")
                .font(.system(size: textSize + 6, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, Self.innerH)
                .padding(.vertical, Self.innerV)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(hovered == "later" ? 0.8 : 0)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .focusEffectDisabled()
        .onHover { hovered = $0 ? "later" : (hovered == "later" ? nil : hovered) }
    }

    private func message(_ text: String, action: @escaping () -> Void) -> some View {
        Text(text)
            .font(.system(size: textSize + 2, weight: .regular))
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }

    /// 계정 한 칸: 24pt 둥근 상자(검정 0.1, 롤오버 0.8) 안에 이름(지금 쓰는 계정이면 금색 점)과 캘린더 이름들.
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
            .padding(.horizontal, Self.innerH)
            .padding(.vertical, Self.innerV)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(hovered == account.id ? 0.8 : 0.1)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .focusEffectDisabled()
        .onHover { hovered = $0 ? account.id : (hovered == account.id ? nil : hovered) }
    }
}
