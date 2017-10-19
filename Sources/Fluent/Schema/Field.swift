public struct Field {
    /// The name of this field.
    public var name: String

    /// The type of field.
    public var type: FieldType
}

public enum FieldType {
    case string
    case custom(String)
}
