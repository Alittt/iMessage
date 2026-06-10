//
//  ConversationStore.swift
//  iMessage
//

import Foundation
import SwiftUI

/// 全局对话数据存储，基于 UserDefaults 持久化；发信记录按会话 ID 单独持久化。
@Observable
final class ConversationStore {
    private static let key = "stored_conversations"
    private static let outgoingKey = "stored_outgoing_chat_messages"

    var conversations: [Conversation] {
        didSet { save() }
    }

    /// 各会话仅发信消息列表（时间正序由调用方保证；存储顺序即追加顺序）。
    private(set) var outgoingMessagesByConversationId: [UUID: [OutgoingChatMessage]] = [:] {
        didSet { saveOutgoing() }
    }

    init() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([Conversation].self, from: data) else {
            self.conversations = []
            loadOutgoing()
            return
        }
        self.conversations = decoded
        loadOutgoing()
    }

    func outgoingMessages(for conversationId: UUID) -> [OutgoingChatMessage] {
        outgoingMessagesByConversationId[conversationId] ?? []
    }

    /// 首次进入聊天页时，用列表预览补一条发信气泡（若尚无记录）。
    func seedOutgoingFromConversationIfNeeded(_ conversation: Conversation) {
        let id = conversation.id
        if let existing = outgoingMessagesByConversationId[id], !existing.isEmpty { return }
        let preview = conversation.lastMessagePreview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !preview.isEmpty else { return }
        outgoingMessagesByConversationId[id] = [
            OutgoingChatMessage(id: UUID(), body: preview, sentAt: conversation.updatedAt)
        ]
    }

    func appendOutgoingMessage(conversationId: UUID, body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let idx = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        var list = outgoingMessagesByConversationId[conversationId] ?? []
        list.append(OutgoingChatMessage(id: UUID(), body: trimmed, sentAt: Date()))
        outgoingMessagesByConversationId[conversationId] = list
        var conv = conversations[idx]
        conv.lastMessagePreview = trimmed
        conv.updatedAt = Date()
        conversations[idx] = conv
    }

    private func loadOutgoing() {
        guard let data = UserDefaults.standard.data(forKey: Self.outgoingKey),
              let raw = try? JSONDecoder().decode([String: [OutgoingChatMessage]].self, from: data) else { return }
        outgoingMessagesByConversationId = Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in
            guard let u = UUID(uuidString: key) else { return nil }
            return (u, value)
        })
    }

    private func saveOutgoing() {
        let raw = Dictionary(uniqueKeysWithValues: outgoingMessagesByConversationId.map { ($0.key.uuidString, $0.value) })
        if let encoded = try? JSONEncoder().encode(raw) {
            UserDefaults.standard.set(encoded, forKey: Self.outgoingKey)
        }
    }

    func addConversation(_ conversation: Conversation) {
        // 所有消息立即显示，scheduledAt 仅用于行内时间展示
        conversations.insert(conversation, at: 0)
        print("[ConversationStore] addConversation: \(conversation.displayName), scheduledAt=\(conversation.scheduledAt?.timeIntervalSince1970 ?? 0)")
    }

    /// 将指定对话移入「最近删除」
    func markRemoved(_ ids: Set<UUID>, toRecentlyDeleted recentlyDeletedStore: RecentlyDeletedStore) {
        for id in ids {
            if let index = conversations.firstIndex(where: { $0.id == id }) {
                let conv = conversations[index]
                let deleted = RecentlyDeletedConversation(
                    id: conv.id,
                    displayName: conv.displayName,
                    participantIDs: conv.participantIDs,
                    avatarData: conv.avatarData,
                    lastMessagePreview: conv.lastMessagePreview,
                    lastMessageType: conv.lastMessageType,
                    unreadCount: conv.unreadCount,
                    isPinned: conv.isPinned,
                    isMuted: conv.isMuted,
                    updatedAt: conv.updatedAt,
                    createdAt: conv.createdAt,
                    deletedAt: Date()
                )
                recentlyDeletedStore.add(deleted)
                conversations.remove(at: index)
                outgoingMessagesByConversationId.removeValue(forKey: id)
            }
        }
    }

    /// 从「最近删除」恢复对话
    func recover(_ item: RecentlyDeletedConversation) {
        let conv = item.toConversation()
        conversations.insert(conv, at: 0)
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(conversations) {
            UserDefaults.standard.set(encoded, forKey: Self.key)
        }
    }
}
