/// Represents a field computed by passing
/// one or more fields into a function and yielding
/// the result as "key"
public struct ComputedField {
    /// The function to call
    public let function: String
    /// The fields that will be passed to the function
    public let fields: [String]
    /// Name for the function's result
    public let key: String
    
    /// Creates a new computed field
    public init(function: String, fields: [String] = [], key: String) {
        self.function = function
        self.fields = fields
        self.key = key
    }
    
    /// Creates a new computed field
    /// that only takes one input field
    public init(function: String, field: String, key: String) {
        self.init(function: function, fields: [field], key: key)
    }
}
