import SwiftUI

struct DesktopPanelView: View {
    @ObservedObject var sampler: MetricsSamplerService

    private let text = Color(red: 0.92, green: 0.93, blue: 0.96)
    private let muted = Color(red: 0.62, green: 0.65, blue: 0.72)
    private let card = Color(red: 0.11, green: 0.12, blue: 0.15)
    private let track = Color.white.opacity(0.12)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Resources")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(text)
                Spacer()
                Text(sampler.snapshot.updatedDate, style: .time)
                    .font(.caption2)
                    .foregroundStyle(muted)
            }

            bar(
                "CPU",
                ByteFormat.percent(sampler.snapshot.cpuUsage),
                sampler.snapshot.cpuUsage,
                Color(red: 0.35, green: 0.62, blue: 1.0)
            )
            bar(
                "Mem",
                "\(ByteFormat.percent(sampler.snapshot.memoryUsage)) \(ByteFormat.memory(sampler.snapshot.memoryUsedBytes))",
                sampler.snapshot.memoryUsage,
                Color(red: 1.0, green: 0.62, blue: 0.28)
            )

            HStack {
                Text("↓ \(ByteFormat.rate(sampler.snapshot.networkInBytesPerSec))")
                Spacer()
                Text("↑ \(ByteFormat.rate(sampler.snapshot.networkOutBytesPerSec))")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(muted)
        }
        .padding(12)
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        )
        .environment(\.colorScheme, .dark)
        .padding(8)
    }

    private func bar(_ title: String, _ detail: String, _ value: Double, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(text)
                Spacer()
                Text(detail)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(track)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(4, geo.size.width * min(1, max(0, value))))
                }
            }
            .frame(height: 6)
        }
    }
}
