//
// Based on HttpParser from Swifter (https://github.com/glock45/swifter) by Damian Kołakowski.
//

#if os(Linux)
    import Glibc
#endif

import Foundation

enum ParserError: ErrorType {
    case InvalidStatusLine(String)
}

class Parser {
    
    func readHttpRequest(socket: Socket) throws -> Request {
        let statusLine = try socket.readLine()
        let statusLineTokens = statusLine.split(" ")
        if statusLineTokens.count < 3 {
            throw ParserError.InvalidStatusLine(statusLine)
        }


        let method = Request.Method(rawValue: statusLineTokens[0]) ?? .Unknown
        let request = Request(method: method)
        request.path = statusLineTokens[1]
        request.data = self.extractQueryParams(request.path)
        request.headers = try self.readHeaders(socket)

        if let cookieString = request.headers["cookie"] {
            let cookies = cookieString.split(";")
            for cookie in cookies {
                let cookieArray = cookie.split("=")
                if cookieArray.count == 2 {
                    let key = cookieArray[0].stringByReplacingOccurrencesOfString(" ", withString: "")
                    request.cookies[key] = cookieArray[1]
                }
            }
        }

        if let contentLength = request.headers["content-length"], let contentLengthValue = Int(contentLength) {
            let body = try readBody(socket, size: contentLengthValue)
            
            if let bodyString = NSString(bytes: body, length: body.count, encoding: NSUTF8StringEncoding) {
                let postArray = bodyString.description.split("&")
                for postItem in postArray {
                    let pair = postItem.split("=")
                    if pair.count == 2 {
                        request.data[pair[0]] = pair[1]
                    }
                }
            }

            request.body = body
        }


        return request
    }
    
    private func extractQueryParams(url: String) -> [String: String] {
        var query = [String: String]()

        var urlParts = url.split("?")
        if urlParts.count < 2 {
            return query
        }

        for subQuery in urlParts[1].split("&") {
            let tokens = subQuery.split(1, separator: "=")
            if let name = tokens.first, value = tokens.last {
                query[name.removePercentEncoding()] = value.removePercentEncoding()
            }
        }

        return query
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
