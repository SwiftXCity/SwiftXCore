import Foundation

#if os(Windows)
import WinSDK
#elseif os(Linux)
import Glibc
#elseif os(macOS)
import Darwin
#endif

public final class Worker: @unchecked Sendable {
    public let id: Int
    private let queue: RingBufferQueue<Task>
    private let ioBackend: IOBackend
    private let router: RadixRouter
    private var running: Bool = false
    private var suspendedTasks: [Foundation.UUID: (Task, Request)] = [:]
    private let lock = NSLock()
    private var connections: [Int: Connection] = [:]

    public var activeConnectionCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return connections.count
    }

    public init(id: Int, ioBackend: IOBackend, router: RadixRouter) {
        self.id = id
        self.queue = RingBufferQueue<Task>(capacity: 16384)
        self.ioBackend = ioBackend
        self.router = router
    }

    public func start() {
        running = true
        Thread.detachNewThread { [weak self] in
            self?.runLoop()
        }
    }

    public func stop() {
        running = false
    }

    public func registerConnection(_ socket: Socket) {
        let connection = Connection(socket: socket, worker: self)
        lock.lock()
        connections[socket.fd] = connection
        lock.unlock()
        ioBackend.register(socket)
    }

    public func submit(task: Task) {
        _ = queue.push(task)
    }

    private func runLoop() {
        while running {
            // Under high load, we want to decrease timeout to 1ms or 0
            let events = ioBackend.poll(timeout: 1)
            
            if !events.isEmpty {
                for event in events {
                    handleIOEvent(event)
                }
            }
            
            // Only check suspended tasks if there are any, to avoid Date() syscalls
            if !suspendedTasks.isEmpty {
                checkSuspendedTasks()
            }
            
            // Drain manual queue
            while let _ = queue.pop() {}
        }
    }

    private func checkSuspendedTasks() {
        var toResume: [(Task, Request)] = []
        lock.lock()
        if suspendedTasks.isEmpty {
            lock.unlock()
            return
        }
        let now = Date()
        var idsToRemove: [Foundation.UUID] = []
        for (id, tuple) in suspendedTasks {
            if let wakeAt = tuple.0.context.wakeAt, now >= wakeAt {
                idsToRemove.append(id)
                toResume.append(tuple)
            }
        }
        for id in idsToRemove {
            suspendedTasks.removeValue(forKey: id)
        }
        lock.unlock()
        for (task, request) in toResume {
            executeTask(task, request: request)
        }
    }

    private func handleIOEvent(_ event: IOEvent) {
        switch event {
        case .read(let socket):
            processRead(socket: socket)
        case .write(_):
            break
        case .error(let socket):
            closeConnection(fd: socket.fd)
        }
    }

    private func processRead(socket: Socket) {
        lock.lock()
        let connection = connections[socket.fd]
        lock.unlock()
        guard let conn = connection else { return }

        let bytesRead = conn.buffer.withMutableWriteBuffer { ptr, capacity in
            #if os(Windows)
            let s = SOCKET(bitPattern: Int64(socket.fd))
            return WinSDK.recv(s, UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: Int8.self), Int32(capacity), 0)
            #else
            return Darwin.recv(Int32(socket.fd), ptr, capacity, 0)
            #endif
        }

        if bytesRead <= 0 {
            closeConnection(fd: socket.fd)
            return
        }
        conn.buffer.commitWrite(Int(bytesRead))
        
        while true {
            let data = conn.buffer.peekData()
            if data.isEmpty { break }
            
            if let (request, consumed) = HTTPParser.scanRequest(data: data) {
                conn.buffer.consume(count: consumed)
                
                // Fast path for routing
                let (handler, params) = router.lookup(path: request.path)
                if let handler = handler {
                    let task = Task(connection: conn) { _, ctx in
                        // We pass the already parsed request and params
                        // In a real framework, we'd wrap this better
                        var reqWithParams = request
                        reqWithParams.params = params
                        return handler(reqWithParams, ctx)
                    }
                    executeTask(task, request: request)
                } else {
                    let response = Response(status: 404, headers: ["Content-Type": "text/plain"], body: Data("404 Not Found".utf8))
                    conn.send(data: HTTPEncoder.encode(response: response))
                }
            } else {
                break 
            }
        }
    }

    private func executeTask(_ task: Task, request: Request) {
        if let response = task.execute(request: request) {
            let encoded = HTTPEncoder.encode(response: response)
            task.connection?.send(data: encoded)
            if request.headers["Connection"]?.lowercased() == "close" {
                closeConnection(fd: task.connection?.socket.fd ?? -1)
            }
        } else {
            lock.lock()
            suspendedTasks[task.id] = (task, request)
            lock.unlock()
        }
    }

    private func closeConnection(fd: Int) {
        if fd < 0 { return }
        lock.lock()
        if let conn = connections.removeValue(forKey: fd) {
            ioBackend.unregister(conn.socket)
            conn.close()
        }
        lock.unlock()
    }
}
