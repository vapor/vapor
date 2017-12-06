import Foundation

public final class HMAC<Variant: Hash> {
    /// Authenticates a message using the provided `Hash` algorithm
    ///
    /// - parameter message: The message to authenticate
    /// - parameter key: The key to authenticate with
    ///
    /// - returns: The authenticated message
    public static func authenticate(_ message: Data, withKey key: Data) -> Data {
        var key = key
        
        // If it's too long, hash it first
        if key.count > Variant.chunkSize {
            key = Variant.hash(key)
        }
        
        // Add padding
        if key.count < Variant.chunkSize {
            key = key + Data(repeating: 0, count: Variant.chunkSize - key.count)
        }
        
        // XOR the information
        var outerPadding = Data(repeating: 0x5c, count: Variant.chunkSize)
        var innerPadding = Data(repeating: 0x36, count: Variant.chunkSize)
        
        for i in 0..<key.count {
            outerPadding[i] = key[i] ^ outerPadding[i]
        }
        
        for i in 0..<key.count {
            innerPadding[i] = key[i] ^ innerPadding[i]
        }
        
        // Hash the information
        let innerPaddingHash: Data = Variant.hash(innerPadding + message)
        let outerPaddingHash: Data = Variant.hash(outerPadding + innerPaddingHash)
        
        return outerPaddingHash
    }
}
