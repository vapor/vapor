import HTTP

extension KeyAccessible where Key == String, Value == String {
    /**
        Extract and transform values from [String: String] dictionaries 
        to StringInitializable types
    */
    public func extract<S: StringInitializable>(_ key: String) throws -> S? {
        return try self[key].flatMap { try S(from: $0) }
    }
}
