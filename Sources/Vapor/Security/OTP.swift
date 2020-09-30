import CryptoKit

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

internal protocol OTP {
    /// A hash function used to calculate HMAC's.
    associatedtype H: HashFunction
    
    /// The key used to calculate the HMAC.
    var key: SymmetricKey { get }
    /// The number of digits to generate.
    var digits: OTPDigits { get }
}

internal extension OTP {
    /// Generate the OTP based on a counter.
    /// - Parameter counter: The counter to generate the OTP for.
    /// - Returns: The generated OTP as `String`.
    func generateOTP(counter: UInt64) -> String {
        let hmac = Data(HMAC<H>.authenticationCode(for: counter.bigEndian.data, using: key))
        // Get the last 4 bits of the HMAC for use as offset
        let offset = Int((hmac.last ?? 0x00) & 0x0f)
        // Get 4 bytes of the HMAC using the offset
        let data = hmac.subdata(in: offset ..< offset + 4)
        // Convert to UInt32
        var number = data.withUnsafeBytes { $0.load(as: UInt32.self ) }.bigEndian
        // Remove most significant bit
        number &= 0x7fffffff
        number = number % digits.pow
        
        let strNum = String(number)
        if strNum.count == digits.rawValue { return strNum }
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
    func generateOTPs(counter: UInt64, on range: Int, size: Int = 1) -> [String] {
        precondition(range > 0, "Cannot generate range of OTP's for range \(range). Range must be greater than 0")
        
        return (-range ... range).map { $0 * size }.map {
            let offset = $0 >= 0 ? counter &+ UInt64($0) : counter &- UInt64(-$0)
            return generateOTP(counter: offset)
        }
//
//        return (-range ... range).map { UInt64($0) * size }.map { generateOTP(counter: counter + $0) }
//        let range = (counter &- (UInt64(range) * size)) ... (counter &+ (UInt64(range) * size))
//        return range.map { generateOTP(counter:$0) }
    }
}

/// Create a one-time password using hash-based message authentication codes.
///
///     let key = SymmetricKey(size: .bits128)
///     let code = HOTP.SHA1(key: key).generate(counter: 0)
///     print(code) "208503"
///
/// See `TOTP` for time-based one-time passwords.
public struct HOTP<H: HashFunction>: OTP {
    let key: SymmetricKey
    let digits: OTPDigits
    
    /// Initialize the HOTP object.
    /// - Parameters:
    ///   - key: The key.
    ///   - digits: The number of digits to generate.
    fileprivate init(key: SymmetricKey, digits: OTPDigits = .six) {
        self.key = key
        self.digits = digits
    }
    
    /// SHA-1 digest based HOTP.
    /// - Parameters:
    ///   - key: The key.
    ///   - digits: The number of digits to generate.
    /// - Returns: The HOTP object.
    public static func SHA1(key: SymmetricKey, digits: OTPDigits = .six) -> HOTP where H == Insecure.SHA1 {
        HOTP<H>(key: key, digits: digits)
    }
    
    /// SHA-256 digest based HOTP.
    /// - Parameters:
    ///   - key: The key.
    ///   - digits: The number of digits to generate.
    /// - Returns: The HOTP object.
    public static func SHA256(key: SymmetricKey, digits: OTPDigits = .six) -> HOTP where H == SHA256 {
        HOTP<H>(key: key, digits: digits)
    }
    
    /// SHA-512 digest based HOTP.
    /// - Parameters:
    ///   - key: The key.
    ///   - digits: The number of digits to generate.
    /// - Returns: The HOTP object.
    public static func SHA512(key: SymmetricKey, digits: OTPDigits = .six) -> HOTP where H == SHA512 {
        HOTP<H>(key: key, digits: digits)
    }
    
    /// Generate the HOTP based on the counter.
    /// - Parameter counter: The counter to generate the HOTP for.
    /// - Returns: The generated HOTP as `String`.
    public func generate(counter: UInt64) -> String {
        generateOTP(counter: counter)
    }
    
    /// Generates several HOTP's for a range.
    /// - Note: This function will automatically wrap the counter by using integer overflow.
    /// - Parameters:
    ///   - counter: The 'main' counter.
    ///   - range: The number of codes to generate in both the forward and backward direction. This number must be bigger than 0.
    ///   For example, if `range` is `2`, a total of `5` codes will be returned: The main code, the two codes prior to the main code and the two codes after the main code.
    /// - Returns: All the generated OTP's in an array.
    public func generate(counter: UInt64, range: Int) -> [String] {
        generateOTPs(counter: counter, on: range)
    }
    
    /// Compute the HOTP for the key and the counter.
    /// - Parameters:
    ///   - key: The key.
    ///   - digits: The number of digits to produce.
    ///   - counter: The counter to generate the HOTP for.
    /// - Returns: The generated HOTP as `String`.
    public static func generate(key: SymmetricKey, digits: OTPDigits = .six, counter: UInt64) -> String {
        precondition(H.self == CryptoKit.Insecure.SHA1.self || H.self == CryptoKit.SHA256.self || H.self == CryptoKit.SHA512.self, "Cannot create HOTP with hash function \(H.self), only SHA-1, SHA-256 and SHA-512 are supported")
        return Self.init(key: key, digits: digits).generate(counter: counter)
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
public struct TOTP<H: HashFunction>: OTP {
    let key: SymmetricKey
    let digits: OTPDigits
    /// The time interval to generate the TOTP on.
    let interval: Int
    
    /// Initialize the TOTP object.
    /// - Parameters:
    ///   - key: The key.
    ///   - digits: The number of digits to generate.
    ///   - interval: The interval in seconds to generate the TOTP for.
    fileprivate init(key: SymmetricKey, digits: OTPDigits = .six, interval: Int = 30) {
        precondition(interval > 0, "Cannot generate TOTP for invalid interval \(interval). Interval must be greater that 0")
        self.key = key
        self.digits = digits
        self.interval = interval
    }
    
    /// SHA-1 digest based TOTP.
    /// - Parameters:
    ///   - key: The key.
    ///   - digits: The number of digits to generate.
    ///   - interval: The interval in seconds to generate the TOTP for.
    /// - Returns: The TOTP object.
    public static func SHA1(key: SymmetricKey, digits: OTPDigits = .six, interval: Int = 30) -> TOTP where H == Insecure.SHA1 {
        TOTP<H>(key: key, digits: digits, interval: interval)
    }
    
    /// SHA-256 digest based TOTP.
    /// - Parameters:
    ///   - key: The key.
    ///   - digits: The number of digits to generate.
    ///   - interval: The interval in seconds to generate the TOTP for.
    /// - Returns: The TOTP object.
    public static func SHA256(key: SymmetricKey, digits: OTPDigits = .six, interval: Int = 30) -> TOTP where H == SHA256 {
        TOTP<H>(key: key, digits: digits, interval: interval)
    }
    
    /// SHA-512 digest based TOTP.
    /// - Parameters:
    ///   - key: The key.
    ///   - digits: The number of digits to generate.
    ///   - interval: The interval in seconds to generate the TOTP for.
    /// - Returns: The TOTP object.
    public static func SHA512(key: SymmetricKey, digits: OTPDigits = .six, interval: Int = 30) -> TOTP where H == SHA512 {
        TOTP<H>(key: key, digits: digits, interval: interval)
    }
    
    /// Generate the TOTP based on a time.
    /// - Parameter time: The time to generate the TOTP for.
    /// - Returns: The generated TOTP as `String`.
    public func generate(time: Date) -> String {
        let secondsPast1970 = Int(floor(time.timeIntervalSince1970))
        let counter = Int(floor(Double(secondsPast1970) / Double(interval)))
        return generateOTP(counter: UInt64(counter))
    }
    
    /// Generates several TOTP's for a range.
    /// - Note: This function will automatically create the previous and next TOTP's for a range based on the interval. For example, if the interval is `30` and the range is `2`, the result will be calculated for `[-1min, -30sec, 0, 30sec, 1min]`.
    /// - Note: This function will automatically wrap the counter by using integer overflow. This might provide some odd behaviour when near the start time or near the max time.
    /// - Parameters:
    ///   - counter: The 'main' counter.
    ///   - range: The number of codes to generate in both the forward and backward direction. This number must be bigger than 0.
    ///   For example, if `range` is `2`, a total of `5` codes will be returned: The main code, the two codes prior to the main code and the two codes after the main code.
    /// - Returns: All the generated OTP's in an array.
    public func generate(time: Date, range: Int) -> [String] {
        let secondsPast1970 = Int(floor(time.timeIntervalSince1970))
        let counter = Int(floor(Double(secondsPast1970) / Double(interval)))
        return generateOTPs(counter: UInt64(counter), on: range, size: interval)
    }
    
    /// Compute the TOTP for the key, time interval and time.
    /// - Parameters:
    ///   - key: The key.
    ///   - digits: The number of digits to generate.
    ///   - interval: The interval in seconds to generate the TOTP for.
    ///   - time: The time to generate the TOTP for.
    /// - Returns: The generated TOTP as `String`.
    public static func generate(key: SymmetricKey, digits: OTPDigits = .six, interval: Int = 30, time: Date) -> String {
        precondition(H.self == CryptoKit.Insecure.SHA1.self || H.self == CryptoKit.SHA256.self || H.self == CryptoKit.SHA512.self, "Cannot create HOTP with hash function \(H.self), only SHA-1, SHA-256 and SHA-512 are supported")
        return Self.init(key: key, digits: digits, interval: interval).generate(time: time)
    }
}

fileprivate extension FixedWidthInteger {
    /// The raw data representing the integer.
    var data: Data {
        var copy = self
        return .init(bytes: &copy, count: MemoryLayout<Self>.size)
    }
}
