import Foundation
import Pufferfish

extension HuffmanEncoder {
    public func encode(string: String) throws -> Data {
        return try self.encode(data: Data(string.utf8))
    }
}
