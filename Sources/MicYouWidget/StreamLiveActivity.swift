// SPDX-License-Identifier: GPL-3.0-or-later
// Lock Screen banner and Dynamic Island for a running stream. iOS 16 has no interactive Live
// Activity buttons, so the activity shows the state and tapping it opens the app

import ActivityKit
import MicYouShared
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
private typealias State = StreamActivityAttributes.ContentState

@available(iOS 16.1, *)
struct StreamLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StreamActivityAttributes.self) { context in
            LockScreenView(serverName: context.attributes.serverName, state: context.state)
                .padding(16)
                .activityBackgroundTint(nil)
                .widgetURL(DeepLink.toggle.url)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                // The leading and trailing regions only reach the camera, too narrow for a host name,
                // so the top row holds the badge and the timer and everything with text goes below
                DynamicIslandExpandedRegion(.leading) {
                    Badge(state: state, size: 40)
                        .padding(.leading, 6)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedText(state: state)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(state.tint)
                        .frame(maxWidth: 88, maxHeight: 40, alignment: .trailing)
                        .padding(.trailing, 6)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    IslandDetails(serverName: context.attributes.serverName, state: state)
                        .padding(.horizontal, 6)
                        .padding(.top, 6)
                }
            } compactLeading: {
                Glyph(state: state)
            } compactTrailing: {
                ElapsedText(state: state)
                    .foregroundStyle(state.tint)
                    .frame(maxWidth: 48)
            } minimal: {
                Glyph(state: state)
            }
            .keylineTint(state.tint)
        }
    }
}

// MARK: Lock Screen

@available(iOS 16.1, *)
private struct LockScreenView: View {
    let serverName: String
    let state: State

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Badge(state: state, size: 44)
                TitleStack(serverName: serverName, subtitle: state.statusText)
                    .layoutPriority(1)
                Spacer(minLength: 8)
                ElapsedText(state: state)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(state.tint)
            }
            ControlRow(state: state)
        }
    }
}

// MARK: Building blocks

@available(iOS 16.1, *)
private struct TitleStack: View {
    let serverName: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(serverName)
                .font(.headline)
                .lineLimit(1)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

/// Status glyph on a circle in the phase's color
@available(iOS 16.1, *)
private struct Badge: View {
    let state: State
    let size: CGFloat

    var body: some View {
        CircleSymbol(symbol: state.symbol, tint: state.tint, size: size)
    }
}

/// Compact and minimal presentation
@available(iOS 16.1, *)
private struct Glyph: View {
    let state: State

    var body: some View {
        Image(systemName: state.symbol)
            .fontWeight(.semibold)
            .foregroundStyle(state.tint)
    }
}

/// Microphone and stream format. The input level is left out on purpose: every update makes the
/// system crossfade the timer
@available(iOS 16.1, *)
private struct ControlRow: View {
    let state: State

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !state.input.isEmpty {
                Label(state.input, systemImage: state.inputSymbol)
                    .font(.subheadline.weight(.medium))
            }
            if !state.detail.isEmpty {
                Text(state.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Bottom of the expanded island, full width so long host names fit
@available(iOS 16.1, *)
private struct IslandDetails: View {
    let serverName: String
    let state: State

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(serverName)
                .font(.headline)
            Text(status)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !state.detail.isEmpty {
                Text(state.detail)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// For example "Streaming · iPhone Microphone" or "Reconnecting (2/6)…"
    private var status: String {
        L10n.Common.joined([state.statusText, state.phase == .streaming ? state.input : ""])
    }
}

@available(iOS 16.1, *)
private struct ElapsedText: View {
    let state: State

    var body: some View {
        // The connection is still up while the microphone is interrupted, so the clock keeps running
        if state.phase == .streaming || state.phase == .interrupted {
            Text(timerInterval: state.startedAt...Date.distantFuture, countsDown: false)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        } else {
            Text(L10n.Status.waiting)
        }
    }
}

@available(iOS 16.1, *)
private extension StreamActivityAttributes.ContentState {
    var tint: Color {
        switch phase {
        case .streaming: isMuted ? .orange : .green
        case .connecting, .reconnecting: .blue
        case .interrupted: .yellow
        }
    }

    var symbol: String {
        switch phase {
        case .streaming: isMuted ? "mic.slash.fill" : "mic.fill"
        case .connecting, .reconnecting: "antenna.radiowaves.left.and.right"
        case .interrupted: "pause.fill"
        }
    }

    /// Phase with the retry progress while reconnecting, for example "Reconnecting (2/6)…"
    var statusText: String {
        switch phase {
        case .connecting: L10n.Status.connecting
        case .reconnecting:
            attempt > 0 ? L10n.Status.reconnectingAttempt(attempt, of: maxAttempts) : L10n.Status.reconnecting
        case .streaming: isMuted ? L10n.Status.muted : L10n.Status.streaming
        case .interrupted: L10n.Status.interrupted
        }
    }
}
