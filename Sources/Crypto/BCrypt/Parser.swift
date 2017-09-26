import Foundation
import Bits

extension BCrypt {
    final class Parser {
        let versionData: Data
        let costData: Data
        let encodedSalt: Data
        let encodedDigest: Data?
        
        init(_ bytes: Data) throws {
            let parts = bytes.split(separator: .dollar)
            
            guard
                parts.count == 3 && (parts[2].count == 22 || parts[2].count == 53)
                else {
                    throw Error.invalidHash
            }
            
            versionData = Data(parts[0])
            costData = Data(parts[1])
            if parts[2].count == 22 {
                encodedSalt = Data(parts[2])
                encodedDigest = nil
            } else {
                let rest = Data(parts[2])
                
                encodedSalt = Data(rest[0..<22])
                encodedDigest = Data(rest[22..<53])
            }
        }
        
        func parseDigest() throws -> Data? {
            guard let encodedDigest = self.encodedDigest else {
                return nil
            }
            
            return Base64.decode(encodedDigest, count: 23)
        }
        
        func parseSalt() throws -> Salt {
            let version = try parseVersion()
            let cost = try parseCost()
            
            let decoded = Base64.decode(encodedSalt, count: 16)
            return try Salt(version, cost: UInt(cost), bytes: decoded)
        }
        
        func parseCost() throws -> UInt {
            guard let costString = String(bytes: costData, encoding: .utf8),
                let cost = UInt(costString) else {
                throw Error.invalidSaltCost
            }
            
            return cost
        }
        
        func parseVersion() throws -> Salt.Version {
            guard versionData.count >= 1 else {
                throw Error.invalidSaltVersion
            }
            
            let version: Salt.Version
            
            switch versionData[0] {
            case Byte.two:
                switch versionData.count {
                case 2:
                    switch versionData[1] {
                    case Byte.a:
                        version = .two(.a)
                    case Byte.x:
                        version = .two(.x)
                    case Byte.y:
                        version = .two(.y)
                    default:
                        throw BCrypt.Error.invalidSaltVersion
                    }
                case 1:
                    version = .two(.none)
                default:
                    throw BCrypt.Error.invalidSaltVersion
                }
            default:
                throw BCrypt.Error.unsupportedSaltVersion
            }
            
            return version
        }
    }
}
