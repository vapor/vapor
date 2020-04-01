public protocol PasswordService {
    func `for`(_ request: Request) -> PasswordService
    func hash(_ plaintext: String) throws -> String
    func verify<Password, Digest>(_ password: Password, created digest: Digest) throws -> Bool where Password: DataProtocol, Digest: DataProtocol
}

public extension PasswordService {    
    func verify(_ password: String, created digest: String) throws -> Bool {
        return try self.verify(
            password.data(using: .utf8)!,
            created: digest.data(using: .utf8)!
        )
    }
}
