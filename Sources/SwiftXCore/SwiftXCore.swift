import Foundation

public final class SwiftXCore: @unchecked Sendable {
    private let config: ServerConfig
    private let scheduler: Scheduler
    private let router = RadixRouter()
    private let listener: Listener
    private var middlewares: [@Sendable (Request, TaskContext) -> Bool] = []
    private let lock = NSLock()

    public init(config: ServerConfig = ServerConfig()) {
        self.config = config
        self.scheduler = Scheduler(config: config, router: self.router)
        self.listener = Listener(port: config.port)
    }

    public func use(_ middleware: @escaping @Sendable (Request, TaskContext) -> Bool) {
        lock.lock()
        defer { lock.unlock() }
        middlewares.append(middleware)
    }

    public func route(_ method: String, _ path: String, handler: @escaping @Sendable (Request, TaskContext) -> Response) {
        router.addRoute(method: method, path: path) { [weak self] req, ctx in
            // Execute middlewares
            self?.lock.lock()
            let currentMiddlewares = self?.middlewares ?? []
            self?.lock.unlock()
            
            for middleware in currentMiddlewares {
                if !middleware(req, ctx) {
                    return Response(status: 403, headers: ["Content-Type": "text/plain"], body: Data("Forbidden by Middleware".utf8))
                }
            }
            
            return handler(req, ctx)
        }
    }
    
    public func route(_ method: String, _ path: String, handler: @escaping @Sendable (Request) -> Response) {
        route(method, path) { req, ctx in
            return handler(req)
        }
    }

    public var activeWorkersCount: Int {
        return scheduler.activeWorkersCount
    }

    public var totalActiveConnections: Int {
        return scheduler.totalActiveConnections
    }

    public func listen(_ port: Int? = nil) {
        scheduler.start()
        
        while true {
            var acceptedAny = false
            while let clientSocket = listener.accept() {
                acceptedAny = true
                clientSocket.setNonBlocking()
                clientSocket.setNoDelay()
                scheduler.schedule(socket: clientSocket)
            }
            
            if !acceptedAny {
                Thread.sleep(forTimeInterval: 0.0001)
            }
        }
    }
}
