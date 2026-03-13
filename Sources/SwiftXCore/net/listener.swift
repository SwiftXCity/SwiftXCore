import Foundation

#if os(Windows)
import WinSDK
#elseif os(Linux)
import Glibc
#elseif os(macOS)
import Darwin
#endif

public final class Listener: @unchecked Sendable {
    private let serverSocket: Socket
    private let port: Int

    public init(port: Int) {
        self.port = port
        
        #if os(Windows)
        var wsaData = WSADATA()
        _ = WSAStartup(0x0202, &wsaData)
        let fd = WinSDK.socket(AF_INET, SOCK_STREAM, Int32(IPPROTO_TCP.rawValue))
        if fd == INVALID_SOCKET {
            fatalError("Failed to create server socket")
        }
        #else
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        if fd == -1 {
            fatalError("Failed to create server socket")
        }
        #endif
        
        self.serverSocket = Socket(fd: Int(fd))
        setupSocket()
    }

    private func setupSocket() {
        var opt: Int32 = 1
        var bufSize: Int32 = 1024 * 1024 // 1MB buffer
        #if os(Windows)
        let s = SOCKET(bitPattern: Int64(serverSocket.fd))
        setsockopt(s, SOL_SOCKET, SO_REUSEADDR, UnsafeRawPointer(&opt), Int32(MemoryLayout<Int32>.size))
        setsockopt(s, SOL_SOCKET, SO_RCVBUF, UnsafeRawPointer(&bufSize), Int32(MemoryLayout<Int32>.size))
        setsockopt(s, SOL_SOCKET, SO_SNDBUF, UnsafeRawPointer(&bufSize), Int32(MemoryLayout<Int32>.size))
        #else
        var optVal = opt
        setsockopt(Int32(serverSocket.fd), SOL_SOCKET, SO_REUSEADDR, &optVal, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(Int32(serverSocket.fd), SOL_SOCKET, SO_RCVBUF, &bufSize, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(Int32(serverSocket.fd), SOL_SOCKET, SO_SNDBUF, &bufSize, socklen_t(MemoryLayout<Int32>.size))
        #endif

        #if os(Windows)
        var addr = sockaddr_in()
        addr.sin_family = ADDRESS_FAMILY(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        addr.sin_addr.S_un.S_addr = INADDR_ANY
        #else
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        addr.sin_addr.s_addr = INADDR_ANY
        #endif

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                #if os(Windows)
                WinSDK.bind(SOCKET(bitPattern: Int64(serverSocket.fd)), $0, Int32(MemoryLayout<sockaddr_in>.size))
                #else
                Darwin.bind(Int32(serverSocket.fd), $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                #endif
            }
        }

        if bindResult == -1 {
            fatalError("Failed to bind to port \(port)")
        }

        #if os(Windows)
        WinSDK.listen(SOCKET(bitPattern: Int64(serverSocket.fd)), SOMAXCONN)
        #else
        Darwin.listen(Int32(serverSocket.fd), SOMAXCONN)
        #endif
        
        serverSocket.setNonBlocking()
    }

    public func accept() -> Socket? {
        var clientAddr = sockaddr()
        var clientAddrLen = socklen_t(MemoryLayout<sockaddr>.size)
        
        #if os(Windows)
        let s = SOCKET(bitPattern: Int64(serverSocket.fd))
        let clientFd = WinSDK.accept(s, &clientAddr, &clientAddrLen)
        if clientFd == INVALID_SOCKET {
            return nil
        }
        #else
        let clientFd = Darwin.accept(Int32(serverSocket.fd), &clientAddr, &clientAddrLen)
        if clientFd == -1 {
            return nil
        }
        #endif
        
        return Socket(fd: Int(clientFd))
    }
}
