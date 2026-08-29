import SwiftUI

struct ContentView: View {
    @ObservedObject var sampler: MetricsSamplerService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Resource Monitor")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Live values come from the menu-bar app. Use the Desktop Panel for second-by-second updates — WidgetKit widgets are throttled by macOS.")
                .foregroundStyle(.secondary)

            statusBanner

            Text(sampler.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                step("1", "Signing & Capabilities: Team set on both targets")
                step("2", "Add App Groups on both targets → enable \(MetricsStore.appGroupID)")
                step("3", "Run the app (keep it running)")
                step("4", "Use Desktop Panel for live desktop stats")
            }

            Button("Show Desktop Panel") {
                NotificationCenter.default.post(name: .showDesktopPanel, object: nil)
            }
            .keyboardShortcut("p", modifiers: [.command])

            Divider()

            MetricPreview(snapshot: sampler.snapshot)
        }
        .padding(24)
        .frame(width: 460)
    }

    @ViewBuilder
    private var statusBanner: some View {
        if MetricsStore.canShareWithWidget {
            banner(
                title: "Sharing with widget",
                detail: "App Group writes are working.",
                color: .green
            )
        } else if sampler.appGroupReady {
            banner(
                title: "App Group present, write failed",
                detail: MetricsStore.lastError
                    ?? "Re-check \(MetricsStore.appGroupID) on both targets. Menu bar still works locally.",
                color: .orange
            )
        } else {
            banner(
                title: "App Group not ready",
                detail: "Enable \(MetricsStore.appGroupID) on both targets for widget sharing. Menu bar still works.",
                color: .orange
            )
        }
    }

    private func banner(title: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(detail).font(.callout)
        }
        .foregroundStyle(.white)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.85)))
    }

    private func step(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.callout)
        }
    }
}

private struct MetricPreview: View {
    let snapshot: MetricsSnapshot

    var body: some View {
        VStack(spacing: 10) {
            row("CPU", ByteFormat.percent(snapshot.cpuUsage), snapshot.cpuUsage, .blue)
            row(
                "Memory",
                "\(ByteFormat.percent(snapshot.memoryUsage)) · \(ByteFormat.memory(snapshot.memoryUsedBytes))",
                snapshot.memoryUsage,
                .orange
            )
            HStack {
                Text("Network")
                Spacer()
                Text("↓ \(ByteFormat.rate(snapshot.networkInBytesPerSec))")
                Text("↑ \(ByteFormat.rate(snapshot.networkOutBytesPerSec))")
            }
            .font(.callout.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func row(_ title: String, _ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(label).monospacedDigit().foregroundStyle(.secondary)
            }
            .font(.callout)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(color.opacity(0.85))
                        .frame(width: max(8, geo.size.width * value))
                }
            }
            .frame(height: 8)
        }
    }
}
