//
// Based on HttpParser from Swifter (https://github.com/glock45/swifter) by Damian Kołakowski.
//

import Foundation
import libc

class SocketParser {
    
    enum Error: ErrorType {
        case InvalidRequest
    }
    
    class RequestLine {
        let method: Request.Method
        let path: String
        let version: String
        
        init(string: String) throws {
            let requestLineWords = string.split(" ")
            
            //requestLine should be 3 words, like `GET /index.html HTTP/1.1`
            if requestLineWords.count < 3 {
                self.method = .Unknown
                self.path = ""
                self.version = ""
                
                throw Error.InvalidRequest
            }
            
            self.method = Request.Method(rawValue: requestLineWords[0]) ?? .Unknown
            self.path = requestLineWords[1]
            self.version = requestLineWords[2]
        }
    }
    
    func readHttpRequest(socket: Socket) throws -> Request {
        let requestLine = try RequestLine(string: socket.readLine())
        
        //var data = self.extractQueryParams(path)
        let headers = try self.readHeaders(socket)
        
        //try to get the ip address of the incoming request (like 127.0.0.1)
        let address = try? socket.peername()
        
        

        var body: [UInt8] = []
        if
            let contentLength = headers["content-length"],
            let contentLengthValue = Int(contentLength) {
                
            body = try readBody(socket, size: contentLengthValue)
        }

        
        return Request(method: requestLine.method, path: requestLine.path, address: address, headers: headers, body: body)
    }
    
    /**
        Reads the `Socket` until the desired
        size is reached.
    */
    private func readBody(socket: Socket, size: Int) throws -> [UInt8] {
        var body = [UInt8]()
        var counter = 0
        
        while counter < size {
            body.append(try socket.read())
            counter += 1
        }
        return body
    }
    
    /**
        Reads the `Socket` line by line extracting
        header pairs until an empty line is reached.
    */
    private func readHeaders(socket: Socket) throws -> [String: String] {
        var requestHeaders = [String: String]()
        
        while true {
            let headerLine = try socket.readLine()
            if headerLine.isEmpty {
                return requestHeaders
            }
            
            let headerTokens = headerLine.split(1, separator: ":")
            if let name = headerTokens.first, value = headerTokens.last {
                requestHeaders[name.lowercaseString] = value.trim()
            }
        }
    }
    
   
}
