import Foundation

/// Represents a number of bytes:
///
/// let bytes: ByteCount = "1mb"
/// print(bytes.value) // 1048576
///
/// let bytes: ByteCount = 1_000_000
/// print(bytes.value) // 1000000

/// let bytes: ByteCount = "2kb"
/// print(bytes.value) // 2048
public struct ByteCount: Equatable, Sendable {
    /// The value in Bytes
    public let value: Int

    public init(value: Int) {
        self.value = value
    }
}

extension ByteCount: ExpressibleByIntegerLiteral {
    /// Initializes the `ByteCount` with the raw byte count
    /// - Parameter value: The number of bytes
    public init(integerLiteral value: Int) {
        self.value = value
    }
}

extension ByteCount: ExpressibleByStringLiteral {
    /// Initializes the `ByteCount` via a descriptive string. Available suffixes are:
    /// `kb`, `mb`, `gb`, `tb`
    /// - Parameter value: The string value (`1mb`)
    public init(stringLiteral value: String) {
        // Short path if it's an int wrapped in a string
        if let intValue = Int(value) {
            self.value = intValue
            return
        }

        let validSuffixes = [
            "kb": 10,
            "mb": 20,
            "gb": 30,
            "tb": 40,
        ]

        let cleanValue = value.lowercased().trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "")
        for suffix in validSuffixes {
            guard cleanValue.hasSuffix(suffix.key) else { continue }
            guard let stringIntValue = cleanValue.components(separatedBy: suffix.key).first else {
                fatalError("Invalid string format")
            }

            guard let intValue = Int(stringIntValue) else {
                fatalError("Invalid int value: \(stringIntValue)")
            }

            self.value = intValue << suffix.value
            return
        }

        // Assert failure here because all cases are handled in the above loop
        fatalError("Could not parse byte count string: \(value)")
    }
}
