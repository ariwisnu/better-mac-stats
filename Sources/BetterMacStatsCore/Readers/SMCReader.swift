import Foundation
import IOKit

/// Minimal AppleSMC client for temperatures, fans and power sensors.
///
/// The SMC is undocumented and its key set varies wildly between Intel and Apple
/// Silicon Macs, so this reader probes a curated key list and silently skips keys
/// that are absent or return implausible values. On Macs where the SMC exposes
/// nothing useful, `read()` returns an empty array and the UI shows a graceful
/// "no sensors" state rather than crashing.
///
/// The kernel's `SMCKeyData_t` is an 80-byte C struct whose layout Swift does not
/// reproduce (Swift packs it to 76 bytes, which the kernel rejects with
/// kIOReturnBadArgument). We therefore marshal the request/response as a raw
/// 80-byte buffer with explicit field offsets, which is ABI-exact.
public final class SMCReader {

    // Field offsets inside the 80-byte SMCKeyData_t.
    private static let bufferSize = 80
    private static let offKey = 0          // UInt32 fourCC
    private static let offDataSize = 28    // keyInfo.dataSize  (UInt32)
    private static let offDataType = 32    // keyInfo.dataType  (UInt32 fourCC)
    private static let offResult = 40      // UInt8
    private static let offData8 = 42       // UInt8 command
    private static let offBytes = 48       // 32-byte payload

    private static let selector: UInt32 = 2        // kSMCHandleYPCEvent
    private static let cmdReadBytes: UInt8 = 5
    private static let cmdReadKeyInfo: UInt8 = 9

    private var connection: io_connect_t = 0
    private var opened = false
    private var unsupported = false

    public init() {}
    deinit { close() }

    // MARK: Curated probe list

    private struct Probe { let key: String; let name: String; let kind: SensorKind; let unit: String }

    private static let probes: [Probe] = {
        var p: [Probe] = []
        func temp(_ k: String, _ n: String) { p.append(Probe(key: k, name: n, kind: .temperature, unit: "°C")) }
        func fan(_ k: String, _ n: String) { p.append(Probe(key: k, name: n, kind: .fan, unit: "RPM")) }
        func power(_ k: String, _ n: String) { p.append(Probe(key: k, name: n, kind: .power, unit: "W")) }

        // Intel CPU / GPU
        temp("TC0P", "CPU Proximity"); temp("TC0D", "CPU Die"); temp("TC0E", "CPU"); temp("TC0F", "CPU")
        temp("TG0P", "GPU Proximity"); temp("TG0D", "GPU Die")
        temp("Ts0P", "Skin"); temp("Ts1P", "Skin"); temp("TA0P", "Ambient"); temp("TA1P", "Ambient")
        temp("Tm0P", "Memory"); temp("TB0T", "Battery"); temp("TB1T", "Battery"); temp("TB2T", "Battery")
        // Apple Silicon CPU/GPU cluster sensors (subset; absent keys are skipped)
        for k in ["Tp01", "Tp05", "Tp09", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0T", "Tp0X", "Tp0b", "Tp0f"] {
            temp(k, "CPU Core")
        }
        for k in ["Tg05", "Tg0D", "Tg0L", "Tg0f", "Tg0j"] { temp(k, "GPU Cluster") }
        temp("Te05", "Efficiency Core"); temp("Th0x", "Heatsink")
        // Fans
        for i in 0 ..< 4 { fan("F\(i)Ac", "Fan \(i + 1)") }
        // Power
        power("PSTR", "System Total"); power("PCPC", "CPU"); power("PCPG", "GPU")
        return p
    }()

    // MARK: Lifecycle

    @discardableResult
    private func open() -> Bool {
        if opened { return true }
        if unsupported { return false }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { unsupported = true; return false }
        defer { IOObjectRelease(service) }

        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == kIOReturnSuccess else {
            unsupported = true
            return false
        }
        opened = true
        return true
    }

    private func close() {
        if opened { IOServiceClose(connection); opened = false }
    }

    public var isAvailable: Bool { open() }

    // MARK: Read

    public func read() -> [SensorReading] {
        guard open() else { return [] }
        var out: [SensorReading] = []
        for probe in Self.probes {
            guard let v = value(forKey: probe.key) else { continue }
            switch probe.kind {
            case .temperature where !(v > -40 && v < 150): continue
            case .fan where !(v >= 0 && v < 12000): continue
            case .power where !(v >= 0 && v < 1000): continue
            default: break
            }
            out.append(SensorReading(key: probe.key, name: probe.name, value: v, unit: probe.unit, kind: probe.kind))
        }
        return out
    }

    // MARK: SMC primitives

    private func value(forKey key: String) -> Double? {
        var keyInfoReq = [UInt8](repeating: 0, count: Self.bufferSize)
        Self.putU32(&keyInfoReq, Self.offKey, Self.fourCC(key))
        keyInfoReq[Self.offData8] = Self.cmdReadKeyInfo
        guard let info = call(keyInfoReq), info[Self.offResult] == 0 else { return nil }

        let size = Int(Self.getU32(info, Self.offDataSize))
        let type = Self.typeString(Self.getU32(info, Self.offDataType))
        guard size > 0, size <= 32 else { return nil }

        var readReq = [UInt8](repeating: 0, count: Self.bufferSize)
        Self.putU32(&readReq, Self.offKey, Self.fourCC(key))
        readReq[Self.offData8] = Self.cmdReadBytes
        Self.putU32(&readReq, Self.offDataSize, UInt32(size))
        guard let out = call(readReq), out[Self.offResult] == 0 else { return nil }

        let bytes = Array(out[Self.offBytes ..< Self.offBytes + size])
        return Self.decode(bytes: bytes, type: type, size: size)
    }

    private func call(_ input: [UInt8]) -> [UInt8]? {
        var output = [UInt8](repeating: 0, count: Self.bufferSize)
        var outSize = Self.bufferSize
        let kr = input.withUnsafeBytes { inPtr in
            output.withUnsafeMutableBytes { outPtr in
                IOConnectCallStructMethod(connection, Self.selector,
                                          inPtr.baseAddress, Self.bufferSize,
                                          outPtr.baseAddress, &outSize)
            }
        }
        return kr == kIOReturnSuccess ? output : nil
    }

    // MARK: Encoding helpers

    private static func putU32(_ buffer: inout [UInt8], _ offset: Int, _ value: UInt32) {
        buffer[offset] = UInt8(value & 0xff)
        buffer[offset + 1] = UInt8((value >> 8) & 0xff)
        buffer[offset + 2] = UInt8((value >> 16) & 0xff)
        buffer[offset + 3] = UInt8((value >> 24) & 0xff)
    }

    private static func getU32(_ buffer: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(buffer[offset]) | UInt32(buffer[offset + 1]) << 8
            | UInt32(buffer[offset + 2]) << 16 | UInt32(buffer[offset + 3]) << 24
    }

    private static func fourCC(_ s: String) -> UInt32 {
        var r: UInt32 = 0
        for b in s.utf8.prefix(4) { r = (r << 8) | UInt32(b) }
        return r
    }

    private static func typeString(_ t: UInt32) -> String {
        let bytes = [UInt8((t >> 24) & 0xff), UInt8((t >> 16) & 0xff), UInt8((t >> 8) & 0xff), UInt8(t & 0xff)]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }

    private static func decode(bytes: [UInt8], type: String, size: Int) -> Double? {
        func float32LE() -> Double? {
            guard size >= 4 else { return nil }
            let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            return Double(Float(bitPattern: bits))
        }
        switch type {
        case "flt ": return float32LE()
        case "sp78":
            guard size >= 2 else { return nil }
            let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
            return Double(raw) / 256.0
        case "fpe2":
            guard size >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4.0
        case "fp2e":
            guard size >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 16384.0
        case "ui8 ": return size >= 1 ? Double(bytes[0]) : nil
        case "ui16": return size >= 2 ? Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) : nil
        case "ui32":
            guard size >= 4 else { return nil }
            return Double(UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3]))
        case "si8 ": return size >= 1 ? Double(Int8(bitPattern: bytes[0])) : nil
        case "si16":
            guard size >= 2 else { return nil }
            return Double(Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1])))
        default:
            if let f = float32LE(), f.isFinite { return f }
            return nil
        }
    }
}
