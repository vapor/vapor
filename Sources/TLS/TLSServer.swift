public protocol TLSServer {
    var settings: TLSServerSettings { get }
}

/// MARK: Settings

public struct TLSServerSettings {
    public let hostname: String
    public let privateKey: String
    public let publicKey: String

    public init(hostname: String, publicKey: String, privateKey: String) {
        self.hostname = hostname
        self.publicKey = publicKey
        self.privateKey = privateKey
    }
}
