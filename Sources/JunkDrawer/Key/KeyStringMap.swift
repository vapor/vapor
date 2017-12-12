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
        self.init(keys: elements)
    }

    /// When there are too much keys, Swift won't be able to infer dictionary literal as KeyStringMap.
    ///
    /// When Swift fails to infer it, the error looks like:
    /// "Expression was too complex to be solved in reasonable time; consider breaking up the expression into distinct sub-expressions"
    ///
    /// Example:
    ///
    /// ```
    /// static var keyStringMap: KeyStringMap {
    ///   let keys: [(Key, String)] = [
    ///       (key(\.id), "id"),
    ///       // ... other keys
    ///   ]
    ///
    ///   return KeyStringMap(keys: keys)
    /// }
    /// ```
    public init(keys elements: [(Key, String)]) {
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
