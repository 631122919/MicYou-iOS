// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

/// Software gain slider, applies immediately, shared with the settings screen
struct InputGainControl: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent(L10n.Settings.inputGain) {
                Text(L10n.Unit.signedDB(settings.inputGainDB))
                    .monospacedDigit()
            }
            Slider(
                value: Binding(get: { settings.inputGainDB }, set: { model.setInputGain($0.rounded()) }),
                in: AppSettings.inputGainRange,
                step: 1
            ) {
                Text(L10n.Settings.inputGain)
            } minimumValueLabel: {
                Image(systemName: "speaker.wave.1")
            } maximumValueLabel: {
                Image(systemName: "speaker.wave.3")
            }
            .foregroundStyle(.secondary)
        }
    }
}
