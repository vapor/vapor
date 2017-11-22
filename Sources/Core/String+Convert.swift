import Debugging

extension String {
    /// Convert self to any type that conforms to LosslessStringConvertible
    func convertTo<T: LosslessStringConvertible>(_ type: T.Type) throws -> T {
        guard let converted = T.self.init(self) else {
            throw ConversionError(
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

/// An error converting types.
public struct ConversionError: Debuggable, Error {
    /// See Debuggable.reason
    public var reason: String

    /// See Debuggable.identifier
    public var identifier: String

    fileprivate init(identifier: String, reason: String) {
        self.reason = reason
        self.identifier = identifier
    }
}
