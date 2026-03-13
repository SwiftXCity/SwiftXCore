import Foundation

public final class Scheduler: @unchecked Sendable {
    private let workers: [Worker]
    private var nextWorkerIndex: Int = 0
    private let lock = NSLock()

    public var activeWorkersCount: Int {
        return workers.filter { $0.activeConnectionCount > 0 }.count
    }

    public var totalActiveConnections: Int {
        return workers.reduce(0) { $0 + $1.activeConnectionCount }
    }

    public init(config: ServerConfig, router: RadixRouter) {
        var workers: [Worker] = []
        for i in 0..<config.workerCount {
            let backend: IOBackend
            #if os(macOS)
            backend = KQueueBackend()
            #elseif os(Linux)
            backend = EPollBackend()
            #elseif os(Windows)
            backend = WSAPollBackend()
            #else
            fatalError("Unsupported OS")
            #endif
            
            workers.append(Worker(id: i, ioBackend: backend, router: router))
        }
        self.workers = workers
    }

    public func start() {
        for worker in workers {
            worker.start()
        }
    }

    public func stop() {
        for worker in workers {
            worker.stop()
        }
    }

    public func schedule(task: Task) {
        lock.lock()
        let index = nextWorkerIndex
        nextWorkerIndex = (nextWorkerIndex + 1) % workers.count
        lock.unlock()

        workers[index].submit(task: task)
    }

    public func schedule(socket: Socket) {
        lock.lock()
        let index = nextWorkerIndex
        nextWorkerIndex = (nextWorkerIndex + 1) % workers.count
        lock.unlock()

        workers[index].registerConnection(socket)
    }
}
