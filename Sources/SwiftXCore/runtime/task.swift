import Foundation

public enum TaskState {
    case running
    case suspended
    case ready
    case completed
}

public protocol TaskContext: AnyObject {
    func get<T>(_ key: String) -> T?
    func set<T>(_ key: String, _ value: T)
    func suspend()
    func sleep(ms: Int)
}

public final class DefaultTaskContext: TaskContext, @unchecked Sendable {
    private var storage: [String: Any] = [:]
    private let lock = NSLock()
    private(set) var isSuspended: Bool = false
    private(set) var wakeAt: Date? = nil

    public func get<T>(_ key: String) -> T? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key] as? T
    }

    public func set<T>(_ key: String, _ value: T) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
    }

    public func suspend() {
        isSuspended = true
    }

    public func sleep(ms: Int) {
        wakeAt = Date().addingTimeInterval(Double(ms) / 1000.0)
        isSuspended = true
    }
    
    public func resetSuspension() {
        isSuspended = false
        wakeAt = nil
    }
}

public final class Task: @unchecked Sendable {
    public let id: Foundation.UUID
    public var state: TaskState
    public let connection: Connection?
    public let handler: @Sendable (Request, TaskContext) -> Response
    public let context: DefaultTaskContext

    public init(connection: Connection? = nil, handler: @Sendable @escaping (Request, TaskContext) -> Response) {
        self.id = Foundation.UUID()
        self.state = .ready
        self.connection = connection
        self.handler = handler
        self.context = DefaultTaskContext()
    }

    public func execute(request: Request) -> Response? {
        state = .running
        context.resetSuspension()
        
        // This is a synchronous call. 
        // If the handler calls context.suspend(), we treat it as suspended.
        let response = handler(request, context)
        
        if context.isSuspended {
            state = .suspended
            return nil
        } else {
            state = .completed
            return response
        }
    }
}
