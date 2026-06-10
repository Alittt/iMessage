//
//  DeleteMorphConfirmation.swift
//  iMessage
//
//  与 ConversationListView 选择模式一致的删除确认：圆形 morph + Liquid Glass 面板。
//

import SwiftUI

/// 测量底部栏内容宽度，删除确认面板占宽约 2/3。
struct SelectionBarWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// 删除确认：圆形从垃圾桶位置放大到面板中心，再展开为面板；收起时反向。
struct DeleteMorphState: Equatable {
    var circleProgress: CGFloat
    var showsPanel: Bool
}

private let deleteMorphTrashDiameter: CGFloat = 52
private let deleteMorphExpandedDiameter: CGFloat = 132
private let deleteMorphPanelHeightEstimate: CGFloat = 220

enum DeleteMorphAnimation {
    static func start(deleteMorph: Binding<DeleteMorphState?>) {
        guard deleteMorph.wrappedValue == nil else { return }
        deleteMorph.wrappedValue = DeleteMorphState(circleProgress: 0, showsPanel: false)
        Task { @MainActor in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.78)) {
                deleteMorph.wrappedValue = DeleteMorphState(circleProgress: 1, showsPanel: false)
            }
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.spring(response: 0.15, dampingFraction: 0.82)) {
                deleteMorph.wrappedValue = DeleteMorphState(circleProgress: 1, showsPanel: true)
            }
        }
    }

    @MainActor
    static func dismiss(deleteMorph: Binding<DeleteMorphState?>) async {
        guard var m = deleteMorph.wrappedValue else { return }
        withAnimation(.spring(response: 0.14, dampingFraction: 0.82)) {
            m.showsPanel = false
            deleteMorph.wrappedValue = m
        }
        try? await Task.sleep(for: .milliseconds(70))
        withAnimation(.spring(response: 0.2, dampingFraction: 0.78)) {
            m.circleProgress = 0
            deleteMorph.wrappedValue = m
        }
        try? await Task.sleep(for: .milliseconds(90))
        deleteMorph.wrappedValue = nil
    }
}

/// 删除确认文案 + 红色主按钮（Liquid Glass 容器）。
struct DeleteMorphConfirmationPanel: View {
    let message: String
    let confirmButtonTitle: String
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(message)
                .font(.body)
                .multilineTextAlignment(.leading)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.primary)

            Button {
                onConfirm()
            } label: {
                Text(confirmButtonTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray5).opacity(0.55), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
    }
}

struct DeleteMorphOverlayView: View {
    let morph: DeleteMorphState
    let panelWidth: CGFloat
    let message: String
    let confirmButtonTitle: String
    let onConfirm: () -> Void
    var onDismiss: () async -> Void

    var body: some View {
        let pw = panelWidth
        let ph = deleteMorphPanelHeightEstimate
        ZStack {
            // 背景遮罩：仅覆盖 circle 周围空白区域，不覆盖面板内容
            if morph.showsPanel {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { await onDismiss() }
                    }
            }
            if !morph.showsPanel {
                DeleteMorphCircleLayer(progress: morph.circleProgress, panelWidth: pw, panelHeight: ph)
            }
            if morph.showsPanel {
                DeleteMorphConfirmationPanel(
                    message: message,
                    confirmButtonTitle: confirmButtonTitle,
                    onConfirm: onConfirm
                )
                .frame(width: pw, alignment: .trailing)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .center)),
                    removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .center))
                ))
            }
        }
        .frame(width: pw, height: ph)
    }
}

private struct DeleteMorphCircleLayer: View {
    let progress: CGFloat
    let panelWidth: CGFloat
    let panelHeight: CGFloat

    var body: some View {
        let w = panelWidth
        let h = panelHeight
        let trashCX = w - deleteMorphTrashDiameter / 2
        let trashCY = h - deleteMorphTrashDiameter / 2
        let panelCX = w / 2
        let panelCY = h / 2
        let cx = trashCX + (panelCX - trashCX) * progress
        let cy = trashCY + (panelCY - trashCY) * progress
        let d = deleteMorphTrashDiameter + (deleteMorphExpandedDiameter - deleteMorphTrashDiameter) * progress

        return Circle()
            .fill(Color(.systemBackground).opacity(0.92))
            .frame(width: d, height: d)
            .glassEffect(.regular, in: Circle())
            .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
            .position(x: cx, y: cy)
    }
}
