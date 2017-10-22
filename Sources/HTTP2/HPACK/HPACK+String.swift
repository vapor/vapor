import Pufferfish

extension Payload {
    public func append(string: String, huffmanEncoded: Bool = false) throws {
        let huffmanMarker: UInt8 = huffmanEncoded ? 0b10000000 : 0
        self.data.append(huffmanMarker)
        
        if huffmanEncoded {
            let encoded = try HuffmanEncoder.hpack.encode(string: string)
            try self.serialize(integer: encoded.count, prefix: 7)
            data.append(contentsOf: encoded)
        } else {
            try self.serialize(integer: string.utf8.count, prefix: 7)
            data.append(contentsOf: string.utf8)
        }
    }
    
    public func parseString() throws -> String {
        guard self.bytePosition < self.data.count else {
            throw Error(.unexpectedEOF)
        }
        
        let byte = self.data[self.bytePosition]
        
        let plainText = byte & 0b10000000 == 0
        let length = try self.parseInteger(prefix: 7)
        
        guard self.bytePosition + length <= self.data.count else {
            throw Error(.unexpectedEOF)
        }
        
        let rawStringBytes = self.data[self.bytePosition..<self.bytePosition &+ length]
        
        self.bytePosition += length
        
        if plainText {
            guard let string = String(data: rawStringBytes, encoding: .utf8) else {
                throw Error(.invalidUTF8String)
            }
            
            return string
        }
        
        let decodedStringBytes = try HuffmanDecoder.hpack().decode(data: rawStringBytes)
        
        guard let string = String(data: decodedStringBytes, encoding: .utf8) else {
            throw Error(.invalidUTF8String)
        }
        
        return string
    }
}
