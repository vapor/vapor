public protocol TLSClient {
    var settings: TLSClientSettings { get }
    func connect(hostname: String, port: UInt16) throws
}

/// MARK: Settings

public struct TLSClientSettings {
    public let clientCertificate: String?
    public let trustedCAFilePaths: [String]
    public let peerDomainName: String?

    public init(
        clientCertificate: String? = nil,
        trustedCAFilePaths: [String] = [],
        peerDomainName: String? = nil
    ) {
        self.clientCertificate = clientCertificate
        self.trustedCAFilePaths = trustedCAFilePaths
        self.peerDomainName = peerDomainName
    }
}
