// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

/// Haptics for the taps and warnings that iOS 17 plays with sensoryFeedback
@MainActor
enum Haptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

extension ContentTransition {
    /// Digits that count to a new value from iOS 17, a plain fade before
    static var countingNumbers: ContentTransition {
        if #available(iOS 17, *) {
            return .numericText()
        }
        return .opacity
    }
}

extension View {
    /// The symbol replace transition from iOS 17, a plain fade before
    @ViewBuilder
    func symbolReplace() -> some View {
        if #available(iOS 17, *) {
            contentTransition(.symbolEffect(.replace))
        } else {
            contentTransition(.opacity)
        }
    }

    /// Reports when the view turns from portrait to landscape and back, onGeometryChange needs iOS 16.4
    func onOrientationChange(_ action: @escaping () -> Void) -> some View {
        modifier(OrientationObserver(action: action))
    }
}

private struct OrientationObserver: ViewModifier {
    let action: () -> Void
    @State private var isLandscape: Bool?

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { update(proxy.size) }
                    .onChange(of: proxy.size) { size in update(size) }
            }
        )
    }

    private func update(_ size: CGSize) {
        // Zero while the view is still being laid out
        guard size.width > 0, size.height > 0 else { return }
        let landscape = size.width > size.height
        guard landscape != isLandscape else { return }
        isLandscape = landscape
        action()
    }
}
