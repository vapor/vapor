import Foundation
#if os(Linux)
// TODO - remove when Crypto finally updated
@preconcurrency import Crypto
#else
import Crypto
#endif

/// Supported OTP output sizes.
public enum OTPDigits: Int, Sendable {
    /// Six digits OTP.
    case six = 6
    /// Seven digits OTP.
    case seven = 7
    /// Eight digits OTP.
    case eight = 8
    
    /// Returns 10^digit.
    fileprivate var pow: UInt32 {
        switch self {
        case .six: 1_000_000
        case .seven: 10_000_000
        case .eight: 100_000_000
        }
    }
}

/// Supported OTP digests.
public enum OTPDigest: Sendable {
    /// The SHA-1 digest.
    case sha1
    /// The SHA-256 digest.
    case sha256
    /// The SHA-512 digest.
    case sha512
}

internal protocol OTP {
    /// The key used to calculate the HMAC.
    var key: SymmetricKey { get }
    /// The number of digits to generate.
    var digits: OTPDigits { get }
    /// A hash function used to calculate HMAC's.
    var digest: OTPDigest { get }
}

internal extension OTP {
    /// Generate the OTP based on a counter.
    /// - Parameter counter: The counter to generate the OTP for.
    /// - Returns: The generated OTP as `String`.
    func generate<H: HashFunction>(
        _ h: H,
        counter: UInt64
    ) -> String {
        let hmac = Array(HMAC<H>.authenticationCode(
            for: /*counter.bigEndian.data */Data([
                UInt8(truncatingIfNeeded: counter >> 56), UInt8(truncatingIfNeeded: counter >> 48),
                UInt8(truncatingIfNeeded: counter >> 40), UInt8(truncatingIfNeeded: counter >> 32),
                UInt8(truncatingIfNeeded: counter >> 24), UInt8(truncatingIfNeeded: counter >> 16),
                UInt8(truncatingIfNeeded: counter >>  8), UInt8(truncatingIfNeeded: counter >> 0),
            ]),
            using: self.key
        ))
        // Get the last 4 bits of the HMAC for use as offset
        let offset = Int((hmac.last ?? 0x00) & 0x0f)
        // Convert to UInt32, removing MSB, then to String
        let number = String((
            (UInt32(hmac[offset + 0] & 0x7f) << 24) | (UInt32(hmac[offset + 1]) << 16) |
            (UInt32(hmac[offset + 2])        <<  8) |  UInt32(hmac[offset + 3])
        ) % self.digits.pow)

        return String(repeatElement("0", count: self.digits.rawValue - number.count)) + number
    }
    
    /// Generates a range of OTP's.
    /// - Note: This function will automatically wrap the counter by using integer overflow.
    /// - Parameters:
    ///   - counter: The 'main' counter.
    ///   - range: The number of codes to generate in both the forward and backward direction. This number must be bigger than 0.
    ///   For example, if `range` is `2`, a total of `5` codes will be returned: The main code, the two codes prior to the main code and the two codes after the main code.
    /// - Returns: All the generated OTP's in an array.
    func generateOTPs<H: HashFunction>(
        _ h: H, counter: UInt64,
        range: Int
    ) -> [String] {
        precondition(range > 0, "Cannot generate range of OTP's for range \(range). Range must be greater than 0")
        
        return (-range ... range).map { self.generate(h, counter: UInt64(Int64(counter) &+ Int64($0))) }
    }
    
    /// Generate the HOTP based on the counter.
    /// - Parameter counter: The counter to generate the HOTP for.
    /// - Returns: The generated HOTP as `String`.
    func _generate(
        counter: UInt64
    ) -> String {
        switch self.digest {
        case .sha1: self.generate(Insecure.SHA1(), counter: counter)
        case .sha256: self.generate(SHA256(), counter: counter)
        case .sha512: self.generate(SHA512(), counter: counter)
        }
    }
    
    /// Generates several TOTP's for a range.
    /// - Note: This function will automatically wrap the counter by using integer overflow. This might provide some odd behaviour when near the start time or near the max time.
    /// - Parameters:
    ///   - counter: The 'main' counter.
    ///   - range: The number of codes to generate in both the forward and backward direction. This number must be bigger than 0.
    ///   For example, if `range` is `2`, a total of `5` codes will be returned: The main code, the two codes prior to the main code and the two codes after the main code.
    /// - Returns: All the generated OTP's in an array.
    func _generate(
        counter: UInt64,
        range: Int
    ) -> [String] {
        switch self.digest {
        case .sha1: self.generateOTPs(Insecure.SHA1(), counter: counter, range: range)
        case .sha256: self.generateOTPs(SHA256(), counter: counter, range: range)
        case .sha512: self.generateOTPs(SHA512(), counter: counter, range: range)
        }
    }
}

/// Create a one-time password using hash-based message authentication codes.
///
///     let key = SymmetricKey(size: .bits128)
///     let code = HOTP.SHA1(key: key).generate(counter: 0)
///     print(code) "208503"
///
/// See ``TOTP`` for time-based one-time passwords.
public struct HOTP: OTP, Sendable {
    let key: SymmetricKey
    let digits: OTPDigits
    let digest: OTPDigest
    
    /// Initialize the HOTP object.
    /// - Parameters:
    ///   - key: The key.
    ///   - digest: The digest to use.
    ///   - digits: The number of digits to generate.
    public init(
        key: SymmetricKey,
        digest: OTPDigest,
        digits: OTPDigits = .six
    ) {
        self.key = key
        self.digits = digits
        self.digest = digest
    }
    
    /// Generate the HOTP based on the counter.
    /// - Parameter counter: The counter to generate the HOTP for.
    /// - Returns: The generated HOTP as `String`.
    public func generate(
        counter: UInt64
    ) -> String {
        self._generate(counter: counter)
    }
    
    /// Generates several HOTP's for a range.
    /// - Note: This function will automatically wrap the counter by using integer overflow.
    /// - Parameters:
    ///   - counter: The 'main' counter.
    ///   - range: The number of codes to generate in both the forward and backward direction. This number must be bigger than 0.
    ///   For example, if `range` is `2`, a total of `5` codes will be returned: The main code, the two codes prior to the main code and the two codes after the main code.
    /// - Returns: All the generated OTP's in an array.
    public func generate(
        counter: UInt64,
        range: Int
    ) -> [String] {
        self._generate(counter: counter, range: range)
    }
    
    /// Compute the HOTP for the key and the counter.
    /// - Parameters:
    ///   - key: The key.
    ///   - digest: The digest to use.
    ///   - digits: The number of digits to produce.
    ///   - counter: The counter to generate the HOTP for.
    /// - Returns: The generated HOTP as `String`.
    public static func generate(
        key: SymmetricKey,
        digest: OTPDigest,
        digits: OTPDigits = .six,
        counter: UInt64
    ) -> String {
        Self.init(key: key, digest: digest, digits: digits).generate(counter: counter)
    }
}

/// Create a one-time password using hash-based message authentication codes
/// and taking uniqueness from the time.
///
///     let key = SymmetricKey(size: .bits128)
///     let code = TOTP.SHA1(key: key).generate(time: Date())
///     print(code) "501247"
///
/// See ``HOTP`` for hash-based one-time passwords.
public struct TOTP: OTP, Sendable {
    let key: SymmetricKey
    let digits: OTPDigits
    let digest: OTPDigest
    /// The time interval to generate the TOTP on.
    let interval: Int
    
    /// Initialize the TOTP object.
    /// - Parameters:
    ///   - key: The key.
    ///   - digest: The digest to use.
    ///   - digits: The number of digits to generate.
    ///   - interval: The interval in seconds to generate the TOTP for.
    public init(
        key: SymmetricKey,
        digest: OTPDigest,
        digits: OTPDigits = .six,
        interval: Int = 30
    ) {
        precondition(interval > 0, "Cannot generate TOTP for invalid interval \(interval). Interval must be greater that 0")
        self.key = key
        self.digits = digits
        self.digest = digest
        self.interval = interval
    }
    
    /// Generate the TOTP based on a time.
    /// - Parameter time: The time to generate the TOTP for.
    /// - Returns: The generated TOTP as `String`.
    public func generate(
        time: Date
    ) -> String {
        let counter = Int(floor(time.timeIntervalSince1970) / Double(self.interval))
        return self._generate(counter: UInt64(counter))
    }
    
    /// Generates several TOTP's for a range.
    /// - Note: This function will automatically create the previous and next TOTP's for a range based on the interval. For example, if the interval is `30` and the range is `2`, the result will be calculated for `[-1min, -30sec, 0, 30sec, 1min]`.
    /// - Note: This function will automatically wrap the counter by using integer overflow. This might provide some odd behaviour when near the start time or near the max time.
    /// - Parameters:
    ///   - counter: The 'main' counter.
    ///   - range: The number of codes to generate in both the forward and backward direction. This number must be bigger than 0.
    ///   For example, if `range` is `2`, a total of `5` codes will be returned: The main code, the two codes prior to the main code and the two codes after the main code.
    /// - Returns: All the generated OTP's in an array.
    public func generate(
        time: Date,
        range: Int
    ) -> [String] {
        let counter = Int(floor(time.timeIntervalSince1970) / Double(self.interval))
        return self._generate(counter: UInt64(counter), range: range)
    }
    
    /// Compute the TOTP for the key, time interval and time.
    /// - Parameters:
    ///   - key: The key.
    ///   - digest: The digest to use.
    ///   - digits: The number of digits to generate.
    ///   - interval: The interval in seconds to generate the TOTP for.
    ///   - time: The time to generate the TOTP for.
    /// - Returns: The generated TOTP as `String`.
    public static func generate(
        key: SymmetricKey,
        digest: OTPDigest,
        digits: OTPDigits = .six,
        interval: Int = 30,
        time: Date
    ) -> String {
        Self.init(key: key, digest: digest, digits: digits, interval: interval).generate(time: time)
    }
}

fileprivate extension FixedWidthInteger {
    /// The raw data representing the integer.
    var data: Data {
        var copy = self
        return .init(bytes: &copy, count: MemoryLayout<Self>.size)
    }
}
