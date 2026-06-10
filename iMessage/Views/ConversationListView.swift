//
//  ConversationListView.swift
//  iMessage
//

import SwiftUI
import UIKit

/// 追踪每行对话在列表中的绝对坐标，用于长按拖选时判断手指落在哪一行。
private struct RowFrame: Identifiable {
    let id: UUID
    let frame: CGRect
}

private struct RowFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// 对话列表根视图：大标题可收缩 + 原生搜索过滤 + 顶部编辑/菜单 + 底部撰写按钮；
/// 选择信息模式下底部为「全部已读 / 未读」+ 删除，对齐系统信息应用与开发文档交互。
/// 材质与层次参考 [Materials](https://developer.apple.com/cn/design/human-interface-guidelines/materials)、
/// [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)、
/// [Color](https://developer.apple.com/cn/design/human-interface-guidelines/color)。
struct ConversationListView: View {
    @State private var searchText = ""
    @State private var editMode: EditMode = .inactive
    @State private var inboxFilter: MessageInboxFilter = .messages
    @State private var isSelecting = false
    @State private var selectedConversations: Set<UUID> = []
    @State private var deleteMorph: DeleteMorphState?
    @State private var selectionBarContentWidth: CGFloat = 0
    @State private var removedConversationIDs: Set<UUID> = []
    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var isDragSelecting = false
    @State private var showImportSheet = false
    @State private var chatPath: [UUID] = []
    @State private var filtering = false
    @State private var store = ConversationStore()
    @State private var recentlyDeletedStore = RecentlyDeletedStore()
    @Environment(\.isSearching) private var isSearching

    /// 底部栏内可用宽度约 2/3，与系统「信息」右侧展开区域一致。
    private var selectionModePanelWidth: CGFloat {
        let bar = selectionBarContentWidth > 0
            ? selectionBarContentWidth
            : max(0, UIScreen.main.bounds.width - 32)
        return bar * 2 / 3
    }

    private var conversations: [Conversation] {
        let base = store.conversations.filter { !$0.isDeleted && !removedConversationIDs.contains($0.id) }
        let sorted = base.sorted { $0.updatedAt > $1.updatedAt }
        if searchText.isEmpty { return sorted }
        return sorted.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                NavigationStack(path: $chatPath) {
                    Group {
                        if inboxFilter == .recentlyDeleted {
                            RecentlyDeletedView(inboxFilter: $inboxFilter, store: store, recentlyDeletedStore: recentlyDeletedStore)
                        } else {
            listContent
                        }
                    }
                .environment(\.editMode, $editMode)
                    .navigationTitle(inboxFilter == .recentlyDeleted ? "最近删除" : "未知发件人")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbar {
                        /// 「最近删除」由 `RecentlyDeletedView` 自带标题栏按钮与底部栏；父级若仍挂列表的编辑/过滤与搜索条会叠在一起。
                        if inboxFilter != .recentlyDeleted {
                            ToolbarItem(placement: .topBarLeading) {
                                Group {
                                    if isSelecting {
                                        Button {
                                            isSelecting = false
                                            selectedConversations.removeAll()
                                            deleteMorph = nil
                                        } label: {
                                            Group {
                                                if selectedConversations.isEmpty {
                                                    Text(" ")
                                                        .font(.body.weight(.medium))
                                                        .frame(width: 36, height: 36)
                                                        .contentShape(Rectangle())
                                                } else {
                                                    ZStack {
                                                        Circle()
                                                            .fill(Color.blue.gradient)
                                                            .frame(width: 36, height: 36)
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 16, weight: .bold))
                                                            .foregroundStyle(.white)
                                                    }
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("完成")
                                        .transition(.move(edge: .leading).combined(with: .opacity))
                                    } else {
                                        Menu {
                                            Button {
                                                isSelecting = true
                                                deleteMorph = nil
                                            } label: {
                                                Label("选择信息", systemImage: "checkmark.circle")
                                            }
                                            Button {
                                                // 设置姓名与照片
                                            } label: {
                                                Label("设置姓名与照片", systemImage: "person.crop.circle")
                                            }
                                        } label: {
                                            Text("编辑")
                                                .font(.body.weight(.medium))
                                        }
                                        .transition(.move(edge: .leading).combined(with: .opacity))
                                    }
                                }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Group {
                                    if isSelecting {
                                        Button {
                                            if selectedConversations.count == conversations.count {
                                                selectedConversations.removeAll()
                                            } else {
                                                selectedConversations = Set(conversations.map(\.id))
                                            }
                                        } label: {
                                            Text(selectedConversations.count == conversations.count ? "取消全选" : "全选")
                                                .font(.body.weight(.medium))
                                        }
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                    } else {
                                        InboxFilterPopoverButton(inboxFilter: $inboxFilter, isDisabled: isSelecting && deleteMorph != nil)
                                            .transition(.move(edge: .trailing).combined(with: .opacity))
                                    }
                                }
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.28), value: isSelecting)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if inboxFilter != .recentlyDeleted {
                            bottomBar
                        }
                    }
                    .background(Color(.systemGroupedBackground))
                    .sheet(isPresented: $showImportSheet) {
                        ImportMessagesView { newConversations in
                            for c in newConversations {
                                store.addConversation(c)
                            }
                        }
                    }
                    .navigationDestination(for: UUID.self) { id in
                        ConversationChatView(conversationId: id, store: store)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)

                if let chatId = chatPath.last,
                   let conv = store.conversations.first(where: { $0.id == chatId }) {
                    ConversationNavBarCenterHeader(conversation: conv, filtering: filtering)
                        .frame(maxWidth: .infinity)
                        .allowsHitTesting(false)
                        .transaction { $0.animation = nil }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var listContent: some View {
        Group {
            if conversations.isEmpty {
                /// 空列表不用 List：单行无法撑满高度，空状态会挤在顶部；用满屏容器做垂直居中。
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Group {
                        if searchText.isEmpty {
                            ContentUnavailableView(
                                "无信息",
                                systemImage: "message.fill",
                                description: Text("与未知发件人的往来信息将在这里显示。")
                            )
                        } else {
                            ContentUnavailableView(
                                "没有结果",
                                systemImage: "magnifyingglass",
                                description: Text("没有与 \"\(searchText)\" 匹配的对话")
                            )
                        }
                    }
                    .multilineTextAlignment(.center)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
        List {
            ForEach(conversations) { item in
                        ConversationRowView(
                            conversation: item,
                            isSelecting: isSelecting,
                            isSelected: selectedConversations.contains(item.id),
                            onTap: {
                                if isSelecting {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if selectedConversations.contains(item.id) {
                                            selectedConversations.remove(item.id)
                                        } else {
                                            selectedConversations.insert(item.id)
                                        }
                                    }
                                } else {
                                    filtering = true
                                    chatPath.append(item.id)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        filtering = false
                                    }
                                }
                            }
                        )
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowSeparator(.hidden)
                        /// 选择模式下选中行：浅灰底，对齐系统「信息」批量选择（约 systemGray4 / #D1D1D6 系）。
                        .listRowBackground(
                            isSelecting && selectedConversations.contains(item.id)
                                ? Color(uiColor: .systemGray4)
                                : Color.clear
                        )
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: RowFrameKey.self,
                                    value: [item.id: geo.frame(in: .named("ConversationList"))]
                                )
                            }
                        )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
                .scrollDisabled(isDragSelecting)
                .coordinateSpace(.named("ConversationList"))
                .onPreferenceChange(RowFrameKey.self) { rowFrames = $0 }
                .gesture(
                    // 已处于选择模式：手指直接在列表上拖动即可多选
                    DragGesture(minimumDistance: 3, coordinateSpace: .named("ConversationList"))
                        .onChanged { value in
                            guard isSelecting, !isDragSelecting else { return }
                            isDragSelecting = true
                            handleDragSelection(at: value.location)
                        }
                        .onEnded { _ in
                            if isDragSelecting {
                                isDragSelecting = false
                            }
                        }
                )
                .simultaneousGesture(
                    // 非选择模式：长按 0.4 秒触发拖选模式，手指滑动经过的对话自动选中
                    LongPressGesture(minimumDuration: 0.4)
                        .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("ConversationList")))
                        .onChanged { value in
                            switch value {
                            case .second(true, let drag):
                                if !isSelecting {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isSelecting = true
                                    }
                                }
                                if !isDragSelecting {
                                    isDragSelecting = true
                                }
                                if let location = drag?.location {
                                    handleDragSelection(at: location)
                                }
                            default:
                                break
                            }
                        }
                        .onEnded { _ in
                            endDragSelection()
                        }
                )
            }
        }
    }

    private var bottomBar: some View {
        ZStack {
            normalBottomBar
                .scaleEffect(isSelecting ? 0.92 : 1)
                .opacity(isSelecting ? 0 : 1)
                .offset(x: isSelecting ? -20 : 0)

            selectionModeBottomBar
                .scaleEffect(isSelecting ? 1 : 0.92)
                .opacity(isSelecting ? 1 : 0)
                .offset(x: isSelecting ? 0 : 20)
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: isSelecting)
    }

    /// 选择信息模式：左「全部已读 / 未读」、右删除（对齐系统信息批量操作）。
    /// 点垃圾桶后：垃圾桶向左上淡出，确认面板以 overlay 浮于底部栏上方并上移，与未读按钮无布局冲突。
    private var selectionModeBottomBar: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 12) {
                Button {
                    // 全部已读 / 标为未读（占位，后续接 UserDefaults）
                } label: {
                    Text(selectedConversations.isEmpty ? "全部已读" : "未读")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .glassEffect(.clear.interactive(), in: Capsule())

                Spacer(minLength: 0)

                if deleteMorph == nil {
                Button {
                        DeleteMorphAnimation.start(deleteMorph: $deleteMorph)
                } label: {
                        Image(systemName: "trash")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(selectedConversations.isEmpty ? Color(.systemGray3) : .primary)
                            .frame(width: 52, height: 52)
                    }
                    .disabled(selectedConversations.isEmpty)
                    .buttonStyle(.plain)
                    .glassEffect(.clear.interactive(), in: Circle())
                    .transition(selectionTrashButtonTransition)
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
                        message: "此对话将从你的所有设备上删除。",
                        confirmButtonTitle: "删除",
                        onConfirm: confirmDeleteSelectedConversations,
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

    /// 垃圾桶：进入时淡入；确认时向左上偏移并淡出（不再占位显示）。
    private var selectionTrashButtonTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity,
            removal: .offset(x: -44, y: -36).combined(with: .opacity)
        )
    }

    private func confirmDeleteSelectedConversations() {
        store.markRemoved(selectedConversations, toRecentlyDeleted: recentlyDeletedStore)
        Task { @MainActor in
            await DeleteMorphAnimation.dismiss(deleteMorph: $deleteMorph)
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
            selectedConversations.removeAll()
            isSelecting = false
        }
    }

    /// 将手指在列表坐标系中的位置映射到被经过的对话 ID。
    private func conversationIDUnder(point: CGPoint) -> UUID? {
        rowFrames.first { $0.value.contains(point) }?.key
    }

    /// 长按后拖动时，实时更新选中状态：移入则选中，移出则取消选中。
    private func handleDragSelection(at location: CGPoint) {
        guard isDragSelecting, let id = conversationIDUnder(point: location) else { return }
        if !selectedConversations.contains(id) {
            selectedConversations.insert(id)
        }
    }

    /// 结束拖选：抬起时根据选中情况决定是否保持选择模式。
    /// - 已选择模式下拖选：始终保持选择模式（由用户主动退出）
    /// - 非选择模式下长按进入：抬起时无选中项则退出选择模式
    private func endDragSelection() {
        guard isDragSelecting else { return }
        isDragSelecting = false
        // 非选择模式下长按进入的拖选，若无选中项则恢复原状
        if !selectedConversations.isEmpty {
            // 保持选择模式
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                isSelecting = false
            }
        }
    }

    private var normalBottomBar: some View {
        GlassEffectContainer(spacing: 20) {
            HStack(spacing: 18) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("搜索", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.primary)
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: searchText.isEmpty ? "mic" : "xmark.circle.fill")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity)
                .glassEffect(.clear.interactive(), in: Capsule())

                Button {
                    if !searchText.isEmpty {
                        searchText = ""
                    } else {
                        showImportSheet = true
                    }
                } label: {
                    Image(systemName: searchText.isEmpty ? "square.and.pencil" : "xmark.circle.fill")
                        .font(.body.weight(.medium))
                        .foregroundStyle(searchText.isEmpty ? .primary : .secondary)
                        .frame(minWidth: 52, minHeight: 52)
                }
                .buttonStyle(.plain)
                .glassEffect(.clear.interactive(), in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .background(Color(.systemGroupedBackground).opacity(0.001))
    }
}

private struct ConversationRowView: View {
    let conversation: Conversation
    let isSelecting: Bool
    let isSelected: Bool
    let onTap: () -> Void

    @State private var showCheckbox = false

    /// 分割线从头像左缘起画：选择模式下跳过左侧勾选（26 + 与头像间距 10）。
    private var dividerLeadingInset: CGFloat {
        isSelecting ? 26 + 10 : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                if isSelecting {
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
                    .offset(x: showCheckbox ? 0 : -26)
                    .opacity(showCheckbox ? 1 : 0)
                }

            avatar
            VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(formatPhoneDisplay(conversation.displayName))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        Spacer(minLength: 4)
                        HStack(spacing: 8) {
                            Text(conversation.scheduledAt ?? conversation.updatedAt, style: .time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                }
                Text(conversation.lastMessagePreview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                /// 与头像同高区域垂直居中，避免标题行相对圆形视觉上偏上。
                .frame(minHeight: 64, alignment: .center)
            }
            .padding(.vertical, 4)

            Divider()
                .padding(.leading, dividerLeadingInset)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onChange(of: isSelecting) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.35)) {
                    showCheckbox = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showCheckbox = false
                }
            }
        }
    }

    private var avatar: some View {
        Group {
            if let data = conversation.avatarData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
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
                    .padding(2)
            }
        }
        // SF Symbol
        .frame(width: 54, height: 54)
        .clipShape(Circle())
    }
}

#Preview {
    ConversationListView()
}
