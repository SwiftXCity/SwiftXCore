import Foundation

public struct Response: Sendable {
    public let status: Int
    public let headers: [String: String]
    public let body: Data?

    public init(status: Int = 200, headers: [String: String] = [:], body: Data? = nil) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    public static func text(_ text: String, status: Int = 200) -> Response {
        let body = Data(text.utf8)
        var headers = ["Content-Type": "text/plain"]
        headers["Content-Length"] = "\(body.count)"
        return Response(status: status, headers: headers, body: body)
    }

    public static func json(_ data: Any, status: Int = 200) -> Response {
        let body = try? JSONSerialization.data(withJSONObject: data)
        var headers = ["Content-Type": "application/json"]
        if let body = body {
            headers["Content-Length"] = "\(body.count)"
        }
        return Response(status: status, headers: headers, body: body)
    }
}
