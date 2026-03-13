import Foundation

#if os(Windows)
import WinSDK
#elseif os(Linux)
import Glibc
#elseif os(macOS)
import Darwin
#endif

public final class Socket: @unchecked Sendable {
    public let fd: Int
    
    public init(fd: Int) {
        self.fd = fd
    }
    
    public func setNonBlocking() {
        #if os(Windows)
        var mode: u_long = 1
        ioctlsocket(SOCKET(bitPattern: Int64(fd)), Int32(FIONBIO), &mode)
        #else
        let flags = fcntl(Int32(fd), F_GETFL, 0)
        _ = fcntl(Int32(fd), F_SETFL, flags | O_NONBLOCK)
        #endif
    }

    public func setNoDelay() {
        var opt: Int32 = 1
        #if os(Windows)
        let s = SOCKET(bitPattern: Int64(fd))
        WinSDK.setsockopt(s, Int32(IPPROTO_TCP.rawValue), WinSDK.TCP_NODELAY, UnsafeRawPointer(&opt), Int32(MemoryLayout<Int32>.size))
        #else
        var optVal = opt
        setsockopt(Int32(fd), IPPROTO_TCP, TCP_NODELAY, &optVal, socklen_t(MemoryLayout<Int32>.size))
        #endif
    }
    
    public func close() {
        #if os(Windows)
        closesocket(SOCKET(bitPattern: Int64(fd)))
        #elseif os(Linux)
        _ = Glibc.close(Int32(fd))
        #elseif os(macOS)
        _ = Darwin.close(Int32(fd))
        #endif
    }
}
