// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

/// Mute and disconnect pinned above the home indicator while a session is active
/// With push to talk the mute button becomes a wide talk button and disconnect shrinks to a circle
struct ControlBar: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        buttons
            .padding(.horizontal, 20)
            .frame(maxWidth: HomeLayout.maxWidth)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.bar)
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            if settings.pushToTalk {
                TalkButton()
                disconnectButton(compact: true)
            } else {
                muteButton
                disconnectButton(compact: false)
            }
        }
        .animation(Motion.state, value: settings.pushToTalk)
    }

    private var muteButton: some View {
        Button {
            model.toggleMute()
        } label: {
            // Mic gets its slash drawn on rather than swapped
            Image(systemName: model.isMuted ? "mic.slash.fill" : "mic.fill")
                .font(.title2)
                .contentTransition(.magicReplace)
                .foregroundStyle(model.isMuted ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .frame(width: 56, height: 56)
                // One surface for both states, so the orange tint fades in instead of the button being replaced
                .glassSurface(in: .circle, tint: model.isMuted ? .orange : nil, fallback: .fillSecondary)
                .contentShape(.circle)
        }
        .buttonStyle(.surface)
        .accessibilityLabel(model.isMuted ? L10n.Common.unmute : L10n.Common.mute)
        .accessibilityAddTraits(model.isMuted ? .isSelected : [])
        .onChange(of: model.isMuted) { _ in
            Haptics.selection()
        }
        .animation(Motion.state, value: model.isMuted)
    }

    private func disconnectButton(compact: Bool) -> some View {
        Button(role: .destructive) {
            model.disconnect()
        } label: {
            Group {
                if compact {
                    Image(systemName: "xmark")
                        .font(.title2.weight(.semibold))
                        .frame(width: 56, height: 56)
                } else {
                    Text(model.phase == .streaming ? L10n.Common.disconnect : L10n.Common.cancel)
                        .font(.headline)
                        .contentTransition(.opacity)
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
            }
            .foregroundStyle(.red)
            .glassSurface(in: .capsule, fallback: Color.red.opacity(0.15))
            .contentShape(.capsule)
        }
        .buttonStyle(.surface)
        .accessibilityLabel(model.phase == .streaming ? L10n.Common.disconnect : L10n.Common.cancel)
        .animation(Motion.state, value: model.phase == .streaming)
    }
}

/// Unmutes while held, like a walkie-talkie
/// A plain view with a gesture rather than a button, a button only reports the tap once it is released
private struct TalkButton: View {
    @EnvironmentObject private var model: AppModel
    /// Resets when the touch ends and also when the system cancels it, for example for a call or Control Center
    @GestureState private var isHeld = false

    var body: some View {
        Label(isTalking ? L10n.Status.talking : L10n.Common.holdToTalk, systemImage: isTalking ? "mic.fill" : "mic.slash.fill")
            .font(.headline)
            .symbolReplace()
            .foregroundStyle(isTalking ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .frame(maxWidth: .infinity, minHeight: 56)
            .glassSurface(in: .capsule, tint: isTalking ? .green : nil, fallback: .fillSecondary)
            .contentShape(.capsule)
            .gesture(
                // onEnded is skipped for a cancelled touch, which would leave the microphone open
                DragGesture(minimumDistance: 0)
                    .updating($isHeld) { _, held, _ in held = true }
            )
            .onChange(of: isHeld) { held in model.setMuted(!held) }
            .onChange(of: isHeld) { held in
                Haptics.impact(held ? .medium : .light)
            }
            .animation(Motion.state, value: isTalking)
            // Holding is hard with VoiceOver, a double tap toggles instead
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isTalking ? L10n.Status.talking : L10n.Common.holdToTalk)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.toggleMute() }
    }

    /// Also when the computer unmuted, so the button never claims silence while audio flows
    private var isTalking: Bool { isHeld || !model.isMuted }
}
