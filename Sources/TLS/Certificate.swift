import Foundation

/// An SSL certificate
public struct Certificate {
    /// The raw binary data
    public var data: Data
    
    /// Creates a certificate from raw data (not Base64-ed)
    public init(raw: Data) {
        self.data = raw
    }
}
