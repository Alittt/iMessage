//
//  FilterAnimation.swift
//  iMessage
//
//  载入过滤动画：不可见 -> 模糊 -> 清晰 -> 完全显示。
//

import SwiftUI

enum FilterPhase {
    case hidden, blurred, sharp, visible

    var opacity: Double {
        switch self {
        case .hidden: return 0.52
        case .blurred: return 0.72
        case .sharp: return 0.94
        case .visible: return 1.0
        }
    }

    var blur: CGFloat {
        switch self {
        case .hidden: return 11
        case .blurred: return 6.5
        case .sharp: return 1.5
        case .visible: return 0
        }
    }
}

struct FilterAnimation<Content: View>: View {
    let isActive: Bool
    @ViewBuilder let content: () -> Content

    @State private var phase: FilterPhase = .visible

    var body: some View {
        content()
            .opacity(phase.opacity)
            .blur(radius: phase.blur)
            .onChange(of: isActive, initial: false) { _, active in
                if active {
                    phase = .hidden
                    schedulePhase(.blurred, after: 100)
                    schedulePhase(.sharp, after: 250)
                    schedulePhase(.visible, after: 400)
                } else {
                    phase = .visible
                }
            }
    }

    private func schedulePhase(_ target: FilterPhase, after ms: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(ms)) {
            withAnimation(.filterPhase) {
                phase = target
            }
        }
    }
}

extension Animation {
    static let filterPhase = Animation.easeInOut(duration: 0.8)
}
