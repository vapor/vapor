//
//  ByteCount.swift
//  
//
//  Created by Jimmy McDermott on 4/24/20.
//

import Foundation

/// Represents a number of bytes:
///
/// let bytes: ByteCount = "1mb"
/// print(bytes.value) // 1048576
///
/// let bytes: ByteCount = 1_000_000
/// print(bytes.value) // 1000000

/// let bytes: ByteCount = "2kib"
/// print(bytes.value) // 2048
public struct ByteCount {

    /// The value in Bytes
    public let value: Int
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
    /// `kib`, `mb`, `gb`, `tb`
    /// - Parameter value: The string value (`1mb`)
    public init(stringLiteral value: String) {
        // Short path if it's an int wrapped in a string
        if let intValue = Int(value) {
            self.value = intValue
            return
        }

        let validSuffixes = [
            "kib": 10,
            "mb": 20,
            "gb": 30,
            "tb": 40
        ]

        for suffix in validSuffixes {
            guard value.hasSuffix(suffix.key) else { continue }
            guard let stringIntValue = value.components(separatedBy: suffix.key).first else {
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
