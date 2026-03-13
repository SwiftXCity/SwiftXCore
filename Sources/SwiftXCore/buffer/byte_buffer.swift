import Foundation

public final class ByteBuffer: @unchecked Sendable {
    private var storage: UnsafeMutablePointer<UInt8>
    private var capacity: Int
    public private(set) var readIndex: Int = 0
    public private(set) var writeIndex: Int = 0

    public var readableBytes: Int {
        return writeIndex - readIndex
    }

    public var writableBytes: Int {
        return capacity - writeIndex
    }

    public init(capacity: Int = 4096) {
        self.capacity = capacity
        self.storage = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
    }

    deinit {
        storage.deallocate()
    }

    public func ensureCapacity(_ additional: Int) {
        if writableBytes < additional {
            let newCapacity = max(capacity * 2, writeIndex + additional)
            let newStorage = UnsafeMutablePointer<UInt8>.allocate(capacity: newCapacity)
            newStorage.moveInitialize(from: storage, count: writeIndex)
            storage.deallocate()
            storage = newStorage
            capacity = newCapacity
        }
    }

    public func writeBytes(_ bytes: UnsafePointer<UInt8>, count: Int) {
        ensureCapacity(count)
        storage.advanced(by: writeIndex).initialize(from: bytes, count: count)
        writeIndex += count
    }

    public func writeBytes(_ bytes: [UInt8]) {
        bytes.withUnsafeBufferPointer { ptr in
            writeBytes(ptr.baseAddress!, count: bytes.count)
        }
    }

    public func readData(count: Int) -> Data? {
        guard readableBytes >= count else { return nil }
        let data = Data(bytes: storage.advanced(by: readIndex), count: count)
        readIndex += count
        
        // Compact if needed
        if readIndex > capacity / 2 {
            storage.moveInitialize(from: storage.advanced(by: readIndex), count: readableBytes)
            writeIndex -= readIndex
            readIndex = 0
        }
        
        return data
    }
    
    public func peekData() -> Data {
        return Data(bytesNoCopy: storage.advanced(by: readIndex), count: readableBytes, deallocator: .none)
    }
    
    public func consume(count: Int) {
        readIndex += count
    }

    public func clear() {
        readIndex = 0
        writeIndex = 0
    }
    
    public func withMutableWriteBuffer<R>(_ body: (UnsafeMutablePointer<UInt8>, Int) -> R) -> R {
        return body(storage.advanced(by: writeIndex), writableBytes)
    }
    
    public func commitWrite(_ count: Int) {
        writeIndex += count
    }
}
