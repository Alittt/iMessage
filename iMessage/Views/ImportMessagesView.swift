//
//  ImportMessagesView.swift
//  iMessage
//

import SwiftUI

/// 批量导入信息配置面板（从右下角编辑按钮呼出）。
struct ImportMessagesView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var numbersText = ""
    @State private var contentText = ""
    @State private var timeMode: TimeMode = .same
    @State private var customIntervalMinutes: Double = 1
    @State private var randomInsertEnabled = false

    /// 发送成功后追加到列表的回调
    var onSend: ([Conversation]) -> Void

    private enum TimeMode: String, CaseIterable {
        case same = "同时发送"
        case custom = "自定义间隔"
    }

    private var parsedNumbers: [String] {
        numbersText
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var parsedLines: [String] {
        contentText
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var canSend: Bool {
        !parsedNumbers.isEmpty && !parsedLines.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    recipientsSection
                    contentSection
                    timeSection
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 0)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("导入信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发送") {
                        let conversations = buildConversations()
                        onSend(conversations)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSend)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var recipientsSection: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(icon: "person.2.fill", title: "收件人", count: parsedNumbers.count)
                TextEditor(text: $numbersText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(minHeight: 72)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(uiColor: .systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                    )
                Text("每行一个号码，或用逗号、空格分隔")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var contentSection: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionHeader(icon: "text.alignleft", title: "内容", count: parsedLines.count)
                    Spacer()
                    randomInsertToggle
                }
                TextEditor(text: $contentText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(minHeight: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(uiColor: .systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                    )
                Text("每行对应一条独立消息")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if randomInsertEnabled {
                    randomInsertHint
                }
            }
        }
    }

    private var timeSection: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "clock.fill", title: "发送时间", count: nil)
                Picker("发送时间", selection: $timeMode) {
                    ForEach(TimeMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()

                if timeMode == .custom {
                    HStack(spacing: 12) {
                        Label("间隔", systemImage: "timer")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()

                        Button {
                            if customIntervalMinutes > 1 {
                                customIntervalMinutes -= 1
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)

                        Text("\(Int(customIntervalMinutes)) 分钟")
                            .font(.body.monospacedDigit().weight(.medium))
                            .frame(minWidth: 64)

                        Button {
                            if customIntervalMinutes < 60 {
                                customIntervalMinutes += 1
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    // 快捷间隔按钮
                    HStack(spacing: 8) {
                        ForEach([1, 2, 5, 10], id: \.self) { mins in
                            Button {
                                customIntervalMinutes = Double(mins)
                            } label: {
                                Text("\(mins) 分钟")
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Int(customIntervalMinutes) == mins
                                                  ? Color.blue
                                                  : Color(uiColor: .tertiarySystemFill))
                                    )
                                    .foregroundStyle(Int(customIntervalMinutes) == mins ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // 手动滑动调整
                    Slider(value: $customIntervalMinutes, in: 1...60, step: 1)
                        .tint(.blue)

                    let base = Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: Date()) ?? Date()
                    let intervalDesc = stride(from: 0, to: min(parsedNumbers.count, 3), by: 1)
                        .map { idx in
                            let d = Calendar.current.date(byAdding: .minute, value: idx * Int(customIntervalMinutes), to: base) ?? Date()
                            return d.formatted(date: .omitted, time: .shortened)
                        }
                        .joined(separator: " → ")

                    if !parsedNumbers.isEmpty && parsedNumbers.count > 1 {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("首批 \(base.formatted(date: .omitted, time: .shortened))，每条间隔 \(Int(customIntervalMinutes)) 分钟")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sub-components

    private var randomInsertToggle: some View {
        Toggle(isOn: $randomInsertEnabled) {
            Text("随机分配")
                .font(.subheadline.weight(.medium))
        }
        .toggleStyle(.switch)
        .labelsHidden()
    }

    private var randomInsertHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "shuffle")
                .font(.caption)
            Text("每条内容将随机分配至不同收件人顺序")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.top, 2)
    }

    @ViewBuilder
    private func sectionHeader(icon: String, title: String, count: Int?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            if let c = count, c > 0 {
                Text("\(c) 条")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.blue.opacity(0.12)))
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
    }

    // MARK: - Logic

    private func buildConversations() -> [Conversation] {
        let numbers = parsedNumbers
        let lines = parsedLines
        guard !numbers.isEmpty, !lines.isEmpty else { return [] }

        let now = Date()
        let shuffledLines = randomInsertEnabled ? lines.shuffled() : lines
        let intervalSeconds = timeMode == .custom ? Int(customIntervalMinutes) * 60 : 0

        return numbers.enumerated().map { idx, number in
            let scheduledTime = intervalSeconds > 0
                ? now.addingTimeInterval(TimeInterval(idx * intervalSeconds))
                : nil

            // 轮询分配内容：确保每条内容都被使用到
            let content = shuffledLines[idx % shuffledLines.count]

            return Conversation(
                id: UUID(),
                participantIDs: [number],
                displayName: number,
                avatarData: nil,
                lastMessagePreview: content,
                lastMessageType: .text,
                unreadCount: 0,
                isPinned: false,
                isMuted: false,
                updatedAt: now,
                createdAt: now,
                isDeleted: false,
                scheduledAt: scheduledTime
            )
        }
    }
}

#Preview {
    ImportMessagesView { _ in }
}
