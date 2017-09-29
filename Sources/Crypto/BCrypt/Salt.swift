import Foundation

extension BCrypt {
    public struct Salt {
        public static var defaultRandom: RandomProtocol = OSRandom()
        public static var defaultCost: UInt = 12
        
        public enum Version {
            case two(Scheme)
            
            public enum Scheme {
                case none
                case a
                case x
                case y
            }
        }
        
        let version: Version
        let cost: UInt
        var bytes: Data
        
        public init(_ version: Version = .two(.y), cost: UInt = Salt.defaultCost, bytes: Data? = nil) throws {
            let bytes = try bytes ?? Salt.defaultRandom.data(count: 16)
            
            guard bytes.count == 16 else {
                throw Error.invalidSaltByteCount
            }
            
            self.version = version
            self.cost = cost
            self.bytes = bytes
        }
    }
}
