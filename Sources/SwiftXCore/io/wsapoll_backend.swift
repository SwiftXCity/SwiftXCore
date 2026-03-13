import Foundation

#if os(Windows)
import WinSDK

public final class WSAPollBackend: IOBackend, @unchecked Sendable {
    private var pollfds: [WSAPOLLFD] = []
    private var sockets: [Int: Socket] = [:]
    private let lock = NSLock()
    
    // Persistent buffer for polling to avoid allocations
    private var pollBuffer: UnsafeMutablePointer<WSAPOLLFD>
    private var bufferCapacity: Int

    public init() {
        self.bufferCapacity = 1024
        self.pollBuffer = UnsafeMutablePointer<WSAPOLLFD>.allocate(capacity: 1024)
    }
    
    deinit {
        pollBuffer.deallocate()
    }

    private func ensureBufferCapacity(_ count: Int) {
        if count > bufferCapacity {
            pollBuffer.deallocate()
            bufferCapacity = max(bufferCapacity * 2, count)
            pollBuffer = UnsafeMutablePointer<WSAPOLLFD>.allocate(capacity: bufferCapacity)
        }
    }

    public func register(_ socket: Socket) {
        lock.lock()
        defer { lock.unlock() }
        
        if sockets[socket.fd] != nil { return }
        
        let fd = SOCKET(bitPattern: Int64(socket.fd))
        let pfd = WSAPOLLFD(fd: fd, events: Int16(POLLRDNORM), revents: 0)
        pollfds.append(pfd)
        sockets[socket.fd] = socket
    }

    public func unregister(_ socket: Socket) {
        lock.lock()
        defer { lock.unlock() }
        
        let fdToFind = Int64(socket.fd)
        if let index = pollfds.firstIndex(where: { Int64(bitPattern: $0.fd) == fdToFind }) {
            pollfds.remove(at: index)
        }
        sockets.removeValue(forKey: socket.fd)
    }

    public func poll(timeout: Int) -> [IOEvent] {
        lock.lock()
        if pollfds.isEmpty {
            lock.unlock()
            if timeout > 0 {
                Thread.sleep(forTimeInterval: Double(timeout) / 1000.0)
            }
            return []
        }
        
        let count = pollfds.count
        ensureBufferCapacity(count)
        
        // Copy to stable buffer
        for i in 0..<count {
            pollBuffer[i] = pollfds[i]
        }
        lock.unlock()
        
        let result = WSAPoll(pollBuffer, ULONG(count), Int32(timeout))
        
        var events: [IOEvent] = []
        if result > 0 {
            for i in 0..<count {
                let revents = pollBuffer[i].revents
                if revents != 0 {
                    let fd = Int(bitPattern: UInt(pollBuffer[i].fd))
                    lock.lock()
                    if let sock = sockets[fd] {
                        if revents & Int16(POLLRDNORM) != 0 {
                            events.append(.read(sock))
                        } else if revents & (Int16(POLLERR) | Int16(POLLHUP)) != 0 {
                            events.append(.error(sock))
                        }
                    }
                    lock.unlock()
                }
            }
        }
        
        return events
    }
}
#endif
