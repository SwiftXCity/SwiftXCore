import SwiftXCore
import Foundation

let config = ServerConfig(port: 8080, workerCount: 32)
let app = SwiftXCore(config: config)

// 1. Core Metrics
app.route("GET", "/metrics") { req in
    return Response.json([
        "active_workers": app.activeWorkersCount,
        "active_connections": app.totalActiveConnections
    ])
}

// 2. Simple Routes
app.route("GET", "/hello") { req in
    return Response.text("Hello from SwiftX Core!")
}

// 3. System Information
app.route("GET", "/info") { req in
    let info: [String: Any] = [
        "core": Core.info(),
        "os": Core.os(),
        "process": Core.process(),
        "query": req.query
    ]
    return Response.json(info)
}

// 4. Deterministic Non-Blocking Wait
app.route("GET", "/wait") { req, ctx in
    if let waited: Bool = ctx.get("is_resumed"), waited {
        return Response.text("Task resumed after non-blocking sleep!")
    }
    
    ctx.set("is_resumed", true)
    ctx.sleep(ms: 2000) // Non-blocking wait
    
    return Response.text("Wait...") 
}

// 5. Benchmark Performance Route (High speed)
app.route("GET", "/benchmark") { req in
    return Response.text("PONG")
}

print("🚀 SwiftX Core Production-Ready Server")
print("------------------------------------------")
print("System: \(Core.os()["platform"] ?? "Unknown")")
print("Process ID: \(Core.process()["pid"] ?? 0)")
print("Listening on http://localhost:8080")

app.listen()
