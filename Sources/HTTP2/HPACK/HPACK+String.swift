import Pufferfish

extension Payload {
    public func append(string: String, huffmanEncoded: Bool = false) throws {
        data.append(huffmanEncoded ? 0b10000000 : 0)
        try self.serialize(integer: string.count, prefix: 7)
        
        if huffmanEncoded {
            data.append(contentsOf: try HuffmanEncoder.hpack.encode(string: string))
        } else {
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
