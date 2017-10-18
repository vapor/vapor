import Foundation
import Bits
import HTTP

/// An enum with no cases can't be instantiated
///
/// This parser can only be used statically, a design choice considering the way multipart is best parsed
///
/// http://localhost:8000/http/multipart/#parsing-a-multipart-form
public final class MultipartParser {
    /// The boundary between all parts
    fileprivate let boundary: Data
    
    /// A helper variable that consists of all bytes inbetween one part's body and the next part's headers
    fileprivate let fullBoundary: Data
    
    /// The multipart form data to parse
    fileprivate let data: ByteBuffer
    
    /// The current position, used for parsing
    var position = 0
    
    /// The output form
    var multipart = Form(parts: [])
    
    /// Creates a new parser for a Multipart form
    init(data: ByteBuffer, boundary: Data) {
        self.data = data
        self.boundary = boundary
        self.fullBoundary = Data([.carriageReturn, .newLine, .hyphen, .hyphen] + boundary)
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
    fileprivate func readHeaders() throws -> Headers {
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
            guard let key = try scanStringUntil(.colon) else {
                throw MultipartError(identifier: "multipart:invalid-header-key", reason: "Invalid multipart header key string encoding")
            }
            
            // skip space (': ')
            position = position + 2
            
            // header value
            guard let value = try scanStringUntil(.carriageReturn) else {
                throw MultipartError(identifier: "multipart:invalid-header-value", reason: "Invalid multipart header value string encoding")
            }
            
            headers[Headers.Name(key)] = value
        }
        
        return headers
    }
    
    /// Parses the part data until the boundary
    fileprivate func seekUntilBoundary() throws -> Data {
        var base = position
        
        return try fullBoundary.withUnsafeBytes { (boundaryPointer: BytesPointer) throws -> Data in
            // Seeks to the end of this part's content
            contentSeek: while true {
                try require(fullBoundary.count)
                
                // The first 2 bytes match, check if a boundary is hit
                if data[base] == fullBoundary[0], data[base &+ 1] == fullBoundary[1], memcmp(boundaryPointer, data.baseAddress!.advanced(by: base), fullBoundary.count) == 0 {
                    defer { position = base }
                    return Data(data[position..<base])
                }
                
                base = base &+ 1
            }
        }
    }
    
    /// Parses the part data until the boundary and decodes it.
    ///
    /// Also appends the part to the Multipart
    fileprivate func appendPart(named name: String?, headers: Headers) throws {
        // The compiler doesn't understand this will never be `nil`
        var partData = try seekUntilBoundary()
        
        // The default 1:1 binary encoding
        var decoder: TransferDecoder = TransferEncoding.binary
        
        // If a different encoding mechanism is specified, use that
        if let encodingString = headers[.contentTransferEncoding] {
            guard let registeredCoder = TransferEncoding.registery[encodingString] else {
                throw MultipartError(identifier: "multipart:body-encoding", reason: "Unknown multipart encoding")
            }
            
            decoder = try registeredCoder.decoder(headers)
        }
        
        // Decodes the part
        partData = try decoder.decode(partData)
        
        let part = Part(data: partData, key: name, headers: headers)
        
        multipart.parts.append(part)
    }
    
    /// Parses the `Data` and adds it to the Multipart.
    fileprivate func parse() throws {
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
            
            try boundary.withUnsafeBytes { (boundaryPointer: BytesPointer) in
                // check boundary
                guard memcmp(data.baseAddress!.advanced(by: position), boundaryPointer, boundary.count) == 0 else {
                    throw MultipartError(identifier: "multipart:boundary", reason: "Wrong boundary")
                }
            }
            
            // skip boundary
            position = position &+ boundary.count
            
            guard try carriageReturnNewLine() else {
                try assertBoundaryStartEnd()
                return
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
                
                return
            }
            
            position = position &+ 2
        }
    }
    
    /// Parses the input mulitpart data using the provided boundary
    ///
    /// - throws: If the multipart data is an invalid Multipart form
    public static func parse(from buffer: ByteBuffer, boundary: Data) throws -> Form {
        let parser = MultipartParser(data: buffer, boundary: boundary)
        
        try parser.parse()
        
        return parser.multipart
    }
    
    /// Parses the input mulitpart body using the provided boundary
    ///
    /// - throws: If the multipart data is an invalid Multipart form
    public static func parse(from body: Body, boundary: Data) throws -> Form {
        return try body.withUnsafeBytes { pointer in
            let buffer = ByteBuffer(start: pointer, count: body.count)
            
            let parser = MultipartParser(data: buffer, boundary: boundary)
            
            try parser.parse()
            
            return parser.multipart
        }
    }
}
