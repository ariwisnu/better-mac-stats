import Foundation
import Darwin
#if canImport(CoreWLAN)
import CoreWLAN
#endif

/// Aggregate up/down throughput via `getifaddrs` interface counters, plus the
/// primary interface name, local IP and a best-effort connection type.
public final class NetworkReader {
    private var lastIn: UInt64 = 0
    private var lastOut: UInt64 = 0
    private var lastTime: Date?
    private lazy var wifiName: String? = Self.wifiInterfaceName()

    public init() {}

    public func read(at now: Date = Date()) -> NetworkUsage {
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var primaryName: String?
        var localIP: String?

        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0 else { return .zero }
        defer { freeifaddrs(ifaddrPtr) }

        var ptr = ifaddrPtr
        while let cur = ptr {
            let ifa = cur.pointee
            ptr = ifa.ifa_next
            let name = String(cString: ifa.ifa_name)
            let flags = ifa.ifa_flags
            let isUp = (flags & UInt32(IFF_UP)) != 0
            let isLoopback = (flags & UInt32(IFF_LOOPBACK)) != 0
            guard isUp, !isLoopback, let addr = ifa.ifa_addr else { continue }
            let family = addr.pointee.sa_family

            if family == UInt8(AF_LINK), let raw = ifa.ifa_data {
                let stats = raw.assumingMemoryBound(to: if_data.self).pointee
                totalIn &+= UInt64(stats.ifi_ibytes)
                totalOut &+= UInt64(stats.ifi_obytes)
            } else if family == UInt8(AF_INET), name.hasPrefix("en"), localIP == nil {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count),
                               nil, 0, NI_NUMERICHOST) == 0 {
                    localIP = String(cString: host)
                    primaryName = name
                }
            }
        }

        var up = 0.0, down = 0.0
        if let last = lastTime {
            let dt = now.timeIntervalSince(last)
            if dt > 0 {
                down = totalIn >= lastIn ? Double(totalIn - lastIn) / dt : 0
                up = totalOut >= lastOut ? Double(totalOut - lastOut) / dt : 0
            }
        }
        lastIn = totalIn; lastOut = totalOut; lastTime = now

        var connType: String?
        if let primary = primaryName {
            connType = (primary == wifiName) ? "Wi-Fi" : "Ethernet"
        }

        return NetworkUsage(uploadBytesPerSec: up, downloadBytesPerSec: down,
                            totalUploaded: totalOut, totalDownloaded: totalIn,
                            interfaceName: primaryName, localIP: localIP, connectionType: connType)
    }

    private static func wifiInterfaceName() -> String? {
        #if canImport(CoreWLAN)
        return CWWiFiClient.shared().interface()?.interfaceName
        #else
        return nil
        #endif
    }
}
