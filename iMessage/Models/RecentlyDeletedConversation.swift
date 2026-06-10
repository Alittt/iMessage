//
//  RecentlyDeletedConversation.swift
//  iMessage
//

import Foundation

/// 「最近删除」列表项：展示号码、条数、距永久删除剩余天数。
struct RecentlyDeletedConversation: Identifiable, Codable, Equatable {
    let id: UUID
    let displayName: String
    let participantIDs: [String]
    let avatarData: Data?
    var lastMessagePreview: String
    var lastMessageType: MessageType
    var unreadCount: Int
    var isPinned: Bool
    var isMuted: Bool
    var updatedAt: Date
    var createdAt: Date
    /// 永久删除倒计时起点（最近删除时间）
    let deletedAt: Date

    /// 距永久删除剩余天数（最多 40 天）
    var daysRemaining: Int {
        let deletedDays = 40
        let calendar = Calendar.current
        let expired = calendar.date(byAdding: .day, value: deletedDays, to: deletedAt) ?? deletedAt
        let remaining = calendar.dateComponents([.day], from: Date(), to: expired).day ?? 0
        return max(0, remaining)
    }

    /// 转换为普通 Conversation（恢复时使用）
    func toConversation() -> Conversation {
        Conversation(
            id: id,
            participantIDs: participantIDs,
            displayName: displayName,
            avatarData: avatarData,
            lastMessagePreview: lastMessagePreview,
            lastMessageType: lastMessageType,
            unreadCount: unreadCount,
            isPinned: isPinned,
            isMuted: isMuted,
            updatedAt: updatedAt,
            createdAt: createdAt,
            isDeleted: false,
            scheduledAt: nil
        )
    }
}
