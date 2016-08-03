import HTTP

enum ExtractError: Swift.Error {
    case unexpectedNil
}

extension KeyAccessible where Key == String, Value == String {
    /**
        Extract and transform values from [String: String] dictionaries 
         tto StringInitializable types
    */
    public func extract<S: StringInitializable>(_ key: String) throws -> S {
        guard let val = try self[key].flatMap({ try S(from: $0) }) else {
            throw ExtractError.unexpectedNil
        }
        return val
    }
}
