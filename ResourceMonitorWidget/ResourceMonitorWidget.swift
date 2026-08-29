import SwiftUI
import WidgetKit

struct MetricsEntry: TimelineEntry {
    let date: Date
    let snapshot: MetricsSnapshot
}

struct MetricsProvider: TimelineProvider {
    func placeholder(in context: Context) -> MetricsEntry {
        MetricsEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (MetricsEntry) -> Void) {
        completion(MetricsEntry(date: .now, snapshot: currentSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MetricsEntry>) -> Void) {
        let snapshot = currentSnapshot()
        let now = Date()
        completion(
            Timeline(
                entries: [MetricsEntry(date: now, snapshot: snapshot)],
                policy: .after(now.addingTimeInterval(15))
            )
        )
    }

    /// Prefer host-written metrics; otherwise sample using the shared baseline file.
    private func currentSnapshot() -> MetricsSnapshot {
        if let stored = MetricsStore.load(), Date().timeIntervalSince1970 - stored.updatedAt < 5 {
            return stored
        }
        return SystemMetricsSampler().sample()
    }
}

struct ResourceMonitorWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: MetricsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemMedium ? 6 : 10) {
            HStack {
                Text("Resources")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(entry.snapshot.updatedDate, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            bar(
                "CPU",
                ByteFormat.percent(entry.snapshot.cpuUsage),
                entry.snapshot.cpuUsage,
                Color(red: 0.20, green: 0.48, blue: 0.96)
            )
            bar(
                family == .systemMedium ? "Mem" : "Memory",
                "\(ByteFormat.percent(entry.snapshot.memoryUsage)) \(ByteFormat.memory(entry.snapshot.memoryUsedBytes))",
                entry.snapshot.memoryUsage,
                Color(red: 0.95, green: 0.55, blue: 0.18)
            )

            HStack {
                Text("↓ \(ByteFormat.rate(entry.snapshot.networkInBytesPerSec))")
                Spacer()
                Text("↑ \(ByteFormat.rate(entry.snapshot.networkOutBytesPerSec))")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            Color(red: 0.96, green: 0.97, blue: 0.98)
        }
    }

    private func bar(_ title: String, _ detail: String, _ value: Double, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(detail)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.06))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(4, geo.size.width * min(1, max(0, value))))
                }
            }
            .frame(height: 6)
        }
    }
}

struct ResourceMonitorWidget: Widget {
    static let kind = MetricsStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: MetricsProvider()) { entry in
            ResourceMonitorWidgetView(entry: entry)
        }
        .configurationDisplayName("Resource Monitor")
        .description("CPU, memory, and network at a glance.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
