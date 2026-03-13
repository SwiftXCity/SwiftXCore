# 🚀 SwiftX Core

**SwiftX Core** is an ultra-fast, cross-platform, non-blocking HTTP and web runtime engine written entirely in pure Swift. 

It forms the low-level foundation for the broader SwiftX web framework, providing raw socket handling, a hyper-optimized byte-level HTTP parser, and deterministic cooperative multitasking that handles **100,000+ Requests Per Second (RPS)** on mid-range hardware without breaking a sweat.

We bypass standard blocking APIs and memory-heavy allocations by writing directly to in-place OS-level memory buffers (`WSAPoll`, `kqueue`, `epoll`). 

Whether you are on **macOS**, **Windows**, or **Linux**, SwiftX Core will scale horizontally to saturate all your CPU cores.

---

## ⚡ Key Features

- **🌐 Cross Platform Mastery**: Natively supports Windows (`WSAPoll` / `WinSDK`), Linux (`epoll` / `Glibc`), and macOS (`kqueue` / `Darwin`). 
- **🔥 Zero-Copy Byte Parsing**: Parses raw HTTP data directly from C-level memory pointers for negligible CPU allocation overhead. No massive `String` copies.
- **🛠️ Zero Internal Logs**: Core runtime has zero blocking console prints. You own your application logging using custom Middlewares.
- **🚥 Fully Pipelined `Keep-Alive`**: Can batch-read array allocations so hundreds of HTTP requests per connection won't block the handler.
- **📊 Real-time Metrics**: Out-of-the-box monitoring API for checking on active workers and connection load.
- **🚀 Static Route Caching**: A blazing Radix trie supplemented with an O(1) lock-free path lookup dictionary array.

---

## 📦 Installation

To use `SwiftXCore` inside your Swift package, add it to the `dependencies` inside your `Package.swift`:

```swift
// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "MySwiftServer",
    dependencies: [
        .package(url: "https://github.com/SwiftXCity/SwiftXCore.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MySwiftServer",
            dependencies: [
                .product(name: "SwiftXCore", package: "swiftx-core")
            ])
    ]
)
```

---

## 📖 Quick Start

Launch a high-performance web server with just a few core commands:

```swift
import SwiftXCore
import Foundation

// 1. Initialize configuration with desired active workers (e.g. your CPU cores)
let config = ServerConfig(port: 8080, workerCount: ProcessInfo.processInfo.processorCount)
let app = SwiftXCore(config: config)

// 2. Add Middlewares (Because we removed internal logs, log here!)
app.use { req, ctx in
    // print("[\(req.method)] \(req.path)")
    return true // Allow request to proceed
}

// 3. Define standard JSON/Text routes 
app.route("GET", "/hello") { req in
    return Response.text("Hello World!")
}

app.route("POST", "/data") { req in
    let json = req.json()
    return Response.json(["received": json])
}

// 4. View Runtime Metrics! Check the health of the engine.
app.route("GET", "/metrics") { req in
    return Response.json([
        "active_workers_count": app.activeWorkersCount,
        "active_tcp_connections": app.totalActiveConnections
    ])
}

// 5. Deterministic Non-Blocking Wait (No thread freezing!)
app.route("GET", "/wait") { req, ctx in
    if let waited: Bool = ctx.get("is_resumed"), waited {
        return Response.text("I waited precisely and resumed!")
    }
    
    ctx.set("is_resumed", true)
    ctx.sleep(ms: 5000) // The worker thread is immediately freed for other connections!
    
    return Response.text("Waiting...")
}

print("Running pure SwiftX Core engine on http://localhost:8080")
// 6. Start the blocking listen loop
app.listen()
```

---

## 📈 Real-Time Engine Metrics

For developers needing to orchestrate containers or monitor system load, you can directly query the core instance to see precisely what your engine is handling.

```swift
let totalWorkers = config.workerCount // Hardware configured capacity
let busyWorkers = app.activeWorkersCount // How many workers are currently processing I/O
let activeSockets = app.totalActiveConnections // Total active TCP sockets held in memory
```

---

## 🧠 High-Performance Benchmarking Guarantee

SwiftX Core is designed to be pushed.

If you are stress-testing, **ALWAYS** compile in `release` mode. Swift's debug mode enforces heavy heap checks that destroy raw `UnsafePointer` network speeds.

```bash
# Correct benchmark build strategy
swift build -c release 

# Start it up
.build/release/MySwiftServer

# Shoot 1,000 concurrent pipelined users at it:
npx autocannon -c 1000 -d 20 -p 20 http://localhost:8080/metrics
```

Expect speeds upwards of **75,000 - 150,000+ Req/s** with latencies holding tightly between 10ms - 50ms (hardware dependent).

---

## 🤝 Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for specifics on extending the networking architecture, understanding our custom byte buffers, and adding support for edge-case hardware instructions (like IOCP or SIMD boundaries). By contributing to SwiftX Core, you help build the fastest Swift web runtime on the planet.
