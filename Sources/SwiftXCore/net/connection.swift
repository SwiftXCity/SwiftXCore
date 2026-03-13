import Foundation

#if os(Windows)
import WinSDK
#elseif os(Linux)
import Glibc
#elseif os(macOS)
import Darwin
#endif

public enum ConnectionState {
    case connected
    case closing
    case closed
}

public final class Connection: @unchecked Sendable {
    public let socket: Socket
    public let buffer: ByteBuffer
    public var state: ConnectionState
    public private(set) weak var worker: Worker?

    public init(socket: Socket, worker: Worker) {
        self.socket = socket
        self.buffer = ByteBuffer(capacity: 16384)
        self.state = .connected
        self.worker = worker
    }

    public func send(data: Data) {
        guard state == .connected else { return }
        
        #if os(Windows)
        let s = SOCKET(bitPattern: Int64(socket.fd))
        data.withUnsafeBytes { ptr in
            _ = WinSDK.send(s, ptr.baseAddress?.assumingMemoryBound(to: Int8.self), Int32(data.count), 0)
        }
        #else
        _ = data.withUnsafeBytes { ptr in
            Darwin.send(Int32(socket.fd), ptr.baseAddress!, data.count, 0)
        }
        #endif
    }

    public func close() {
        state = .closed
        #if os(Windows)
        let s = SOCKET(bitPattern: Int64(socket.fd))
        _ = WinSDK.shutdown(s, Int32(SD_SEND))
        #else
        _ = Darwin.shutdown(Int32(socket.fd), SHUT_WR)
        #endif
        socket.close()
    }
}
