import Foundation

public final class MultipartParser {
    public static func parse(request: Request) throws -> Multipart {
        let multipart = "multipart/"
        
        // Check the header
        guard
            let header = request.headers[.contentType],
            header.starts(with: multipart),
            let range = header.range(of: "boundary=") else {
                throw Error(identifier: "multipart-boundary", reason: "No multipart boundary found in the Content-Type header")
        }
        
        // Extract the boundary from the headers
        let boundary = header[range.upperBound...]
        
        // Parse this multipart using the boundary
        return try self.parse(multipart: request.body.data, boundary: Data(boundary.utf8))
    }
    
    public static func parse(multipart data: Data, boundary: Data) throws -> Multipart {
        let fullBoundary = Data([.carriageReturn, .newLine, .hyphen, .hyphen] + boundary)
        var position = 0
        var multipart = Multipart(parts: [])
        
        func require(_ n: Int) throws {
            guard position + n < data.count else {
                throw Error(identifier: "http:multipart:missing-data", reason: "Invalid multipart formatting")
            }
        }
        
        func carriageReturnNewLine() throws -> Bool {
            try require(2)
            
            return data[position] == .carriageReturn && data[position &+ 1] == .newLine
        }
        
        func scanUntil(_ trigger: UInt8) throws -> String? {
            var offset = 0
            
            headerKey: while true {
                guard position + offset < data.count else {
                    throw Error(identifier: "http:multipart:eof", reason: "Unexpected end of multipart")
                }
                
                if data[position &+ offset] == trigger {
                    break headerKey
                }
                
                offset += 1
            }
            
            defer {
                position = position + offset
            }
            
            return String(bytes: data[position..<position + offset], encoding: .utf8)
        }
        
        func checkBoundaryStartEnd() throws {
            guard data[position] == .hyphen, data[position &+ 1] == .hyphen else {
                throw Error(identifier: "http:multipart:boundary", reason: "Invalid multipart formatting")
            }
        }
        
        while position < data.count {
            // require '--' + boundary + \r\n
            try require(2 + boundary.count + 2)
            
            // check '--'
            try checkBoundaryStartEnd()
            
            // skip '--'
            position = position &+ 2
            
            // check boundary
            guard data[position..<position &+ boundary.count] == boundary else {
                throw Error(identifier: "http:multipart:boundary", reason: "Wrong boundary")
            }
            
            // skip boundary
            position = position &+ boundary.count
            
            guard try carriageReturnNewLine() else {
                try checkBoundaryStartEnd()
                return multipart
            }
            
            var headers = Headers()
            
            // headers
            headerScan: while position < data.count, try carriageReturnNewLine() {
                // skip \r\n
                position = position &+ 2
                
                // `\r\n\r\n` marks the end of headers
                if try carriageReturnNewLine() {
                    position = position &+ 2
                    break headerScan
                }
                
                // header key
                guard let key = try scanUntil(.colon) else {
                    throw Error(identifier: "http:multipart:invalid-header-key", reason: "Invalid multipart header key string encoding")
                }
                
                // skip space (': ')
                position = position + 2
                
                // header value
                guard let value = try scanUntil(.carriageReturn) else {
                    throw Error(identifier: "http:multipart:invalid-header-value", reason: "Invalid multipart header value string encoding")
                }
                
                headers[Headers.Name(key)] = value
            }
            
            guard let content = headers[.contentDisposition], content.starts(with: "form-data") else {
                throw Error(identifier: "http:multipart:headers", reason: "Invalid content disposition")
            }
            
            let key = headers[.contentDisposition, "name"]
            
            // The compiler doesn't understand this will never be `nil`
            var partData: Data!
            
            var base = position
            
            // Seeks to the end of this part's content
            contentSeek: while true {
                try require(fullBoundary.count)
                
                if data[base] == fullBoundary.first, data[base..<base + fullBoundary.count] == fullBoundary {
                    partData = Data(data[position..<base])
                    position = base
                    break contentSeek
                }
                
                base = base &+ 1
            }
            
            // The default 1:1 binary encoding
            var encoding: MultipartContentCoder = Encoding.binary
            
            // If a different encoding mechanism is specified, use that
            if let encodingString = headers[.contentTransferEncoding] {
                guard let registeredCoder = Encoding.registery[encodingString] else {
                    throw Error(identifier: "http:multipart:body-encoding", reason: "Unknown multipart encoding")
                }
                
                encoding = try registeredCoder.init(headers: headers)
            }
            
            // Decodes the part
            partData = try encoding.decode(partData)
            
            let part = Multipart.Part(data: partData, key: key, headers: headers)
            
            multipart.parts.append(part)
            
            // If it doesn't end in a second `\r\n`, this must be the end of the data z
            guard try carriageReturnNewLine() else {
                guard data[position] == .hyphen, data[position &+ 1] == .hyphen else {
                    throw Error(identifier: "http:multipart:invalid-eof", reason: "Invalid multipart ending")
                }
                
                return multipart
            }
            
            position = position &+ 2
        }
        
        return multipart
    }
}
