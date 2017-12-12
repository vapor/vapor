import Foundation
import Bits
import HTTP

/// An enum with no cases can't be instantiated
///
/// This parser can only be used statically, a design choice considering the way multipart is best parsed
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/multipart/#parsing-a-multipart-form)
public final class MultipartParser {
    /// The boundary between all parts
    fileprivate let boundary: [UInt8]
    
    /// A helper variable that consists of all bytes inbetween one part's body and the next part's headers
    fileprivate let fullBoundary: [UInt8]
    
    /// The multipart form data to parse
    fileprivate let data: Data
    
    /// The current position, used for parsing
    var position = 0
    
    /// The output form
    var multipart: MultipartForm
    
    /// Creates a new parser for a Multipart form
    public init(body: HTTPBody, boundary: [UInt8]) {
        self.data = body.data ?? Data()
        self.boundary = boundary
        self.multipart = MultipartForm(parts: [], boundary: boundary)
        self.fullBoundary = [.carriageReturn, .newLine, .hyphen, .hyphen] + boundary
    }
    
    /// Scans for a possible boundary in a Multipart Data
    public static func boundary(for data: Data) throws -> [UInt8] {
        guard
            let index = data.index(of: .carriageReturn),
            index > 5,
            data[0] == .hyphen,
            data[1] == .hyphen
        else {
            throw MultipartError(identifier: "no-boundary", reason: "No possible boundary could be found")
        }
        
        return Array(data[2..<index])
    }
    
    // Requires `n` bytes
    fileprivate func require(_ n: Int) throws {
        guard position + n < data.count else {
            throw MultipartError(identifier: "multipart:missing-data", reason: "Invalid multipart formatting")
        }
    }
    
    // Checks if the current position contains a `\r\n`
    fileprivate func carriageReturnNewLine() throws -> Bool {
        try require(2)
        
        return data[position] == .carriageReturn && data[position &+ 1] == .newLine
    }
    
    // Scans until the trigger is found
    // Instantiates a String from the found data
    fileprivate func scanStringUntil(_ trigger: UInt8) throws -> String? {
        var offset = 0
        
        headerKey: while true {
            guard position + offset < data.count else {
                throw MultipartError(identifier: "multipart:eof", reason: "Unexpected end of multipart")
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
    
    /// Asserts that the position is on top of two hyphens
    fileprivate func assertBoundaryStartEnd() throws {
        guard data[position] == .hyphen, data[position &+ 1] == .hyphen else {
            throw MultipartError(identifier: "multipart:boundary", reason: "Invalid multipart formatting")
        }
    }
    
    /// Reads the headers at the current position
    fileprivate func readHeaders() throws -> HTTPHeaders {
        var headers = HTTPHeaders()
        
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
            guard let key = try scanStringUntil(.colon) else {
                throw MultipartError(identifier: "multipart:invalid-header-key", reason: "Invalid multipart header key string encoding")
            }
            
            // skip space (': ')
            position = position + 2
            
            // header value
            guard let value = try scanStringUntil(.carriageReturn) else {
                throw MultipartError(identifier: "multipart:invalid-header-value", reason: "Invalid multipart header value string encoding")
            }
            
            headers[HTTPHeaders.Name(key)] = value
        }
        
        return headers
    }
    
    /// Parses the part data until the boundary
    fileprivate func seekUntilBoundary() throws -> Data {
        var base = position
        
        // Seeks to the end of this part's content
        contentSeek: while true {
            try require(fullBoundary.count)
            
            let matches = data.withByteBuffer { buffer in
                return buffer[base] == fullBoundary[0] && buffer[base &+ 1] == fullBoundary[1] && memcmp(fullBoundary, buffer.baseAddress!.advanced(by: base), fullBoundary.count) == 0
            }
            
            // The first 2 bytes match, check if a boundary is hit
            if matches {
                defer { position = base }
                return Data(data[position..<base])
            }
            
            base = base &+ 1
        }
    }
    
    /// Parses the part data until the boundary and decodes it.
    ///
    /// Also appends the part to the Multipart
    fileprivate func appendPart(named name: String?, headers: HTTPHeaders) throws {
        // The compiler doesn't understand this will never be `nil`
        let partData = try seekUntilBoundary()
        
        let part = Part(data: partData, key: name, headers: headers)
        
        multipart.parts.append(part)
    }
    
    /// Parses the `Data` and adds it to the Multipart.
    public func parse() throws -> MultipartForm {
        guard multipart.parts.count == 0 else {
            throw MultipartError(identifier: "multipart:multiple-parses", reason: "Multipart may only be parsed once")
        }
        
        while position < data.count {
            // require '--' + boundary + \r\n
            try require(fullBoundary.count)
            
            // assert '--'
            try assertBoundaryStartEnd()
            
            // skip '--'
            position = position &+ 2
            
            let matches = data.withByteBuffer { buffer in
                return memcmp(buffer.baseAddress!.advanced(by: position), boundary, boundary.count) == 0
            }
            
            // check boundary
            guard matches else {
                throw MultipartError(identifier: "multipart:boundary", reason: "Wrong boundary")
            }
            
            // skip boundary
            position = position &+ boundary.count
            
            guard try carriageReturnNewLine() else {
                try assertBoundaryStartEnd()
                return multipart
            }
            
            var headers = try readHeaders()
            
            guard let content = headers[.contentDisposition], content.starts(with: "form-data") else {
                throw MultipartError(identifier: "multipart:headers", reason: "Invalid content disposition")
            }
            
            let key = headers[.contentDisposition, "name"]
            
            try appendPart(named: key, headers: headers)
            
            // If it doesn't end in a second `\r\n`, this must be the end of the data z
            guard try carriageReturnNewLine() else {
                guard data[position] == .hyphen, data[position &+ 1] == .hyphen else {
                    throw MultipartError(identifier: "multipart:invalid-eof", reason: "Invalid multipart ending")
                }
                
                return multipart
            }
            
            position = position &+ 2
        }
        
        return multipart
    }
}
