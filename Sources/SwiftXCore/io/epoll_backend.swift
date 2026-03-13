import Foundation

#if os(Linux)
import Glibc

public final class EPollBackend: IOBackend, @unchecked Sendable {
    private let epfd: Int32
    private var socketMap: [Int32: Socket] = [:]

    public init() {
        self.epfd = epoll_create1(0)
        if epfd == -1 {
            fatalError("Failed to create epoll")
        }
    }

    public func register(_ socket: Socket) {
        var event = epoll_event()
        event.events = UInt32(EPOLLIN.rawValue) | UInt32(EPOLLET.rawValue)
        event.data.fd = Int32(socket.fd)
        
        epoll_ctl(epfd, EPOLL_CTL_ADD, Int32(socket.fd), &event)
        socketMap[Int32(socket.fd)] = socket
    }

    public func unregister(_ socket: Socket) {
        epoll_ctl(epfd, EPOLL_CTL_DEL, Int32(socket.fd), nil)
        socketMap.removeValue(forKey: Int32(socket.fd))
    }

    public func poll(timeout: Int) -> [IOEvent] {
        var events = [epoll_event](repeating: epoll_event(), count: 1024)
        let count = epoll_wait(epfd, &events, 1024, Int32(timeout))
        
        var results: [IOEvent] = []
        for i in 0..<Int(count) {
            let event = events[i]
            let fd = event.data.fd
            if let socket = socketMap[fd] {
                if (event.events & UInt32(EPOLLIN.rawValue)) != 0 {
                    results.append(.read(socket))
                }
                if (event.events & UInt32(EPOLLOUT.rawValue)) != 0 {
                    results.append(.write(socket))
                }
            }
        }
        return results
    }
}
#endif
