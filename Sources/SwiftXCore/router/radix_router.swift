import Foundation

public final class RadixNode: @unchecked Sendable {
    public var segment: String
    public var children: [String: RadixNode] = [:]
    public var handler: (@Sendable (Request, TaskContext) -> Response)?
    public var parameterName: String?

    public init(segment: String) {
        self.segment = segment
    }
}

public final class RadixRouter: @unchecked Sendable {
    private let root = RadixNode(segment: "")
    private let lock = NSLock()
    
    // Cache for static paths to avoid segmenting
    private var staticCache: [String: (@Sendable (Request, TaskContext) -> Response)] = [:]
    private let cacheLock = NSLock()

    public func addRoute(method: String, path: String, handler: @escaping @Sendable (Request, TaskContext) -> Response) {
        let segments = path.split(separator: "/", omittingEmptySubsequences: true)
        
        lock.lock()
        var current = root
        var isDynamic = false
        for segment in segments {
            let key: String
            var paramName: String? = nil

            if segment.hasPrefix(":") {
                key = ":"
                paramName = String(segment.dropFirst())
                isDynamic = true
            } else {
                key = String(segment)
            }

            if let next = current.children[key] {
                current = next
            } else {
                let newNode = RadixNode(segment: String(segment))
                newNode.parameterName = paramName
                current.children[key] = newNode
                current = newNode
            }
        }
        current.handler = handler
        lock.unlock()
        
        // Add to static cache if no parameters
        if !isDynamic {
            cacheLock.lock()
            staticCache[path] = handler
            cacheLock.unlock()
        }
    }

    public func lookup(path: String) -> (handler: (@Sendable (Request, TaskContext) -> Response)?, params: [String: String]) {
        // Fast static check
        cacheLock.lock()
        if let handler = staticCache[path] {
            cacheLock.unlock()
            return (handler, [:])
        }
        cacheLock.unlock()

        let segments = path.split(separator: "/", omittingEmptySubsequences: true)
        
        var current = root
        var params: [String: String] = [:]

        // Using a lock-free approach for lookup if we can assume no mutations
        // But for safety let's use the current structure
        for segment in segments {
            let s = String(segment)
            if let next = current.children[s] {
                current = next
            } else if let next = current.children[":"] {
                if let paramName = next.parameterName {
                    params[paramName] = s
                }
                current = next
            } else {
                return (nil, [:])
            }
        }

        return (current.handler, params)
    }
}
