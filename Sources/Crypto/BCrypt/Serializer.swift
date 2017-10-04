import Bits
import Foundation

extension BCrypt {
    internal final class Serializer {
        let salt: Salt
        let digest: Data?
        
        init(_ salt: Salt, digest: Data? = nil) {
            self.salt = salt
            self.digest = digest
        }
        
        func serializeSalt() -> Data {
            var bytes = Data()
            bytes.reserveCapacity(22)
            
            bytes.append(Byte.dollar)
            
            // serialize version
            switch salt.version {
            case .two(let scheme):
                bytes.append(.two)
                switch scheme {
                case .none:
                    break
                case .a:
                    bytes.append(.a)
                case .x:
                    bytes.append(.x)
                case .y:
                    bytes.append(.y)
                }
            }
            bytes.append(.dollar)
            
            // serialize cost
            if salt.cost < 10 {
                bytes.append(.zero)
            }
            bytes.append(contentsOf: salt.cost.description.utf8)
            bytes.append(.dollar)
            
            // serialize encoded salt
            let encodedSalt = Base64.encode(salt.bytes, count: 16)
            bytes.append(contentsOf: encodedSalt)
            
            return bytes
        }
        
        func serialize() -> Data {
            var bytes = serializeSalt()
            
            if let digest = digest {
                let encodedDigest = Base64.encode(digest, count: 23)
                bytes += encodedDigest
            }
            
            return bytes
        }
    }
}
