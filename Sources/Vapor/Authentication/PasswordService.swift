public protocol PasswordService {
    func `for`(_ request: Request) -> PasswordService
    func hash<Plaintext>(_ plaintext: Plaintext) throws -> String where Plaintext: DataProtocol
    func verify<Password, Digest>(_ password: Password, created digest: Digest) throws -> Bool where Password: DataProtocol, Digest: DataProtocol
}

public extension PasswordService {
    func hash(_ plaintext: String) throws -> String {
        let string = plaintext.data(using: .utf8)!
        return try self.hash(string)
    }
    
    func verify(_ password: String, created digest: String) throws -> Bool {
        return try self.verify(
            password.data(using: .utf8)!,
            created: digest.data(using: .utf8)!
        )
    }
}
