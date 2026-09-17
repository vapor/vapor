extension ServerConfiguration {
    /// Supported HTTP decompression options.
    public struct RequestDecompressionConfiguration: Sendable {
        /// Disables decompression. This is the default option.
        public static var disabled: Self {
            .init(storage: .disabled)
        }

        /// Enables decompression with default configuration.
        public static var enabled: Self {
            .enabled(limit: .ratio(25))
        }

        /// Enables decompression with custom configuration.
        public static func enabled(
            limit: DecompressionLimit
        ) -> Self {
            .init(storage: .enabled(limit: limit))
        }

        enum Storage {
            case disabled
            case enabled(limit: DecompressionLimit)
        }

        var storage: Storage

        /// Bounds the expanded body independently of a route's body collection limit.
        public struct DecompressionLimit: Sendable, Equatable {
            enum Storage: Sendable, Equatable {
                case none
                case size(Int)
                case ratio(Int)
            }

            let storage: Storage

            /// No decompression limit. Body collection still respects the route's maximum size.
            public static let none = Self(storage: .none)

            /// Maximum number of decompressed bytes, including for streaming requests.
            public static func size(_ bytes: Int) -> Self {
                precondition(bytes >= 0, "Decompression size must be nonnegative")
                return Self(storage: .size(bytes))
            }

            /// Maximum expansion relative to compressed bytes received so far.
            public static func ratio(_ ratio: Int) -> Self {
                precondition(ratio > 0, "Decompression ratio must be positive")
                return Self(storage: .ratio(ratio))
            }

            func exceeded(compressed: Int, decompressed: Int) -> Bool {
                switch self.storage {
                case .none: false
                case .size(let maximum): decompressed > maximum
                case .ratio(let ratio):
                    // Overflow means the permitted expansion exceeds any representable body size.
                    if case (let maximum, false) = compressed.multipliedReportingOverflow(by: ratio) {
                        decompressed > maximum
                    } else {
                        false
                    }
                }
            }
        }
    }
}
