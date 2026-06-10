//
//  ConversationNavBarCenterHeader.swift
//  iMessage
//
//  聊天页导航栏中间区：头像 + 号码胶囊。置于 NavigationStack 外 overlay，避免随 push 从右侧滑入。
//

import SwiftUI
import UIKit

struct ConversationNavBarCenterHeader: View {
    let conversation: Conversation
    let filtering: Bool

    @State private var animating = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 0)
            FilterAnimation(isActive: animating) {
                avatarView
                    .frame(width: 68, height: 68)
            }
            FilterAnimation(isActive: animating) {
                HStack(spacing: 4) {
                    Text(formatPhoneDisplay(conversation.displayName))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
                .glassEffect(.clear.interactive(), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: filtering, initial: true) { _, newValue in
            if newValue {
                animating = true
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let data = conversation.avatarData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            Image(systemName: Conversation.PlaceholderAvatar.systemImageName)
                .resizable()
                .scaledToFit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.643, green: 0.737, blue: 0.878),
                            Color(red: 0.561, green: 0.631, blue: 0.804),
                            Color(red: 0.510, green: 0.561, blue: 0.765)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(4)
        }
    }
}
