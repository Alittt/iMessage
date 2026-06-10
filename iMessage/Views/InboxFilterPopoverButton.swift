//
//  InboxFilterPopoverButton.swift
//  iMessage
//

import SwiftUI

private enum FilterRowIcon {
    case system(String)
    case asset(String)
}

/// 导航栏右上角过滤菜单（与 `ConversationListView` / `RecentlyDeletedView` 共用）。
struct InboxFilterPopoverButton: View {
    @Binding var inboxFilter: MessageInboxFilter
    @State private var isPresented = false
    var isDisabled: Bool = false

    private let filterItems: [(filter: MessageInboxFilter, label: String, icon: FilterRowIcon)] = [
        (.messages, "信息", .asset("message")),
        (.unknownSenders, "未知发件人", .system("person.crop.circle.badge.questionmark")),
        (.junk, "垃圾短信", .system("xmark.bin")),
        (.recentlyDeleted, "最近删除", .system("trash")),
    ]

    var body: some View {
        Button {
            guard !isDisabled else { return }
            isPresented = true
        } label: {
            if isDisabled {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.title.weight(.medium))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.title.weight(.medium))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .blue)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                ForEach(filterItems, id: \.filter) { item in
                    Button {
                        inboxFilter = item.filter
                        isPresented = false
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(width: 16, alignment: .leading)
                                .opacity(inboxFilter == item.filter ? 1 : 0)
                            filterRowIconView(item.icon)
                            Text(item.label)
                                .font(.system(size: 15))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }

                Divider()
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("过滤与垃圾信息")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                    Text("在\"设置\"中查看垃圾信息")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .padding(.leading, 44)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 240)
            .presentationCompactAdaptation(.popover)
        }
    }

    @ViewBuilder
    private func filterRowIconView(_ icon: FilterRowIcon) -> some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 15))
                .frame(width: 22)
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
        }
    }
}
