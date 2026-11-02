// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import MicYouCore
import Network
import os

/// Follows the network path so the home screen can warn before a connection that cannot reach the computer
@MainActor
final class NetworkMonitor: ObservableObject {
    /// Local until the first path arrives, so nothing flashes at launch
    @Published private(set) var status: NetworkStatus = .local
    /// The status whose warning was closed, it shows again once the network changes
    @Published private var dismissed: NetworkStatus?
    /// Called on the main actor after the status changed
    var onChange: ((NetworkStatus) -> Void)?

    private let monitor = NWPathMonitor()
    private let log = Logger.micyou("model")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let status = NetworkStatus(
                satisfied: path.status == .satisfied,
                wifi: path.usesInterfaceType(.wifi),
                wired: path.usesInterfaceType(.wiredEthernet),
                other: path.usesInterfaceType(.other)
            )
            Task { @MainActor in self?.update(status) }
        }
        monitor.start(queue: DispatchQueue(label: "com.chouchiu.micyou.network", qos: .utility))
    }

    func warns(overUSB: Bool) -> Bool {
        status.needsWarning(overUSB: overUSB) && dismissed != status
    }

    func dismissWarning() {
        dismissed = status
    }

    private func update(_ status: NetworkStatus) {
        guard status != self.status else { return }
        log.info("Network changed: \(String(describing: status), privacy: .public)")
        self.status = status
        dismissed = nil
        onChange?(status)
    }
}
