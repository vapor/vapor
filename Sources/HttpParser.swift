//
//  HttpParser.swift
//  Swifter
//  Copyright (c) 2015 Damian Kołakowski. All rights reserved.
//

#if os(Linux)
    import Glibc
#else
    import Foundation
#endif

enum HttpParserError: ErrorType {
    case InvalidStatusLine(String)
}

class HttpParser {
    
    func readHttpRequest(socket: Socket) throws -> HttpRequest {
        let statusLine = try socket.readLine()
        let statusLineTokens = statusLine.split(" ")
        if statusLineTokens.count < 3 {
            throw HttpParserError.InvalidStatusLine(statusLine)
        }
        let request = HttpRequest()
        request.method = statusLineTokens[0]
        request.path = statusLineTokens[1]
        request.queryParams = extractQueryParams(request.path)
        request.headers = try readHeaders(socket)
        if let contentLength = request.headers["content-length"], let contentLengthValue = Int(contentLength) {
            request.body = try readBody(socket, size: contentLengthValue)
        }
        return request
    }
    
    private func extractQueryParams(url: String) -> [(String, String)] {
        guard let query = url.split("?").last else {
            return []
        }
        return query.split("&").reduce([(String, String)]()) { (c, s) -> [(String, String)] in
            let tokens = s.split(1, separator: "=")
            if let name = tokens.first, value = tokens.last {
                return c + [(name.removePercentEncoding(), value.removePercentEncoding())]
            }
            return c
        }
    }
    
    private func readBody(socket: Socket, size: Int) throws -> [UInt8] {
        var body = [UInt8]()
        var counter = 0
        while counter < size {
            body.append(try socket.read())
            counter += 1
        }
        return body
    }
    
    private func readHeaders(socket: Socket) throws -> [String: String] {
        var requestHeaders = [String: String]()
        repeat {
            let headerLine = try socket.readLine()
            if headerLine.isEmpty {
                return requestHeaders
            }
            let headerTokens = headerLine.split(1, separator: ":")
            if let name = headerTokens.first, value = headerTokens.last {
                requestHeaders[name.lowercaseString] = value.trim()
            }
        } while true
    }
    
    func supportsKeepAlive(headers: [String: String]) -> Bool {
        if let value = headers["connection"] {
            return "keep-alive" == value.trim()
        }
        return false
    }
}
