#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension DataProtocol {
    func copyBytes() -> [UInt8] {
        Array(self)
    }
}
