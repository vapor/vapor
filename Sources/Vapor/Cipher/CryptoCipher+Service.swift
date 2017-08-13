import Bits
import Crypto
import Service

extension CryptoCipher: ServiceType {
    /// See Service.serviceName
    public static var serviceName: String {
        return "crypto"
    }

    /// See Service.serviceSupports
    public static var serviceSupports: [Any.Type] {
        return [CipherProtocol.self]
    }

    /// See Service.make()
    public static func makeService(for container: Container) throws -> CryptoCipher? {
        return try CryptoCipher(config: container.make())
    }
}
