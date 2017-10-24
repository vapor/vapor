import HTTP
import Foundation
import Pufferfish

public final class HPACKEncoder {
    let remoteTable = HeadersTable()
    var tableSize: Int = 4_096
    var currentTableSize = 0
    var maxTableSize: Int?
    
    static let huffmanEncoder = HuffmanEncoder.hpack
    
    /// Encodes a request into a set of frames
    ///
    /// TODO: Body for non-GET requests
    public func encode(request: Request, chunksOf size: Int, streamID: Int32) throws -> [Frame] {
        var payloads = [Payload]()
        
        // Encode the path (required)
        try payloads.withPayload(maxSize: size) { payload in
            try payload.setPath(
                to: request.uri.path,
                encoder: HPACKEncoder.huffmanEncoder
            )
        }
        
        // Encode the method (required)
        try payloads.withPayload(maxSize: size) { payload in
            switch request.method {
            case .get:
                try payload.fullyIndexed(index: HeadersTable.get.index)
            case .post:
                try payload.fullyIndexed(index: HeadersTable.post.index)
            default:
                try payload.headerIndexed(index: HeadersTable.get.index, value: request.method.string, encoder: HPACKEncoder.huffmanEncoder)
            }
        }
        
        // Encode the scheme (required)
        try payloads.withPayload(maxSize: size) { payload in
            try payload.fullyIndexed(index: HeadersTable.https.index)
        }
        
        // Encode the authority (required)
        if let host = request.headers[.host] ?? request.uri.hostname {
            try payloads.withPayload(maxSize: size) { payload in
                try payload.headerIndexed(
                    index: HeadersTable.authority.index,
                    value: host,
                    encoder: HPACKEncoder.huffmanEncoder
                )
            }
        }
        
        // Encode the remaining headers with lowercased keys
        // Exception for host due to the above authority
        nextHeader: for (name, value) in request.headers where name != .host {
            let name = name.description.lowercased()
            
            // Loop up the key in the statictable for a shorthand
            // TODO: Performance?
            for entry in HeadersTable.staticEntries {
                if entry.name.description == name {
                    // Use the existing key by referencing the index
                    try payloads.withPayload(maxSize: size) { payload in
                        try payload.headerIndexed(
                            index: entry.index,
                            value: value,
                            encoder: HPACKEncoder.huffmanEncoder
                        )
                    }
                    
                    continue nextHeader
                }
            }
            
            // Encode a never before indexed header
            try payloads.withPayload(maxSize: size) { payload in
                try payload.neverIndexed(
                    key: name.description,
                    value: value,
                    encoder: HPACKEncoder.huffmanEncoder
                )
            }
        }
        
        return [Frame](
            headers: payloads,
            streamID: streamID,
            endingStream: request.body.data.count == 0
        )
    }
}

extension Array where Element == Frame {
    init(headers: [Payload], streamID: Int32, endingStream: Bool) {
        self.init()
        
        for i in 0..<headers.count {
            let frame = Frame(type: .headers, payload: headers[i], streamID: streamID)
            
            if i > 0 {
                frame.type = .continuation
            }
            
            if i == headers.count - 1 {
                // The last header needs the END_HEADERS flag
                frame.flags |= 0x04
                
                if endingStream {
                    frame.flags |= 0x01
                }
            }
            
            self.append(frame)
        }
    }
}

extension Payload {
    func fullyIndexed(index: Int) throws {
        self.data.append(UInt8.completelyIndexed)
        try self.serialize(integer: index, prefix: 7)
    }
    
    func headerIndexed(index: Int, value: String, encoder: HuffmanEncoder) throws {
        self.data.append(UInt8.headerIndexed)
        try self.serialize(integer: index, prefix: 6)
        try self.append(string: value, huffmanEncoder: encoder)
    }
    
    func neverIndexed(key: String, value: String, encoder: HuffmanEncoder) throws {
        self.data.append(UInt8.neverIndexed)
        try self.append(string: key, huffmanEncoder: encoder)
        try self.append(string: value, huffmanEncoder: encoder)
    }
    
    func setPath(to path: String, encoder: HuffmanEncoder) throws {
        if path == "/" {
            try fullyIndexed(index: HeadersTable.root.index)
        } else {
            try headerIndexed(index: HeadersTable.root.index, value: path, encoder: encoder)
        }
    }
    
    func setAuthority(to authority: String, encoder: HuffmanEncoder) throws {
        try headerIndexed(index: HeadersTable.host.index, value: authority, encoder: encoder)
    }
}
