import Foundation

public struct Request: Sendable {
    public let method: String
    public let path: String
    public let headers: [String: String]
    public var query: [String: String]
    public var params: [String: String]
    public let body: Data?
    
    public init(method: String, path: String, headers: [String: String], query: [String: String] = [:], params: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.path = path
        self.headers = headers
        self.query = query
        self.params = params
        self.body = body
    }

    public func json() -> [String: Any]? {
        guard let body = body else { return nil }
        return try? JSONSerialization.jsonObject(with: body) as? [String: Any]
    }
}
