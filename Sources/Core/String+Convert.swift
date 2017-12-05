import Debugging

extension String {
    /// Convert self to any type that conforms to LosslessStringConvertible
    func convertTo<T: LosslessStringConvertible>(_ type: T.Type) throws -> T {
        guard let converted = T.self.init(self) else {
            throw CoreError(
                identifier: "string",
                reason: "Unable to convert \(self) to \(T.self)"
            )
        }

        return converted
    }
}

extension String {
    /// Converts the string to a boolean or return nil.
    public var bool: Bool? {
        switch self {
        case "true", "yes", "1": return true
        case "false", "no", "0": return false
        default: return nil
        }
    }
}

extension String {
    /// Ensures a string has a strailing suffix w/o duplicating
    ///
    ///     "hello.jpg".finished(with: ".jpg") // hello.jpg
    ///     "hello".finished(with: ".jpg") // hello.jpg
    ///
    public func finished(with end: String) -> String {
        guard !self.hasSuffix(end) else { return self }
        return self + end
    }
}

/// Capable of being decoded from a string.
public protocol StringDecodable {
    /// Decode self from a string.
    static func decode(from string: String) -> Self?
}
