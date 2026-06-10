//
//  RecentlyDeletedStore.swift
//  iMessage
//

import Foundation

/// 「最近删除」持久化存储。
@Observable
final class RecentlyDeletedStore {
    private static let key = "recently_deleted_conversations"

    var items: [RecentlyDeletedConversation] {
        didSet { save() }
    }

    init() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([RecentlyDeletedConversation].self, from: data) else {
            self.items = []
            return
        }
        self.items = decoded
    }

    func add(_ item: RecentlyDeletedConversation) {
        items.insert(item, at: 0)
    }

    func remove(_ ids: Set<UUID>) {
        items.removeAll { ids.contains($0.id) }
    }

    /// 恢复指定对话到 ConversationStore
    func recover(_ ids: Set<UUID>, to store: ConversationStore) {
        for id in ids {
            if let item = items.first(where: { $0.id == id }) {
                store.recover(item)
                items.removeAll { $0.id == id }
            }
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: Self.key)
        }
    }
}
