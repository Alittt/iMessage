//
//  OutgoingChatMessage.swift
//  iMessage
//

import Foundation

/// 单条会话中的发信记录（本应用仅模拟发信，无收信气泡）。
struct OutgoingChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let body: String
    let sentAt: Date
}
