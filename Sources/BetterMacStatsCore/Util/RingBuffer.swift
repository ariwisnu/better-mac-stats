import Foundation

/// Fixed-capacity rolling history used to drive sparkline charts in popovers and
/// the menu bar without unbounded growth.
public struct RingBuffer<Element> {
    private var storage: [Element] = []
    public let capacity: Int

    public init(capacity: Int) {
        self.capacity = max(1, capacity)
        storage.reserveCapacity(self.capacity)
    }

    /// Append a value, evicting the oldest once capacity is exceeded.
    public mutating func push(_ value: Element) {
        storage.append(value)
        if storage.count > capacity {
            storage.removeFirst(storage.count - capacity)
        }
    }

    /// Oldest-to-newest values currently held.
    public var values: [Element] { storage }

    public var count: Int { storage.count }
    public var isEmpty: Bool { storage.isEmpty }
    public var last: Element? { storage.last }

    public mutating func clear() { storage.removeAll(keepingCapacity: true) }
}
