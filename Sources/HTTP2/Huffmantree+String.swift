import Foundation

extension HuffmanTree {
    public func encode(string: String) -> Data {
        return self.encode(data: Data(string.utf8))
    }
    
    public func decode(data: Data) -> Data {
        fatalError()
    }
}
