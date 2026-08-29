import Foundation

struct MetricsSnapshot: Codable, Equatable {
    var cpuUsage: Double
    var memoryUsedBytes: UInt64
    var memoryTotalBytes: UInt64
    var networkInBytesPerSec: Double
    var networkOutBytesPerSec: Double
    var updatedAt: TimeInterval

    var memoryUsage: Double {
        guard memoryTotalBytes > 0 else { return 0 }
        return min(1, Double(memoryUsedBytes) / Double(memoryTotalBytes))
    }

    var updatedDate: Date {
        Date(timeIntervalSince1970: updatedAt)
    }

    static func make(
        cpuUsage: Double,
        memoryUsedBytes: UInt64,
        memoryTotalBytes: UInt64,
        networkInBytesPerSec: Double,
        networkOutBytesPerSec: Double
    ) -> MetricsSnapshot {
        MetricsSnapshot(
            cpuUsage: cpuUsage,
            memoryUsedBytes: memoryUsedBytes,
            memoryTotalBytes: memoryTotalBytes,
            networkInBytesPerSec: networkInBytesPerSec,
            networkOutBytesPerSec: networkOutBytesPerSec,
            updatedAt: Date().timeIntervalSince1970
        )
    }

    static var placeholder: MetricsSnapshot {
        .make(
            cpuUsage: 0,
            memoryUsedBytes: 0,
            memoryTotalBytes: 1,
            networkInBytesPerSec: 0,
            networkOutBytesPerSec: 0
        )
    }
}

/// Persisted counters so CPU/network deltas work across process launches and widget reloads.
struct MetricsBaseline: Codable, Equatable {
    var cpuUser: UInt32
    var cpuSystem: UInt32
    var cpuIdle: UInt32
    var cpuNice: UInt32
    var networkInBytes: UInt64
    var networkOutBytes: UInt64
    var timestamp: TimeInterval
}

enum ByteFormat {
    static func memory(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }

    static func rate(_ bytesPerSec: Double) -> String {
        let value = max(0, bytesPerSec)
        if value < 1024 {
            return String(format: "%.0f B/s", value)
        }
        if value < 1024 * 1024 {
            return String(format: "%.1f KB/s", value / 1024)
        }
        return String(format: "%.1f MB/s", value / (1024 * 1024))
    }

    static func percent(_ ratio: Double) -> String {
        String(format: "%.0f%%", min(1, max(0, ratio)) * 100)
    }
}
