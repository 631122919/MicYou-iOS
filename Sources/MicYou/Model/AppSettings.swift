// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import MicYouCore
import MicYouProtocol
import Network

/// Persistent user preferences, read when a stream starts
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let sampleRates = [48000, 44100, 16000]
    static let opusBitrates = [32000, 64000, 96000, 128000]
    static let inputGainRange = 0.0...24.0
    static let recentHostLimit = 5

    private enum Key: String {
        case host, port, transport, codec, opusBitrate, sampleRate, stereo, voiceProcessing, inputGainDB, input
        case highQualityBluetooth, fecEnabled, autoReconnect, autoConnect, pushToTalk, keepScreenOn, liveActivity, recentHosts, lastServiceName, usbSelected
        case welcomeShown, tourShown, autoCheckUpdates, lastUpdateCheck, dismissedUpdate
    }

    private let defaults: UserDefaults

    @Published var host: String { didSet { save(host, .host) } }
    @Published var port: Int { didSet { save(port, .port) } }
    @Published var transport: TransportMode { didSet { save(transport.rawValue, .transport) } }
    @Published var codec: CodecChoice { didSet { save(codec.rawValue, .codec) } }
    @Published var opusBitrate: Int { didSet { save(opusBitrate, .opusBitrate) } }
    @Published var sampleRate: Int { didSet { save(sampleRate, .sampleRate) } }
    @Published var stereo: Bool { didSet { save(stereo, .stereo) } }
    @Published var voiceProcessing: Bool { didSet { save(voiceProcessing, .voiceProcessing) } }
    /// Software gain in dB, within inputGainRange
    @Published var inputGainDB: Double { didSet { save(inputGainDB, .inputGainDB) } }
    /// The microphone to record from, applies immediately
    @Published var input: InputPreference { didSet { save(input.storageValue, .input) } }
    @Published var fecEnabled: Bool { didSet { save(fecEnabled, .fecEnabled) } }
    @Published var autoReconnect: Bool { didSet { save(autoReconnect, .autoReconnect) } }
    /// Connects to the selected computer when the app opens
    @Published var autoConnect: Bool { didSet { save(autoConnect, .autoConnect) } }
    /// Muted unless the talk button is held
    @Published var pushToTalk: Bool { didSet { save(pushToTalk, .pushToTalk) } }
    @Published var keepScreenOn: Bool { didSet { save(keepScreenOn, .keepScreenOn) } }
    @Published var liveActivity: Bool { didSet { save(liveActivity, .liveActivity) } }
    @Published var recentHosts: [String] { didSet { save(recentHosts, .recentHosts) } }
    /// Bonjour instance name of the last server picked from the list
    @Published var lastServiceName: String? { didSet { save(lastServiceName, .lastServiceName) } }
    /// The USB cable was picked last, it wins over lastServiceName
    @Published var usbSelected: Bool { didSet { save(usbSelected, .usbSelected) } }
    /// Full bandwidth recording from supported AirPods, iOS 26 and later
    @Published var highQualityBluetooth: Bool { didSet { save(highQualityBluetooth, .highQualityBluetooth) } }
    /// The welcome sheet appears once, on the first launch
    @Published var welcomeShown: Bool { didSet { save(welcomeShown, .welcomeShown) } }
    /// The spotlight tour of the home screen follows the welcome sheet, also once
    @Published var tourShown: Bool { didSet { save(tourShown, .tourShown) } }
    /// Look for a new release when the app opens, at most once a day
    @Published var autoCheckUpdates: Bool { didSet { save(autoCheckUpdates, .autoCheckUpdates) } }
    @Published var lastUpdateCheck: Date? { didSet { save(lastUpdateCheck, .lastUpdateCheck) } }
    /// The version whose home screen notice was closed, a newer one shows again
    @Published var dismissedUpdate: String? { didSet { save(dismissedUpdate, .dismissedUpdate) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func load<T>(_ key: Key) -> T? { defaults.object(forKey: key.rawValue) as? T }
        host = load(.host) ?? ""
        port = load(.port) ?? Int(MicYouWire.defaultPort)
        transport = load(.transport).flatMap(TransportMode.init) ?? .tcpUDP
        codec = load(.codec).flatMap(CodecChoice.init) ?? .opus
        opusBitrate = load(.opusBitrate) ?? 64000
        sampleRate = load(.sampleRate) ?? 48000
        stereo = load(.stereo) ?? false
        voiceProcessing = load(.voiceProcessing) ?? false
        inputGainDB = load(.inputGainDB) ?? 6
        input = load(.input).map(InputPreference.init(storageValue:)) ?? .automatic
        fecEnabled = load(.fecEnabled) ?? true
        autoReconnect = load(.autoReconnect) ?? true
        autoConnect = load(.autoConnect) ?? false
        pushToTalk = load(.pushToTalk) ?? false
        keepScreenOn = load(.keepScreenOn) ?? false
        liveActivity = load(.liveActivity) ?? true
        let hosts: [String] = load(.recentHosts) ?? []
        let service: String? = load(.lastServiceName)
        recentHosts = hosts
        lastServiceName = service
        usbSelected = load(.usbSelected) ?? false
        // Anyone who connected before this sheet existed has already found their way
        let hasConnected = !hosts.isEmpty || service != nil
        welcomeShown = load(.welcomeShown) ?? hasConnected
        tourShown = load(.tourShown) ?? hasConnected
        highQualityBluetooth = load(.highQualityBluetooth) ?? true
        autoCheckUpdates = load(.autoCheckUpdates) ?? true
        lastUpdateCheck = load(.lastUpdateCheck)
        dismissedUpdate = load(.dismissedUpdate)
    }

    /// The manual fields as an address, nil while they are empty or invalid
    /// A port typed into the address field, as in "192.168.1.5:8554" or "[fe80::1]:8554", wins over the port field
    var manualTarget: ServerAddress? {
        ServerAddress(parsing: host, defaultPort: port)
    }

    /// The address field without surrounding spaces, as it is remembered among the recent hosts
    var typedHost: String {
        host.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when something is typed but cannot be used, for an inline hint
    var manualInputInvalid: Bool {
        !typedHost.isEmpty && manualTarget == nil
    }

    /// The port field as a TCP port, nil when it is out of range, used by USB where no address can carry one
    var validPort: UInt16? {
        UInt16(exactly: port).flatMap { $0 > 0 ? $0 : nil }
    }

    /// Shows the welcome sheet and the tour again, from the about page
    func replayIntroduction() {
        welcomeShown = false
        tourShown = false
    }

    func rememberHost(_ host: String) {
        var hosts = recentHosts.filter { $0 != host }
        hosts.insert(host, at: 0)
        recentHosts = Array(hosts.prefix(Self.recentHostLimit))
    }

    func forgetHosts(at offsets: IndexSet) {
        recentHosts = recentHosts.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
    }

    private func save(_ value: Any?, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }
}

extension AppSettings {
    func apply(_ preset: StreamPreset) {
        transport = preset.transport
        codec = preset.codec
        if preset.codec == .opus { opusBitrate = preset.opusBitrate }
        sampleRate = preset.sampleRate
    }

    /// Rate actually sent, Opus maps 44.1 kHz to 48 kHz
    var streamSampleRate: Int {
        codec.streamRate(forCaptureRate: sampleRate)
    }

    /// The current audio and transport choices for a network stream
    var streamOptions: StreamOptions {
        StreamOptions(
            transport: transport,
            codec: codec,
            sampleRate: streamSampleRate,
            channels: stereo ? 2 : 1,
            opusBitrate: opusBitrate,
            fecEnabled: fecEnabled
        )
    }

    /// The choices a stream over `link` actually uses
    func streamOptions(for link: StreamLink) -> StreamOptions {
        link.isUSB ? streamOptions.overUSB : streamOptions
    }

    /// Freezes the current choices for one stream
    func streamConfig(link: StreamLink) -> StreamConfig {
        StreamConfig(link: link, options: streamOptions(for: link))
    }

    /// The preset the current settings match, nil once something was changed by hand
    var matchingPreset: StreamPreset? {
        StreamPreset.matching(transport: transport, codec: codec, sampleRate: sampleRate, opusBitrate: opusBitrate)
    }
}
