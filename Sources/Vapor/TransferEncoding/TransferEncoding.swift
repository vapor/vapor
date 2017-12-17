/// Configures which encodings to use for a given transfer encoding.
public struct TransferEncodingConfig {
    /// Configured encodings.
    var encodings: [String: TransferEncoding]
    
    /// Create a new transfer encoding config.
    public init() {
        self.encodings = [:]
    }
    
    /// Adds a transfer encoding for the specified name.
    public mutating func use(encoding: TransferEncoding, for name: String) {
        self.encodings[name] = encoding
    }
    
    /// Returns an encoding for the specified transfer encoding type or throws an error.
    func requireEncoding(for name: String) throws -> TransferEncoding {
        guard let encoding = encodings[name] else {
            throw VaporError(identifier: "missing-encoding", reason: "There is no known encoding for \(name)")
        }
        
        return encoding
    }
}

/// MARK: Default

extension TransferEncodingConfig {
    /// Creates a default TransferEncoding configuration
    public static func `default`() -> TransferEncodingConfig {
        var config = TransferEncodingConfig()
        
        // plain/binary
        let binary = TransferEncoding(encoder: BinaryCoder.init, decoder: BinaryCoder.init)
        
        config.use(encoding: binary, for: "binary")
        config.use(encoding: binary, for: "")
        
        return config
    }
}
