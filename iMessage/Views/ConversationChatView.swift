//
//  ConversationChatView.swift
//  iMessage
//
//  仅发信聊天页：右侧蓝色气泡 +「已送达」，无收信气泡。
//

import SwiftUI

struct ConversationChatView: View {
    let conversationId: UUID
    @Bindable var store: ConversationStore

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var filtering = false
    @FocusState private var inputFocused: Bool

    private var conversation: Conversation? {
        store.conversations.first { $0.id == conversationId }
    }

    private var messages: [OutgoingChatMessage] {
        store.outgoingMessages(for: conversationId)
    }

    var body: some View {
        Group {
            if let conv = conversation {
                chatContent(conversation: conv)
            } else {
                ContentUnavailableView("对话不存在", systemImage: "message.slash")
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // FaceTime 占位
                } label: {
                    Image(systemName: "video")
                        .font(.body)
                }
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            if let conv = conversation {
                store.seedOutgoingFromConversationIfNeeded(conv)
            }
        }
    }

    @ViewBuilder
    private func chatContent(conversation: Conversation) -> some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        messageThreadHeader
                        ForEach(messages) { msg in
                            outgoingBubble(message: msg)
                                .id(msg.id)
                        }
                        spamNoticeSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.top, 30)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last?.id {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let last = messages.last?.id {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }

            inputBar
        }
        .background(Color(.systemGroupedBackground))
    }

    private var messageThreadHeader: some View {
        VStack(spacing: 4) {
            Text("iMessage 信息")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(threadHeaderDate)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var threadHeaderDate: String {
        let d = messages.last?.sentAt ?? conversation?.updatedAt ?? Date()
        let cal = Calendar.current
        if cal.isDateInToday(d) {
            return "今天 \(d.formatted(date: .omitted, time: .shortened))"
        }
        if cal.isDateInYesterday(d) {
            return "昨天 \(d.formatted(date: .omitted, time: .shortened))"
        }
        return d.formatted(date: .abbreviated, time: .shortened)
    }

    private func outgoingBubble(message: OutgoingChatMessage) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                Spacer(minLength: 56)
                Text(message.body)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(red: 0.0, green: 0.478, blue: 1.0))
                    )
            }
            HStack {
                Spacer()
                Text("已送达")
                    .font(.caption2)
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
    }

    private var spamNoticeSection: some View {
        VStack(spacing: 14) {
            Text("若未预期会收到来自未知发件人的这则信息，其可能为垃圾信息。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            HStack(spacing: 8) {
                Button {
                    dismiss()
                } label: {
                    Text("删除")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .glassEffect(.clear.interactive(), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    // 标记为已知发件人占位
                } label: {
                    Text("标记为已知发件人")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(red: 0.0, green: 0.478, blue: 1.0))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 10)
                        .glassEffect(.clear.interactive(), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    private var inputBar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Button {
                    // 附件占位
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect(.clear.interactive(), in: Capsule())

                HStack(alignment: .center, spacing: 8) {
                    TextField("iMessage 信息", text: $draft, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...6)
                        .focused($inputFocused)
                        .submitLabel(.send)
                        .onSubmit { send() }

                    if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            // 语音占位
                        } label: {
                            Image(systemName: "mic")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            send()
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color(red: 0.0, green: 0.478, blue: 1.0)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.clear.interactive(), in: Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground).opacity(0.001))
    }

    private func send() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        store.appendOutgoingMessage(conversationId: conversationId, body: t)
        draft = ""
    }

}

#Preview {
    NavigationStack {
        ConversationChatView(
            conversationId: UUID(),
            store: ConversationStore()
        )
    }
}
