/// Capable of mapping Swift key path's to Fluent query fields.
public protocol KeyStringMappable {
    /// Maps key paths to their codable key.
    static var keyStringMap: KeyStringMap { get }
}

extension KeyStringMappable {
    /// Maps a model's key path to AnyKeyPath.
    public static func key<T, K: KeyPath<Self, T>>(_ path: K) -> Key {
        return Key(path: path, type: T.self, isOptional: false)
    }

    /// Maps a model's key path to AnyKeyPath.
    public static func key<T, K: KeyPath<Self, Optional<T>>>(_ path: K) -> Key {
        return Key(path: path, type: T.self, isOptional: true)
    }
}
