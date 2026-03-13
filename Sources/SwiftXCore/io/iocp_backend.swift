import Foundation

#if os(Windows)
import WinSDK

public final class IOCPBackend: IOBackend, @unchecked Sendable {
    private let completionPort: HANDLE
    private var socketMap: [Int: Socket] = [:]
    private let lock = NSLock()

    public init() {
        let port = CreateIoCompletionPort(INVALID_HANDLE_VALUE, nil, 0, 0)
        guard let p = port else {
            fatalError("Failed to create IOCP")
        }
        self.completionPort = p
    }

    public func register(_ socket: Socket) {
        // For IOCP, we associate the socket with the completion port
        #if os(Windows)
        let s = HANDLE(bitPattern: Int(socket.fd))
        CreateIoCompletionPort(s, completionPort, 0, 0)
        #endif
        lock.lock()
        defer { lock.unlock() }
        socketMap[socket.fd] = socket
    }

    public func unregister(_ socket: Socket) {
        // IOCP doesn't have an explicit unregister, it's removed when closed
        lock.lock()
        defer { lock.unlock() }
        socketMap.removeValue(forKey: socket.fd)
    }

    public func poll(timeout: Int) -> [IOEvent] {
        var numberOfBytes: DWORD = 0
        var completionKey: ULONG_PTR = 0
        var overlapped: UnsafeMutablePointer<OVERLAPPED>? = nil
        
        let success = GetQueuedCompletionStatus(completionPort, &numberOfBytes, &completionKey, &overlapped, DWORD(timeout))
        
        var results: [IOEvent] = []
        if success {
            let fd = Int(completionKey)
            lock.lock()
            let socket = socketMap[fd]
            lock.unlock()
            
            if let socket = socket {
                results.append(.read(socket))
            }
        }
        return results
    }
}
#endif
