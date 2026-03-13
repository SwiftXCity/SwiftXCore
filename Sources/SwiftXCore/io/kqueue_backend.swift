import Foundation

#if os(macOS)
import Darwin

public final class KQueueBackend: IOBackend, @unchecked Sendable {
    private let kq: Int32
    private var socketMap: [Int32: Socket] = [:]

    public init() {
        self.kq = kqueue()
        if kq == -1 {
            fatalError("Failed to create kqueue")
        }
    }

    public func register(_ socket: Socket) {
        var event = kevent()
        event.ident = UInt(socket.fd)
        event.filter = Int16(EVFILT_READ)
        event.flags = UInt16(EV_ADD | EV_ENABLE)
        event.fflags = 0
        event.data = 0
        event.udata = nil

        var change = event
        kevent(kq, &change, 1, nil, 0, nil)
        socketMap[Int32(socket.fd)] = socket
    }

    public func unregister(_ socket: Socket) {
        var event = kevent()
        event.ident = UInt(socket.fd)
        event.filter = Int16(EVFILT_READ)
        event.flags = UInt16(EV_DELETE)
        var change = event
        kevent(kq, &change, 1, nil, 0, nil)
        socketMap.removeValue(forKey: Int32(socket.fd))
    }

    public func poll(timeout: Int) -> [IOEvent] {
        var events = [kevent](repeating: kevent(), count: 1024)
        var timeoutSpec = timespec(tv_sec: timeout / 1000, tv_nsec: (timeout % 1000) * 1_000_000)
        
        let count = kevent(kq, nil, 0, &events, 1024, &timeoutSpec)
        
        var results: [IOEvent] = []
        for i in 0..<Int(count) {
            let event = events[i]
            let fd = Int32(event.ident)
            if let socket = socketMap[fd] {
                if event.filter == EVFILT_READ {
                    results.append(.read(socket))
                } else if event.filter == EVFILT_WRITE {
                    results.append(.write(socket))
                }
            }
        }
        return results
    }
}
#endif
