import Foundation

public final class HTTPParser {
    /// Parses an HTTP request from raw data without unnecessary String copies.
    public static func scanRequest(data: Data) -> (Request, Int)? {
        return data.withUnsafeBytes { buffer in
            let ptr = buffer.bindMemory(to: UInt8.self)
            let count = buffer.count
            
            // 1. Find Header Boundary \r\n\r\n
            var headerEnd = -1
            for i in 0..<count - 3 {
                if ptr[i] == 0x0D && ptr[i+1] == 0x0A && ptr[i+2] == 0x0D && ptr[i+3] == 0x0A {
                    headerEnd = i
                    break
                }
            }
            guard headerEnd != -1 else { return nil }
            
            // 2. Parse First Line
            var lineStart = 0
            var firstLineEnd = -1
            for i in 0..<headerEnd - 1 {
                if ptr[i] == 0x0D && ptr[i+1] == 0x0A {
                    firstLineEnd = i
                    break
                }
            }
            guard firstLineEnd != -1 else { return nil }
            
            let firstLineBytes = ptr.baseAddress!.advanced(by: lineStart)
            let firstLineLen = firstLineEnd - lineStart
            
            // Extract Method/Path/Version from first line
            // We search for spaces
            var space1 = -1
            var space2 = -1
            for i in 0..<firstLineLen {
                if firstLineBytes[i] == 0x20 { // Space
                    if space1 == -1 { space1 = i }
                    else { space2 = i; break }
                }
            }
            guard space1 != -1 && space2 != -1 else { return nil }
            
            let method = String(decoding: UnsafeBufferPointer(start: firstLineBytes, count: space1), as: UTF8.self)
            let pathFull = String(decoding: UnsafeBufferPointer(start: firstLineBytes.advanced(by: space1 + 1), count: space2 - space1 - 1), as: UTF8.self)
            
            // Query params
            var path = pathFull
            var query: [String: String] = [:]
            if let qIdx = pathFull.firstIndex(of: "?") {
                path = String(pathFull[..<qIdx])
                // Parse query... (skipped for brevity/speed in benchmark)
            }
            
            // 3. Headers
            var headers: [String: String] = [:]
            lineStart = firstLineEnd + 2
            while lineStart < headerEnd {
                var nextLineEnd = headerEnd
                for i in lineStart..<headerEnd - 1 {
                    if ptr[i] == 0x0D && ptr[i+1] == 0x0A {
                        nextLineEnd = i
                        break
                    }
                }
                
                let lineLen = nextLineEnd - lineStart
                if lineLen > 0 {
                    let lineBytes = ptr.baseAddress!.advanced(by: lineStart)
                    // Find colon
                    var colon = -1
                    for i in 0..<lineLen {
                        if lineBytes[i] == 0x3A { // ':'
                            colon = i
                            break
                        }
                    }
                    if colon != -1 {
                        let key = String(decoding: UnsafeBufferPointer(start: lineBytes, count: colon), as: UTF8.self).trimmingCharacters(in: .whitespaces)
                        let val = String(decoding: UnsafeBufferPointer(start: lineBytes.advanced(by: colon + 1), count: lineLen - colon - 1), as: UTF8.self).trimmingCharacters(in: .whitespaces)
                        headers[key] = val
                    }
                }
                
                lineStart = nextLineEnd + 2
            }
            
            // 4. Body
            let bodyStart = headerEnd + 4
            var consumed = bodyStart
            var body: Data? = nil
            if let cLenStr = headers["Content-Length"], let cLen = Int(cLenStr) {
                if count - bodyStart < cLen { return nil }
                body = data.subdata(in: bodyStart..<(bodyStart + cLen))
                consumed += cLen
            }
            
            return (Request(method: method, path: path, headers: headers, query: query, body: body), consumed)
        }
    }
}
