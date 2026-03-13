import Foundation

#if os(Windows)
import WinSDK
#elseif os(Linux)
import Glibc
#elseif os(macOS)
import Darwin
#endif

public struct RuntimeInfo: Sendable {
    public static func os() -> [String: String] {
        var info: [String: String] = [:]
        #if os(macOS)
        info["platform"] = "macOS"
        #elseif os(Linux)
        info["platform"] = "Linux"
        #elseif os(Windows)
        info["platform"] = "Windows"
        #endif
        
        info["arch"] = String(describing: ProcessInfo.processInfo.activeProcessorCount) + " cores"
        info["os_version"] = ProcessInfo.processInfo.operatingSystemVersionString
        return info
    }

    public static func process() -> [String: Any] {
        var info: [String: Any] = [:]
        info["pid"] = ProcessInfo.processInfo.processIdentifier
        info["uptime"] = ProcessInfo.processInfo.systemUptime
        info["memory_usage"] = getMemoryUsage()
        info["env"] = ProcessInfo.processInfo.environment
        return info
    }

    private static func getMemoryUsage() -> UInt64 {
        #if os(macOS)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return kerr == KERN_SUCCESS ? info.resident_size : 0
        #else
        // Simplified for other platforms
        return 0 
        #endif
    }
}

public struct Core {
    public static func info() -> [String: String] {
        return [
            "name": "SwiftX Core",
            "version": "1.0.0-beta",
            "runtime": "Native Swift 6",
            "status": "Running"
        ]
    }
    
    public static func os() -> [String: String] {
        return RuntimeInfo.os()
    }
    
    public static func process() -> [String: Any] {
        return RuntimeInfo.process()
    }
}
