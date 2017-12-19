import Bits
import Foundation
import COperatingSystem

/// Uses the operating system's Random function
/// uses `random` on Linux and `arc4random` on macOS.
///
/// [Learn More →](https://docs.vapor.codes/3.0/crypto/random/)
public final class OSRandom: DataGenerator {
    /// Create a new OSRandom
    public init() {}

    /// Get a random array of Bytes
    public func bytes(count: Int) -> Data {
        var bytes = Data()

        for _ in 0..<count {
            let random = makeRandom(min: 0, max: .maxByte)
            bytes.append(Byte(random))
        }

        return bytes
    }

    fileprivate func makeRandom(min: Int, max: Int) -> Int {
        let top = max - min + 1
        #if os(Linux)
            // will always be initialized
            guard randomInitialized else { fatalError() }
            return Int(COperatingSystem.random() % top) + min
        #else
            return Int(arc4random_uniform(UInt32(top))) + min
        #endif
    }
}

extension Int {
    fileprivate static let maxByte: Int = Int(Byte.max)
}

#if os(Linux)
    /// Generates a random number between (and inclusive of)
    /// the given minimum and maximum.
    private let randomInitialized: Bool = {
        /// This stylized initializer is used to work around dispatch_once
        /// not existing and still guarantee thread safety
        let current = Date().timeIntervalSinceReferenceDate
        let salt = current.truncatingRemainder(dividingBy: 1) * 100000000
        COperatingSystem.srand(UInt32(current + salt))
        return true
    }()
#endif


