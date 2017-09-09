import Foundation
import Debugging

public enum PBKDF2Error: Error {
    case cannotIterateZeroTimes
    case cannotDeriveFromPassword(Data)
    case cannotDeriveFromSalt(Data)
    case keySizeTooBig(Int)
}

public final class PBKDF2<Variant: Hash> {
    /// Derives a key from a given set of parameters
    ///
    /// - parameter password: The password to hash
    /// - parameter salt: The random salt that should be unique to the user's credentials, used for preventing Rainbow Tables
    /// - parameter iterations: The amount of iterations to use for strengthening the key, higher is stronger/safer but also slower
    /// - parameter keySize: The amount of bytes to output
    ///
    /// - throws: Invalid input bytes for password or salt
    /// - throws: Too large amount of key bytes requested
    /// - throws: Too little iterations
    ///
    /// - returns: The derived key bytes
    public static func deriveKey(fromPassword password: String, saltedWith salt: Data, iterating iterations: Int = 10_000, derivedKeyLength keySize: Int? = Variant.digestSize) throws -> Data {
        return try deriveKey(fromPassword: Data(password.utf8), saltedWith: salt, iterating: iterations, derivedKeyLength: keySize)
    }
    
    /// Derives a key from a given set of parameters
    ///
    /// - parameter password: The password to hash
    /// - parameter salt: The random salt that should be unique to the user's credentials, used for preventing Rainbow Tables
    /// - parameter iterations: The amount of iterations to use for strengthening the key, higher is stronger/safer but also slower
    /// - parameter keySize: The amount of bytes to output
    ///
    /// - throws: Invalid input bytes for password or salt
    /// - throws: Too large amount of key bytes requested
    /// - throws: Too little iterations
    ///
    /// - returns: The derived key bytes
    public static func deriveKey(fromPassword password: Data, saltedWith salt: Data, iterating iterations: Int = 10_000, derivedKeyLength keySize: Int? = Variant.digestSize) throws -> Data {
        // Used to create a block number to append to the salt before deriving
        func integerData(blockNum block: UInt32) -> Data {
            var bytes = Data(repeating: 0, count: 4)
            bytes[0] = UInt8((block >> 24) & 0xFF)
            bytes[1] = UInt8((block >> 16) & 0xFF)
            bytes[2] = UInt8((block >> 8) & 0xFF)
            bytes[3] = UInt8(block & 0xFF)
            return bytes
        }
        
        // Authenticated using HMAC with precalculated keys (saves 50% performance)
        func authenticate(innerPadding: Data, outerPadding: Data, message: Data) throws -> Data {
            let innerPaddingHash = Variant.hash(innerPadding + message)
            let outerPaddingHash = Variant.hash(outerPadding + innerPaddingHash)
            
            return outerPaddingHash
        }
        
        let keySize = keySize ?? Variant.chunkSize
        
        // Check input values to be correct
        guard iterations > 0 else {
            throw PBKDF2Error.cannotIterateZeroTimes
        }
        
        guard password.count > 0 else {
            throw PBKDF2Error.cannotDeriveFromPassword(password)
        }
        
        guard salt.count > 0 else {
            throw PBKDF2Error.cannotDeriveFromSalt(salt)
        }
        
        guard keySize <= Int(((pow(2,32) as Double) - 1) * Double(Variant.chunkSize)) else {
            throw PBKDF2Error.keySizeTooBig(keySize)
        }
        
        // MARK - Precalculate paddings
        var password = password
        
        // If the key is too long, hash it first
        if password.count > Variant.chunkSize {
            password = Variant.hash(password)
        }
        
        // Add padding
        if password.count < Variant.chunkSize {
            password = password + Data(repeating: 0, count: Variant.chunkSize - password.count)
        }
        
        // XOR the information
        var outerPadding = Data(repeating: 0x5c, count: Variant.chunkSize)
        var innerPadding = Data(repeating: 0x36, count: Variant.chunkSize)
        
        for i in 0..<password.count {
            outerPadding[i] = password[i] ^ outerPadding[i]
        }
        
        for i in 0..<password.count {
            innerPadding[i] = password[i] ^ innerPadding[i]
        }
        
        // This is where all the processing happens
        let blocks = UInt32((keySize + Variant.digestSize - 1) / Variant.digestSize)
        var response = Data()
        
        // Loop over all blocks
        for block in 1...blocks {
            let s = salt + integerData(blockNum: block)
            
            // Iterate the first time
            var ui = try authenticate(innerPadding: innerPadding, outerPadding: outerPadding, message: s)
            var u1 = ui
            
            // Continue iterating for this block
            for _ in 0..<iterations - 1 {
                u1 = try authenticate(innerPadding: innerPadding, outerPadding: outerPadding, message: u1)
                xor(&ui, u1)
            }
            
            // Append the response to be returned
            response.append(contentsOf: ui)
        }
        
        return Data(response[0..<keySize])
    }
    
    /// Validates a password using HMAC based PBKDF2<Variant>
    public static func validate(_ password: Data, saltedWith salt: Data, against: Data, iterating iterations: Int) throws -> Bool {
        let newHash = try deriveKey(fromPassword: password, saltedWith: salt, iterating: iterations, derivedKeyLength: against.count)
        
        return newHash == against
    }
}
 
/// Xors two data buffers
fileprivate func xor(_ lhs: inout Data, _ rhs: Data) {
    for i in 0..<lhs.count {
        lhs[i] = lhs[i] ^ rhs[i]
    }
}

