import AppKit
import Network

/// Avisa al despertar la Mac y al volver la conexión a internet.
final class SystemEventsMonitor {
    private let onWake: @MainActor () -> Void
    private let onNetworkRestored: @MainActor () -> Void
    private let pathMonitor = NWPathMonitor()
    private var wakeObserver: (any NSObjectProtocol)?
    private var isOnline = true

    init(onWake: @escaping @MainActor () -> Void, onNetworkRestored: @escaping @MainActor () -> Void) {
        self.onWake = onWake
        self.onNetworkRestored = onNetworkRestored

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { onWake() }
        }

        pathMonitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.networkChanged(online: online) }
        }
        pathMonitor.start(queue: DispatchQueue(label: "com.tonis.vigilia.network"))
    }

    private func networkChanged(online: Bool) {
        defer { isOnline = online }
        if online, !isOnline {
            onNetworkRestored()
        }
    }
}
