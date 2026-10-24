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
        let (totalIn, totalOut) = Self.interfaceTotals()
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

            if family == UInt8(AF_INET), name.hasPrefix("en"), localIP == nil {
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

    /// Tunnels (VPN) and bridges carry traffic that is also counted on the physical
    /// interface underneath, so summing them would double the rate.
    static let virtualPrefixes = ["utun", "ipsec", "ppp", "gif", "stf", "bridge"]

    static func isCounted(interface name: String) -> Bool {
        !virtualPrefixes.contains { name.hasPrefix($0) }
    }

    /// Summed byte counters of every up, non-loopback, physical interface. Read
    /// from `NET_RT_IFLIST2` because `getifaddrs` only exposes 32-bit counters,
    /// which wrap every 4 GB.
    private static func interfaceTotals() -> (UInt64, UInt64) {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len = 0
        guard sysctl(&mib, 6, nil, &len, nil, 0) == 0, len > 0 else { return (0, 0) }
        var buf = [UInt8](repeating: 0, count: len)
        guard sysctl(&mib, 6, &buf, &len, nil, 0) == 0 else { return (0, 0) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        buf.withUnsafeBytes { raw in
            var off = 0
            while off + MemoryLayout<if_msghdr>.size <= len {
                let msg = raw.loadUnaligned(fromByteOffset: off, as: if_msghdr.self)
                guard msg.ifm_msglen > 0 else { break }
                if Int32(msg.ifm_type) == RTM_IFINFO2,
                   off + MemoryLayout<if_msghdr2>.size <= len {
                    let info = raw.loadUnaligned(fromByteOffset: off, as: if_msghdr2.self)
                    var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
                    if info.ifm_flags & IFF_UP != 0, info.ifm_flags & IFF_LOOPBACK == 0,
                       if_indextoname(UInt32(info.ifm_index), &name) != nil,
                       isCounted(interface: String(cString: name)) {
                        totalIn &+= info.ifm_data.ifi_ibytes
                        totalOut &+= info.ifm_data.ifi_obytes
                    }
                }
                off += Int(msg.ifm_msglen)
            }
        }
        return (totalIn, totalOut)
    }

    private static func wifiInterfaceName() -> String? {
        #if canImport(CoreWLAN)
        return CWWiFiClient.shared().interface()?.interfaceName
        #else
        return nil
        #endif
    }
}
