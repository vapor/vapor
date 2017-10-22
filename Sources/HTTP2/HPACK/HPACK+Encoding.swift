import HTTP
import Foundation

public final class HPACKEncoder {
    let remoteTable = HeadersTable()
    var tableSize: Int = 4_096
    var currentTableSize = 0
    var maxTableSize: Int?
    
    public func encode(request: Request, chunksOf size: Int, streamID: Int32) throws -> [Frame] {
        var payloads = [Payload]()
        
        try payloads.withPayload(maxSize: size) { payload in
            try payload.setPath(to: request.uri.path)
        }
        
        try payloads.withPayload(maxSize: size) { payload in
            switch request.method {
            case .get:
                try payload.fullyIndexed(index: HeadersTable.get.index)
            case .post:
                try payload.fullyIndexed(index: HeadersTable.post.index)
            default:
                try payload.headerIndexed(index: HeadersTable.get.index, value: request.method.string)
            }
        }
        
        if let host = request.uri.hostname ?? request.headers[.host] {
            try payloads.withPayload(maxSize: size) { payload in
                try payload.headerIndexed(index: HeadersTable.get.index, value: host)
            }
        }
        
        nextHeader: for (name, value) in request.headers where name != .host {
            for entry in HeadersTable.staticEntries {
                if entry.name == name {
                    try payloads.withPayload(maxSize: size) { payload in
                        try payload.headerIndexed(index: entry.index, value: value)
                    }
                    
                    continue nextHeader
                }
            }
            
            try payloads.withPayload(maxSize: size) { payload in
                try payload.neverIndexed(key: name.description, value: value)
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
    
    func headerIndexed(index: Int, value: String, huffmanEncoded: Bool = true) throws {
        self.data.append(UInt8.headerIndexed)
        try self.serialize(integer: index, prefix: 6)
        try self.append(string: value, huffmanEncoded: huffmanEncoded)
    }
    
    func neverIndexed(key: String, value: String, huffmanEncoded: Bool = true) throws {
        self.data.append(UInt8.neverIndexed)
        try self.append(string: key, huffmanEncoded: huffmanEncoded)
        try self.append(string: value, huffmanEncoded: huffmanEncoded)
    }
    
    func setPath(to path: String, huffmanEncoded: Bool = true) throws {
        if path == "/" {
            try fullyIndexed(index: HeadersTable.root.index)
        } else {
            try headerIndexed(index: HeadersTable.root.index, value: path, huffmanEncoded: huffmanEncoded)
        }
    }
    
    func setAuthority(to authority: String, huffmanEncoded: Bool = true) throws {
        try headerIndexed(index: HeadersTable.authority.index, value: authority, huffmanEncoded: huffmanEncoded)
    }
}
