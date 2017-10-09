import Pufferfish

extension Packet {
    public func append(string: String, huffmanEncoded: Bool = false) throws {
        data.append(huffmanEncoded ? 0b10000000 : 0)
        try self.serialize(integer: string.count, prefix: 7)
        
        if huffmanEncoded {
            data.append(contentsOf: try HuffmanEncoder.hpack.encode(string: string))
        } else {
            data.append(contentsOf: string.utf8)
        }
    }
}
