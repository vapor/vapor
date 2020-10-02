import Crypto

/// Supported OTP output sizes.
public enum OTPDigits: Int {
    /// Six digits OTP.
    case six = 6
    /// Seven digits OTP.
    case seven = 7
    /// Eight digits OTP.
    case eight = 8
    
    /// Returns 10^digit.
    fileprivate var pow: UInt32 {
        switch self {
        case .six: return 1_000_000
        case .seven: return 10_000_000
        case .eight: return 100_000_000
        }
    }
}

/// Supported OTP digests.
public enum OTPDigest {
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
        let hmac = Data(HMAC<H>.authenticationCode(for: counter.bigEndian.data, using: self.key))
        // Get the last 4 bits of the HMAC for use as offset
        let offset = Int((hmac.last ?? 0x00) & 0x0f)
        // Get 4 bytes of the HMAC using the offset
        let data = hmac.subdata(in: offset ..< offset + 4)
        // Convert to UInt32
        var number = data.withUnsafeBytes { $0.load(as: UInt32.self ) }.bigEndian
        // Remove most significant bit
        number &= 0x7fffffff
        number = number % self.digits.pow
        
        let strNum = String(number)
        if strNum.count == self.digits.rawValue { return strNum }
        return String(repeatElement("0", count: digits.rawValue - strNum.count)) + strNum
    }
    
    /// Generates a range of OTP's.
    /// - Note: This function will automatically wrap the counter by using integer overflow.
    /// - Parameters:
    ///   - counter: The 'main' counter.
    ///   - range: The number of codes to generate in both the forward and backward direction. This number must be bigger than 0.
    ///   For example, if `range` is `2`, a total of `5` codes will be returned: The main code, the two codes prior to the main code and the two codes after the main code.
    ///   - size: The size of the offset. This is particularly useful for TOTP's, as it allows to specify the interval as size.
    /// - Returns: All the generated OTP's in an array.
    func generateOTPs<H: HashFunction>(
        _ h: H, counter: UInt64,
        range: Int,
        size: Int = 1
    ) -> [String] {
        precondition(range > 0, "Cannot generate range of OTP's for range \(range). Range must be greater than 0")
        
        return (-range ... range).map { $0 * size }.map {
            let offset = $0 >= 0 ? counter &+ UInt64($0) : counter &- UInt64(-$0)
            return generate(h, counter: offset)
        }
    }
    
    /// Generate the HOTP based on the counter.
    /// - Parameter counter: The counter to generate the HOTP for.
    /// - Returns: The generated HOTP as `String`.
    func _generate(
        counter: UInt64
    ) -> String {
        switch self.digest {
        case .sha1: return generate(Insecure.SHA1(), counter: counter)
        case .sha256: return generate(SHA256(), counter: counter)
        case .sha512: return generate(SHA512(), counter: counter)
        }
    }
    
    /// Generates several TOTP's for a range.
    /// - Note: This function will automatically wrap the counter by using integer overflow. This might provide some odd behaviour when near the start time or near the max time.
    /// - Parameters:
    ///   - counter: The 'main' counter.
    ///   - range: The number of codes to generate in both the forward and backward direction. This number must be bigger than 0.
    ///   - size: The size of the offset. This is particularly useful for TOTP's, as it allows to specify the interval as size.
    ///   For example, if `range` is `2`, a total of `5` codes will be returned: The main code, the two codes prior to the main code and the two codes after the main code.
    /// - Returns: All the generated OTP's in an array.
    func _generate(
        counter: UInt64,
        range: Int,
        size: Int = 1
    ) -> [String] {
        switch self.digest {
        case .sha1: return generateOTPs(Insecure.SHA1(), counter: counter, range: range, size: size)
        case .sha256: return generateOTPs(SHA256(), counter: counter, range: range, size: size)
        case .sha512: return generateOTPs(SHA512(), counter: counter, range: range, size: size)
        }
    }
}

/// Create a one-time password using hash-based message authentication codes.
///
///     let key = SymmetricKey(size: .bits128)
///     let code = HOTP.SHA1(key: key).generate(counter: 0)
///     print(code) "208503"
///
/// See `TOTP` for time-based one-time passwords.
public struct HOTP: OTP {
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
        _generate(counter: counter)
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
        _generate(counter: counter, range: range)
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
        return Self.init(key: key, digest: digest, digits: digits).generate(counter: counter)
    }
}

/// Create a one-time password using hash-based message authentication codes
/// and taking uniqueness from the time.
///
///     let key = SymmetricKey(size: .bits128)
///     let code = TOTP.SHA1(key: key).generate(time: Date())
///     print(code) "501247"
///
/// See `HOTP` for hash-based one-time passwords.
public struct TOTP: OTP {
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
        let secondsPast1970 = Int(floor(time.timeIntervalSince1970))
        let counter = Int(floor(Double(secondsPast1970) / Double(self.interval)))
        return _generate(counter: UInt64(counter))
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
        let secondsPast1970 = Int(floor(time.timeIntervalSince1970))
        let counter = Int(floor(Double(secondsPast1970) / Double(self.interval)))
        return _generate(counter: UInt64(counter), range: range, size: self.interval)
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
        return Self.init(key: key, digest: digest, digits: digits, interval: interval).generate(time: time)
    }
}

fileprivate extension FixedWidthInteger {
    /// The raw data representing the integer.
    var data: Data {
        var copy = self
        return .init(bytes: &copy, count: MemoryLayout<Self>.size)
    }
}
