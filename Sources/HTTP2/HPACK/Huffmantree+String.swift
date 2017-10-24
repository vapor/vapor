import Foundation
import Pufferfish

extension HuffmanEncoder {
    func encode(string: String) throws -> Data {
        return try self.encode(data: Data(string.utf8))
    }
}
