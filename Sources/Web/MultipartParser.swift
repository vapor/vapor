import Foundation
import Bits

/// An enum with no cases can't be instantiated
///
/// This parser can only be used statically, a design choice considering the way multipart is best parsed
public enum MultipartParser {
    /// Parses the input mulitpart data using the provided boundary
    ///
    /// - throws: If the multipart data is invalid
    public static func parse(multipart data: Data, boundary: Data) throws -> Multipart {
        let fullBoundary = Data([.carriageReturn, .newLine, .hyphen, .hyphen] + boundary)
        var position = 0
        var multipart = Multipart(parts: [])
        
        // Requires `n` bytes
        func require(_ n: Int) throws {
            guard position + n < data.count else {
                throw Error(identifier: "multipart:missing-data", reason: "Invalid multipart formatting")
            }
        }
        
        // Checks if the current position contains a `\r\n`
        func carriageReturnNewLine() throws -> Bool {
            try require(2)
            
            return data[position] == .carriageReturn && data[position &+ 1] == .newLine
        }
        
        // Scans until the trigger is found
        // Instantiates a String from the found data
        func scanStringUntil(_ trigger: UInt8) throws -> String? {
            var offset = 0
            
            headerKey: while true {
                guard position + offset < data.count else {
                    throw Error(identifier: "multipart:eof", reason: "Unexpected end of multipart")
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
                throw Error(identifier: "multipart:boundary", reason: "Invalid multipart formatting")
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
                throw Error(identifier: "multipart:boundary", reason: "Wrong boundary")
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
                guard let key = try scanStringUntil(.colon) else {
                    throw Error(identifier: "multipart:invalid-header-key", reason: "Invalid multipart header key string encoding")
                }
                
                // skip space (': ')
                position = position + 2
                
                // header value
                guard let value = try scanStringUntil(.carriageReturn) else {
                    throw Error(identifier: "multipart:invalid-header-value", reason: "Invalid multipart header value string encoding")
                }
                
                headers[Headers.Name(key)] = value
            }
            
            guard let content = headers[.contentDisposition], content.starts(with: "form-data") else {
                throw Error(identifier: "multipart:headers", reason: "Invalid content disposition")
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
            var decoder: ContentDecoder = DataEncoding.binary
            
            // If a different encoding mechanism is specified, use that
            if let encodingString = headers[.contentTransferEncoding] {
                guard let registeredCoder = DataEncoding.registery[encodingString] else {
                    throw Error(identifier: "multipart:body-encoding", reason: "Unknown multipart encoding")
                }
                
                decoder = try registeredCoder.decoder(headers)
            }
            
            // Decodes the part
            partData = try decoder.decode(partData)
            
            let part = Part(data: partData, key: key, headers: headers)
            
            multipart.parts.append(part)
            
            // If it doesn't end in a second `\r\n`, this must be the end of the data z
            guard try carriageReturnNewLine() else {
                guard data[position] == .hyphen, data[position &+ 1] == .hyphen else {
                    throw Error(identifier: "multipart:invalid-eof", reason: "Invalid multipart ending")
                }
                
                return multipart
            }
            
            position = position &+ 2
        }
        
        return multipart
    }
}
