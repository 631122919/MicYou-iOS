// SPDX-License-Identifier: GPL-3.0-or-later
// Home Screen and Lock Screen widget, iOS 16 style: every control is a link that opens the app,
// because widgets can only run intents from iOS 17. The widget shares no storage with the app,
// so it shows no connection state and never needs a new timeline
// Text is capped at the Large content size category and every line scales down, a widget has a
// fixed height and larger text would push the layout out of its card

import MicYouShared
import SwiftUI
import WidgetKit

struct ShortcutWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.chouchiu.micyou.shortcuts", provider: Provider()) { _ in
            ShortcutWidgetView()
                .dynamicTypeSize(.xSmall ... .large)
        }
        .configurationDisplayName(L10n.App.name)
        .description(String(localized: L10n.Widget.description))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry { SimpleEntry() }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        completion(Timeline(entries: [SimpleEntry()], policy: .never))
    }
}

private struct SimpleEntry: TimelineEntry {
    let date = Date.now
}

private struct ShortcutWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "mic.fill")
                    .font(.title2.weight(.semibold))
            }
            .widgetURL(DeepLink.toggle.url)
            .accessibilityLabel(Text(L10n.Widget.hint))
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label(L10n.App.name, systemImage: "mic.fill")
                    .font(.headline)
                    .lineLimit(1)
                    .widgetAccentable()
                Text(L10n.Widget.hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(DeepLink.toggle.url)
        case .accessoryInline:
            Label(L10n.App.name, systemImage: "mic.fill")
                .widgetURL(DeepLink.toggle.url)
        case .systemMedium:
            // Title on top, the three links fill the height that is left
            VStack(alignment: .leading, spacing: 10) {
                Title()
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    ActionLink(link: .connect, title: L10n.Common.connect, symbol: "mic.fill", tint: .green)
                    ActionLink(link: .toggleMute, title: L10n.Common.mute, symbol: "mic.slash.fill", tint: .orange)
                    ActionLink(link: .disconnect, title: L10n.Common.disconnect, symbol: "xmark", tint: .red)
                }
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                CircleSymbol(symbol: "mic.fill", tint: .green, size: 38)
                Spacer(minLength: 4)
                Text(L10n.App.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(L10n.Widget.hint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(DeepLink.toggle.url)
        }
    }
}

private struct Title: View {
    var body: some View {
        Label(L10n.App.name, systemImage: "mic.fill")
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .widgetAccentable()
    }
}

/// Opens the app with a deep link, the app performs the action on launch or in the foreground
private struct ActionLink: View {
    let link: DeepLink
    let title: String
    let symbol: String
    let tint: Color

    var body: some View {
        Link(destination: link.url) {
            VStack(spacing: 6) {
                CircleSymbol(symbol: symbol, tint: tint, size: 38)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
