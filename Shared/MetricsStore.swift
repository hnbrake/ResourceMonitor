import Foundation

enum MetricsStore {
    /// Must match App Groups on BOTH targets in Signing & Capabilities.
    static let appGroupID = "group.com.hnbrake.ResourceMonitor"
    static let widgetKind = "ResourceMonitorWidget"

    private static let metricsFile = "metrics.json"
    private static let baselineFile = "baseline.json"

    private(set) static var lastError: String?

    static var isAppGroupAvailable: Bool {
        containerURL != nil
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// Prefer App Group; fall back to app support so the menu bar still works offline from the widget.
    private static var storageDirectory: URL? {
        if let containerURL {
            ensureDirectory(containerURL)
            return containerURL
        }
        return localFallbackDirectory
    }

    private static var localFallbackDirectory: URL? {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("ResourceMonitor", isDirectory: true)
        if let base {
            ensureDirectory(base)
        }
        return base
    }

    private static var metricsURL: URL? {
        storageDirectory?.appendingPathComponent(metricsFile)
    }

    private static var baselineURL: URL? {
        storageDirectory?.appendingPathComponent(baselineFile)
    }

    /// True only when we can write into the real App Group container (widget-shareable).
    static var canShareWithWidget: Bool {
        guard let containerURL else { return false }
        ensureDirectory(containerURL)
        let probe = containerURL.appendingPathComponent(".write-probe")
        do {
            try "ok".write(to: probe, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(at: probe)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    static func load() -> MetricsSnapshot? {
        // Prefer App Group copy for the widget; host can also read fallback.
        if let url = containerURL?.appendingPathComponent(metricsFile),
           let value: MetricsSnapshot = decode(url) {
            return value
        }
        return decode(localFallbackDirectory?.appendingPathComponent(metricsFile))
    }

    static func loadBaseline() -> MetricsBaseline? {
        if let url = containerURL?.appendingPathComponent(baselineFile),
           let value: MetricsBaseline = decode(url) {
            return value
        }
        return decode(localFallbackDirectory?.appendingPathComponent(baselineFile))
    }

    @discardableResult
    static func save(_ snapshot: MetricsSnapshot) -> Bool {
        var ok = false
        if let containerURL {
            ensureDirectory(containerURL)
            ok = encode(snapshot, to: containerURL.appendingPathComponent(metricsFile)) || ok
        }
        if let localFallbackDirectory {
            ok = encode(snapshot, to: localFallbackDirectory.appendingPathComponent(metricsFile)) || ok
        }
        return ok
    }

    @discardableResult
    static func saveBaseline(_ baseline: MetricsBaseline) -> Bool {
        var ok = false
        if let containerURL {
            ensureDirectory(containerURL)
            ok = encode(baseline, to: containerURL.appendingPathComponent(baselineFile)) || ok
        }
        if let localFallbackDirectory {
            ok = encode(baseline, to: localFallbackDirectory.appendingPathComponent(baselineFile)) || ok
        }
        return ok
    }

    private static func ensureDirectory(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private static func decode<T: Decodable>(_ url: URL?) -> T? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func encode<T: Encodable>(_ value: T, to url: URL?) -> Bool {
        guard let url else { return false }
        do {
            try JSONEncoder().encode(value).write(to: url, options: [.atomic])
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}
