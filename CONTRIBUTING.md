# Contributing to SwiftX Core

First of all, thank you for your interest in SwiftX Core! This runtime is designed for extreme performance (70k+ RPS) and low overhead on Windows, Linux, and macOS. Any contributions to push its boundaries or stabilize it across platforms are highly welcome.

## Architecture

SwiftX Core uses a non-blocking, multi-threaded event loop model similar to an Nginx worker process model, built entirely in Swift. It handles incoming sockets, reads directly to zero-copy memory buffers, and parses bytes in-place to avoid heavy Object or String allocations.

### Directory Structure Structure (`Sources/SwiftXCore`)

*   **`SwiftXCore.swift`**: The main entry point for configuring and booting the server. Defines `use()` and `route()` methods, as well as accessing internal `Scheduler` metrics (like worker/connection count).
*   **`buffer/byte_buffer.swift`**: A high-performance, unsafe-pointer-backed memory buffer. Reads happen directly into this memory from the OS socket.
*   **`http/`**:
    *   **`http_parser.swift`**: The ultra-fast, byte-scanning HTTP request parser. Parses headers directly from pointers without unnecessary `String` heap allocations.
    *   **`encoder.swift`**: Converts `Response` objects back to `Data` rapidly by caching static lines and headers.
    *   **`request.swift` & `response.swift`**: Lightweight representations of HTTP requests and responses.
*   **`io/`**: Contains the OS-specific network polling mechanisms layer. 
    *   `wsapoll_backend.swift`: Windows WSAPoll (Extremely fast array-copied socket polling).
    *   `epoll_backend.swift`: Linux `epoll`.
    *   `kqueue_backend.swift`: macOS / Darwin `kqueue`.
    *   `select_backend.swift`: Legacy fallback for Windows if `WSAPoll` is not viable.
    *   `socket.swift`: Safe and non-blocking abstractions over standard file descriptors.
*   **`net/`**:
    *   **`listener.swift`**: Handles port binding and accepting incoming raw TCP sockets.
    *   **`connection.swift`**: Wraps accepted client sockets state and wraps the worker-level transmission buffer.
*   **`router/`**:
    *   **`radix_router.swift`**: A high-speed, thread-safe trie-tree implementation for matching dynamic/parametric paths (e.g., `/user/:id`) as well as an O(1) static route cache.
*   **`runtime/`**:
    *   **`scheduler.swift`**: Manages the worker threads, assigning incoming socket connections using a Round-Robin policy. Tracks active connections and workers.
    *   **`worker.swift`**: The heart of the network loop. Every worker thread runs a dedicated continuous `runLoop` that tracks I/O arrays and triggers tasks.
    *   **`task.swift`**: A deterministic co-routine system to suspend and resume user code without blocking the `Worker`'s underlying thread.
    *   **`ring_buffer.swift`**: An optimized thread-safe lock-free or low-lock Ring Queue used for submitting closures.

## Logging

**Note to Contributors**: We do **not** use any default logging inside the internal `SwiftXCore` components. This is intentional. Printing or logging synchronously blocks the system thread and completely destroys performance. The user of `SwiftXCore` is expected to supply their own middleware or attach a logger in the application layer if required.

## Building and Testing

1.  **Clone the repository**: `git clone https://github.com/your-org/swiftx-core.git`
2.  **Build (Always use Release mode for actual testing)**: 
    ```bash
    swift build -c release
    ```
3.  **Run the Example Server**:
    ```bash
    swift run -c release SwiftXCoreExample
    ```

## Submitting Pull Requests
1. Ensure your PR is strictly checked against high-concurrency memory leaks using tools like Autocannon (`npx autocannon -c 100 -d 10 http://localhost:8080/benchmark`).
2. Keep in-place memory access (`UnsafeRawPointer`, `UnsafeMutableRawPointer`) bounded correctly to avoid buffer overflows.
3. Don't add third-party dependencies unless strictly necessary. SwiftX Core relies entirely on standard OS primitives (`Glibc`, `Darwin`, `WinSDK`).
