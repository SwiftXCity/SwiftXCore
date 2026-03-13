import Foundation

public struct ServerConfig: Sendable {
    public let port: Int
    public let workerCount: Int
    public let maxConnections: Int
    public let keepAlive: Bool

    public init(
        port: Int = 8080,
        workerCount: Int = ProcessInfo.processInfo.activeProcessorCount,
        maxConnections: Int = 10000,
        keepAlive: Bool = true
    ) {
        self.port = port
        self.workerCount = workerCount
        self.maxConnections = maxConnections
        self.keepAlive = keepAlive
    }
}
