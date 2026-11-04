// SPDX-License-Identifier: GPL-3.0-or-later

import ActivityKit
import Foundation
import MicYouShared
import os

/// Drives the Lock Screen and Dynamic Island activity from the app process, no App Group needed
/// Live Activities exist from iOS 16.1, so everything here is a no-op below that and the stored
/// activity stays boxed: the Activity type itself would otherwise raise the class to iOS 16.1
@MainActor
final class LiveActivityController {
    private let log = Logger.micyou("activity")
    private var activity: Any?
    /// Server of the shown or requested activity
    private var serverName: String?
    /// The state the last update asked for, replayed when the request lands late
    private var latest: Any?
    /// What the activity shows, so an update that changes nothing is dropped
    private var lastKey: String?
    private var request: Task<Void, Never>?

    @available(iOS 16.1, *)
    func update(serverName: String, state: StreamActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let key = Self.key(for: state)
        // The user can swipe the activity away while streaming, request a new one then
        let dismissed = (activity as? Activity<StreamActivityAttributes>).map { $0.activityState != .active } ?? false
        if serverName == self.serverName, !dismissed {
            guard key != lastKey else { return }
            lastKey = key
            latest = state
            // While a request is in flight it sends the latest state once it lands
            if let activity = activity as? Activity<StreamActivityAttributes> {
                Self.push(state, to: activity)
            }
            return
        }
        end()
        self.serverName = serverName
        lastKey = key
        latest = state
        request = Task { [weak self] in
            // Requesting blocks on a round trip to the system, off the main thread it cannot stall the connect animation
            let result = await Task.detached(priority: .userInitiated) {
                Result {
                    Unchecked(try Activity.request(
                        attributes: StreamActivityAttributes(serverName: serverName),
                        contentState: state,
                        pushType: nil
                    ))
                }
            }.value
            self?.finishRequest(result, requested: key)
        }
    }

    @available(iOS 16.1, *)
    func end() {
        request?.cancel()
        request = nil
        serverName = nil
        lastKey = nil
        latest = nil
        guard let activity = activity as? Activity<StreamActivityAttributes> else { return }
        self.activity = nil
        Self.dismiss(activity)
    }

    @available(iOS 16.1, *)
    private func finishRequest(_ result: Result<Unchecked<Activity<StreamActivityAttributes>>, any Error>, requested: String) {
        switch result {
        case .success(let box):
            // Ended or replaced while waiting
            guard !Task.isCancelled else { return Self.dismiss(box.value) }
            activity = box.value
            if let latest = latest as? StreamActivityAttributes.ContentState, Self.key(for: latest) != requested {
                Self.push(latest, to: box.value)
            }
        case .failure(let error):
            log.error("Live Activity request failed: \(String(describing: error), privacy: .public)")
            guard !Task.isCancelled else { return }
            // The next update tries again
            serverName = nil
            lastKey = nil
        }
        request = nil
    }

    /// Clears activities left over from a run that ended without a termination notice, such as a crash
    @available(iOS 16.1, *)
    func endStale() {
        Activity<StreamActivityAttributes>.activities.forEach(Self.dismiss)
    }

    /// Ends every activity before the process exits, for example when the app is swiped away
    /// The main thread is blocked here, so the requests run detached and the wait is bounded
    @available(iOS 16.1, *)
    nonisolated static func endAllBeforeExit() {
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            for activity in Activity<StreamActivityAttributes>.activities {
                await activity.end(using: nil, dismissalPolicy: .immediate)
            }
            done.signal()
        }
        _ = done.wait(timeout: .now() + 2)
    }

    @available(iOS 16.1, *)
    private static func key(for state: StreamActivityAttributes.ContentState) -> String {
        [
            state.phase.rawValue,
            String(state.isMuted),
            state.detail,
            state.input,
            String(state.attempt),
            String(state.startedAt.timeIntervalSince1970),
        ].joined(separator: "|")
    }

    // Activity is not Sendable but its methods are safe to call from any context

    @available(iOS 16.1, *)
    private static func push(_ state: StreamActivityAttributes.ContentState, to activity: Activity<StreamActivityAttributes>) {
        nonisolated(unsafe) let target = activity
        Task { await target.update(using: state) }
    }

    @available(iOS 16.1, *)
    private static func dismiss(_ activity: Activity<StreamActivityAttributes>) {
        nonisolated(unsafe) let target = activity
        Task { await target.end(using: nil, dismissalPolicy: .immediate) }
    }
}

/// Carries a non Sendable value whose methods are thread safe across an isolation boundary
private struct Unchecked<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) { self.value = value }
}
