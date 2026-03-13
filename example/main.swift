import SwiftXCore
import Foundation

let config = ServerConfig(port: 8080)
let app = SwiftXCore(config: config)

app.route("GET", "/hello") { req in
    return Response.text("Hello from SwiftX Core!")
}

app.route("GET", "/user/:id") { req in
    let userId = req.params["id"] ?? "unknown"
    return Response.json(["user": userId, "status": "active"])
}

print("Starting SwiftX Core Example...")
app.listen()
