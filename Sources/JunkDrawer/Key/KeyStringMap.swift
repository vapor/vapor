/// Maps model keys to strings.
public struct KeyStringMap: ExpressibleByDictionaryLiteral {
    /// Store the key and query field.
    internal var storage: [AnyKeyPath: KeyString]

    /// Holds a key and it's associated string for
    internal struct KeyString {
        let key: Key
        let string: String
    }

    /// See ExpressibleByDictionaryLiteral
    public init(dictionaryLiteral elements: (Key, String)...) {
        self.storage = [:]
        for (key, string) in elements {
            storage[key.path] = KeyString(key: key, string: string)
        }
    }

    /// Access a query field for a given model key.
    public subscript(_ key: AnyKeyPath) -> String? {
        return storage[key]?.string
    }

    /// Returns the string for a given key path or throws
    /// and error if none exists
    public func requireString(for key: AnyKeyPath) throws -> String {
        guard let string = self[key] else {
            throw CoreError(
                identifier: "stringForKeyRequired",
                reason: "No string for key `\(key)` was found in the `KeyStringMap`."
            )
        }

        return string
    }
}
