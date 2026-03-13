import Foundation

#if os(Windows)
import WinSDK

public final class SelectBackend: IOBackend, @unchecked Sendable {
    private var sockets: [Socket] = []
    private let lock = NSLock()

    public init() {}

    public func register(_ socket: Socket) {
        lock.lock()
        defer { lock.unlock() }
        if !sockets.contains(where: { $0.fd == socket.fd }) {
            sockets.append(socket)
        }
    }

    public func unregister(_ socket: Socket) {
        lock.lock()
        defer { lock.unlock() }
        sockets.removeAll(where: { $0.fd == socket.fd })
    }

    public func poll(timeout: Int) -> [IOEvent] {
        lock.lock()
        let currentSockets = sockets
        lock.unlock()
        
        if currentSockets.isEmpty {
            if timeout > 0 {
                Thread.sleep(forTimeInterval: Double(timeout) / 1000.0)
            }
            return []
        }

        var events: [IOEvent] = []
        let batchSize = Int(FD_SETSIZE)
        
        // Split into batches of 64 (WinSDK FD_SETSIZE)
        var i = 0
        while i < currentSockets.count {
            var readSet = fd_set()
            readSet.fd_count = 0
            
            let end = min(i + batchSize, currentSockets.count)
            let batch = currentSockets[i..<end]
            
            for socket in batch {
                fd_set_add_safe(&readSet, socket.fd)
            }

            var timeVal = timeval()
            timeVal.tv_sec = 0
            timeVal.tv_usec = i == 0 ? Int32(timeout * 1000) : 0 // Only first batch waits

            let result = WinSDK.select(0, &readSet, nil, nil, &timeVal)
            
            if result > 0 {
                for j in 0..<Int(readSet.fd_count) {
                    let readyFd = get_fd_safe(&readSet, j)
                    if let originalSocket = currentSockets.first(where: { $0.fd == Int(readyFd) }) {
                        events.append(.read(originalSocket))
                    }
                }
            }
            
            i += batchSize
        }
        
        return events
    }

    private func fd_set_add_safe(_ set: inout fd_set, _ fd: Int) {
        let count = Int(set.fd_count)
        if count < FD_SETSIZE {
            let s = SOCKET(bitPattern: Int64(fd))
            withUnsafeMutablePointer(to: &set.fd_array) { ptr in
                let array = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: SOCKET.self)
                array[count] = s
            }
            set.fd_count += 1
        }
    }

    private func get_fd_safe(_ set: inout fd_set, _ index: Int) -> Int64 {
        return withUnsafePointer(to: &set.fd_array) { ptr in
            let array = UnsafeRawPointer(ptr).assumingMemoryBound(to: SOCKET.self)
            return Int64(bitPattern: array[index])
        }
    }
}
#endif
