import Foundation

public enum IOEvent {
    case read(Socket)
    case write(Socket)
    case error(Socket)
}

public protocol IOBackend: Sendable {
    func register(_ socket: Socket)
    func unregister(_ socket: Socket)
    func poll(timeout: Int) -> [IOEvent]
}
