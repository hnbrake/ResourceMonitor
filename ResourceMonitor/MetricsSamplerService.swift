import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class MetricsSamplerService: ObservableObject {
    static let shared = MetricsSamplerService()

    @Published private(set) var snapshot: MetricsSnapshot = .placeholder
    @Published private(set) var appGroupReady = false
    @Published private(set) var lastSaveSucceeded = false
    @Published private(set) var statusMessage = "Starting…"

    private let sampler = SystemMetricsSampler()
    private var timer: Timer?

    private init() {}

    func start() {
        guard timer == nil else { return }

        refreshStatus()
        _ = sampler.sample() // baseline only

        let timer = Timer(timeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func tick() {
        refreshStatus()
        let next = sampler.sample()
        snapshot = next
        lastSaveSucceeded = MetricsStore.save(next)

        if MetricsStore.canShareWithWidget {
            WidgetCenter.shared.reloadTimelines(ofKind: MetricsStore.widgetKind)
            statusMessage = "Live · sharing with widget"
        } else if lastSaveSucceeded {
            statusMessage = "Live · widget share unavailable"
        } else if let error = MetricsStore.lastError {
            statusMessage = "Live · save warning: \(error)"
        } else {
            statusMessage = "Live"
        }
    }

    private func refreshStatus() {
        appGroupReady = MetricsStore.isAppGroupAvailable
    }
}
