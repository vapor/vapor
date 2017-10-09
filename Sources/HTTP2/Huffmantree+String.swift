import Foundation

extension HuffmanEncoder {
    public func encode(string: String) -> Data {
        return self.encode(data: Data(string.utf8))
    }
}
