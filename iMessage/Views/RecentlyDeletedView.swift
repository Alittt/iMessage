//
//  RecentlyDeletedView.swift
//  iMessage
//
//  「最近删除」：说明文案 + 列表（圆圈选择、头像、条数、剩余天数）+ 底部全部恢复 / 删除。
//

import SwiftUI
import UIKit

struct RecentlyDeletedView: View {
    @Binding var inboxFilter: MessageInboxFilter

    var store: ConversationStore
    var recentlyDeletedStore: RecentlyDeletedStore

    @State private var selectedIDs: Set<UUID> = []
    @State private var deleteMorph: DeleteMorphState?
    @State private var selectionBarContentWidth: CGFloat = 0

    private var items: [RecentlyDeletedConversation] { recentlyDeletedStore.items }

    private var hasDeletedItems: Bool { !items.isEmpty }

    /// 底部栏内可用宽度约 2/3，与 `ConversationListView` 选择模式一致。
    private var selectionModePanelWidth: CGFloat {
        let bar = selectionBarContentWidth > 0
            ? selectionBarContentWidth
            : max(0, UIScreen.main.bounds.width - 32)
        return bar * 2 / 3
    }

    /// 即将永久删除的会话数量（未勾选时与点垃圾桶删全部一致）。
    private var pendingDeleteCount: Int {
        selectedIDs.isEmpty ? items.count : selectedIDs.count
    }

    private static let headerFootnote = "对话在删除前会显示剩余天数。之后信息将被永久删除。过程最长可能需要40天。"

    var body: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("最近删除")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                InboxFilterPopoverButton(inboxFilter: $inboxFilter, isDisabled: deleteMorph != nil)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            recentlyDeletedBottomBar
        }
        .background(Color(.systemGroupedBackground))
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ContentUnavailableView(
                "无信息",
                systemImage: "message.fill",
                description: Text("删除的信息将在这里显示。")
            )
            .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
    }

    private var listContent: some View {
        List {
            Section {
                Text(Self.headerFootnote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            ForEach(items) { item in
                RecentlyDeletedRowView(
                    item: item,
                    isSelected: selectedIDs.contains(item.id),
                    onToggleSelect: { toggleSelection(item.id) }
                )
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func toggleSelection(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedIDs.contains(id) {
                selectedIDs.remove(id)
            } else {
                selectedIDs.insert(id)
            }
        }
    }

    private var recentlyDeletedBottomBar: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 12) {
                Button {
                    let ids = selectedIDs.isEmpty ? Set(items.map(\.id)) : selectedIDs
                    recentlyDeletedStore.recover(ids, to: store)
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedIDs.removeAll()
                    }
                } label: {
                    Text("全部恢复")
                        .font(.body.weight(.medium))
                        .foregroundStyle(hasDeletedItems ? Color.primary : Color(.systemGray3))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
                .disabled(!hasDeletedItems)
                .buttonStyle(.plain)
                .glassEffect(.clear.interactive(), in: Capsule())

                Spacer(minLength: 0)

                if deleteMorph == nil {
                    Button {
                        DeleteMorphAnimation.start(deleteMorph: $deleteMorph)
                    } label: {
                        Image(systemName: "trash")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(hasDeletedItems ? Color.primary : Color(.systemGray3))
                            .frame(width: 52, height: 52)
                    }
                    .disabled(!hasDeletedItems)
                    .buttonStyle(.plain)
                    .glassEffect(.clear.interactive(), in: Circle())
                    .transition(recentlyDeletedTrashButtonTransition)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: SelectionBarWidthKey.self, value: geometry.size.width)
                }
            }
            .onPreferenceChange(SelectionBarWidthKey.self) { selectionBarContentWidth = $0 }
            .overlay(alignment: .bottomTrailing) {
                if let morph = deleteMorph {
                    DeleteMorphOverlayView(
                        morph: morph,
                        panelWidth: selectionModePanelWidth,
                        message: "这些信息将从所有设备上删除。此操作不能撤销。",
                        confirmButtonTitle: "删除 \(pendingDeleteCount) 条信息",
                        onConfirm: confirmPermanentDelete,
                        onDismiss: {
                            await DeleteMorphAnimation.dismiss(deleteMorph: $deleteMorph)
                        }
                    )
                    .animation(.spring(response: 0.22, dampingFraction: 0.78), value: deleteMorph)
                    .offset(y: -1)
                    .padding(.trailing, 16)
                }
            }
        }
        .background(Color(.systemGroupedBackground).opacity(0.001))
    }

    private var recentlyDeletedTrashButtonTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity,
            removal: .offset(x: -44, y: -36).combined(with: .opacity)
        )
    }

    private func confirmPermanentDelete() {
        deleteMorph = nil
        let ids = selectedIDs.isEmpty ? Set(items.map(\.id)) : selectedIDs
        recentlyDeletedStore.remove(ids)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
            selectedIDs.removeAll()
        }
    }
}

// MARK: - 行视图

private struct RecentlyDeletedRowView: View {
    let item: RecentlyDeletedConversation
    let isSelected: Bool
    let onToggleSelect: () -> Void

    private var messageCountLabel: String {
        "1 条信息"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                selectionCircle
                avatar
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(messageCountLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(item.daysRemaining)天")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            Divider()
                .padding(.leading, 26 + 10)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggleSelect()
        }
    }

    private var selectionCircle: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.blue : Color.clear)
                .frame(width: 26, height: 26)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.6), lineWidth: 1.5)
                )
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 26, height: 26)
    }

    private var avatar: some View {
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
            .padding(2)
            .frame(width: 54, height: 54)
            .clipShape(Circle())
    }
}

#Preview {
    NavigationStack {
        RecentlyDeletedView(
            inboxFilter: .constant(.recentlyDeleted),
            store: ConversationStore(),
            recentlyDeletedStore: RecentlyDeletedStore()
        )
    }
}
