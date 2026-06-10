//
//  Conversation.swift
//  iMessage
//

import Foundation

enum MessageType: String, Codable {
    case text
    case image
    case video
    case audio
    case system
}

struct Conversation: Identifiable, Codable, Equatable {
    let id: UUID
    let participantIDs: [String]
    let displayName: String
    let avatarData: Data?
    var lastMessagePreview: String
    var lastMessageType: MessageType
    var unreadCount: Int
    var isPinned: Bool
    var isMuted: Bool
    var updatedAt: Date
    let createdAt: Date
    var isDeleted: Bool
    /// 计划发送时间（非 nil 表示待显示的定时消息）
    var scheduledAt: Date?

    var isGroup: Bool { participantIDs.count > 1 }
}

extension Conversation {
    /// 无自定义头像数据时的占位：SF Symbol + #91A2D4
    enum PlaceholderAvatar {
        static let systemImageName = "person.crop.circle.fill"
        static let fillRed = 145.0 / 255.0
        static let fillGreen = 162.0 / 255.0
        static let fillBlue = 212.0 / 255.0
    }

    /// 占位：接入真实数据源前为空列表。
    static let mockConversations: [Conversation] = []
}
