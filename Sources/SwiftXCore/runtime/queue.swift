import Foundation

public final class RingBufferQueue<T>: @unchecked Sendable {
    private var buffer: [T?]
    private var head: Int = 0
    private var tail: Int = 0
    private let capacity: Int
    private let lock = NSLock()

    public init(capacity: Int = 1024) {
        self.capacity = capacity
        self.buffer = [T?](repeating: nil, count: capacity)
    }

    public func push(_ item: T) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let nextTail = (tail + 1) % capacity
        if nextTail == head {
            return false // Full
        }

        buffer[tail] = item
        tail = nextTail
        return true
    }

    public func pop() -> T? {
        lock.lock()
        defer { lock.unlock() }

        if head == tail {
            return nil // Empty
        }

        let item = buffer[head]
        buffer[head] = nil
        head = (head + 1) % capacity
        return item
    }

    public var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return head == tail
    }
}
