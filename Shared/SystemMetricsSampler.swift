import Darwin
import Foundation

final class SystemMetricsSampler {
    private var previous: MetricsBaseline?
    private var lastCPUUsage: Double = 0
    private var lastNetworkIn: Double = 0
    private var lastNetworkOut: Double = 0

    init() {
        // Prefer disk baseline if available, but in-memory is authoritative for this process.
        previous = MetricsStore.loadBaseline()
    }

    func sample() -> MetricsSnapshot {
        let memory = memoryUsage()
        let cpuTicks = readCPUTicks()
        let netTotals = interfaceByteTotals()
        let now = Date().timeIntervalSince1970

        if let cpuTicks, let previous, now - previous.timestamp >= 0.5 {
            let user = Double(cpuTicks.user &- previous.cpuUser)
            let system = Double(cpuTicks.system &- previous.cpuSystem)
            let idle = Double(cpuTicks.idle &- previous.cpuIdle)
            let nice = Double(cpuTicks.nice &- previous.cpuNice)
            let total = user + system + idle + nice
            if total > 0 {
                lastCPUUsage = min(1, max(0, (user + system + nice) / total))
            }

            let elapsed = max(0.5, now - previous.timestamp)
            lastNetworkIn = max(0, Double(netTotals.inBytes &- previous.networkInBytes) / elapsed)
            lastNetworkOut = max(0, Double(netTotals.outBytes &- previous.networkOutBytes) / elapsed)
        }

        let baseline = MetricsBaseline(
            cpuUser: cpuTicks?.user ?? previous?.cpuUser ?? 0,
            cpuSystem: cpuTicks?.system ?? previous?.cpuSystem ?? 0,
            cpuIdle: cpuTicks?.idle ?? previous?.cpuIdle ?? 0,
            cpuNice: cpuTicks?.nice ?? previous?.cpuNice ?? 0,
            networkInBytes: netTotals.inBytes,
            networkOutBytes: netTotals.outBytes,
            timestamp: now
        )
        previous = baseline
        _ = MetricsStore.saveBaseline(baseline)

        return .make(
            cpuUsage: lastCPUUsage,
            memoryUsedBytes: memory.used,
            memoryTotalBytes: memory.total,
            networkInBytesPerSec: lastNetworkIn,
            networkOutBytesPerSec: lastNetworkOut
        )
    }

    private func readCPUTicks() -> (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, rebound, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        return (
            info.cpu_ticks.0,
            info.cpu_ticks.1,
            info.cpu_ticks.2,
            info.cpu_ticks.3
        )
    }

    private func memoryUsage() -> (used: UInt64, total: UInt64) {
        var total: UInt64 = 0
        var totalSize = size_t(MemoryLayout<UInt64>.size)
        sysctlbyname("hw.memsize", &total, &totalSize, nil, 0)
        total = max(total, 1)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        guard result == KERN_SUCCESS else { return (0, total) }

        let pageSize = UInt64(vm_kernel_page_size)
        let used = min(
            total,
            UInt64(stats.active_count) * pageSize
                + UInt64(stats.wire_count) * pageSize
                + UInt64(stats.compressor_page_count) * pageSize
        )
        return (used, total)
    }

    private func interfaceByteTotals() -> (inBytes: UInt64, outBytes: UInt64) {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else {
            return (0, 0)
        }
        defer { freeifaddrs(ifaddrPtr) }

        var inBytes: UInt64 = 0
        var outBytes: UInt64 = 0
        var pointer: UnsafeMutablePointer<ifaddrs>? = first

        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            guard let addr = current.pointee.ifa_addr else { continue }
            guard addr.pointee.sa_family == sa_family_t(AF_LINK) else { continue }

            let name = String(cString: current.pointee.ifa_name)
            // Count common interfaces: Ethernet/Wi‑Fi (en*), and Thunderbolt bridges.
            guard name.hasPrefix("en") || name.hasPrefix("bridge") else { continue }
            guard let data = current.pointee.ifa_data else { continue }

            let networkData = data.assumingMemoryBound(to: if_data.self)
            inBytes += UInt64(networkData.pointee.ifi_ibytes)
            outBytes += UInt64(networkData.pointee.ifi_obytes)
        }

        return (inBytes, outBytes)
    }
}
