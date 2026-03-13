import Foundation

public class HTTPEncoder {
    private static let status200 = "HTTP/1.1 200 OK\r\n".data(using: .utf8)!
    private static let status404 = "HTTP/1.1 404 Not Found\r\n".data(using: .utf8)!
    private static let status500 = "HTTP/1.1 500 Internal Server Error\r\n".data(using: .utf8)!
    private static let keepAlive = "Connection: keep-alive\r\n".data(using: .utf8)!
    private static let crlf = "\r\n".data(using: .utf8)!
    private static let colon = ": ".data(using: .utf8)!

    public static func encode(response: Response) -> Data {
        var data = Data()
        data.reserveCapacity(256 + (response.body?.count ?? 0))
        
        switch response.status {
        case 200: data.append(status200)
        case 404: data.append(status404)
        case 500: data.append(status500)
        default: data.append("HTTP/1.1 \(response.status) Unknown\r\n".data(using: .utf8)!)
        }
        
        var hasConnection = false
        for (key, value) in response.headers {
            if key.lowercased() == "connection" { hasConnection = true }
            data.append(key.data(using: .utf8)!)
            data.append(colon)
            data.append(value.data(using: .utf8)!)
            data.append(crlf)
        }
        
        if !hasConnection {
            data.append(keepAlive)
        }
        
        data.append(crlf)
        if let body = response.body {
            data.append(body)
        }
        
        return data
    }
}
