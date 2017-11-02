public struct SchemaColumn {
    public var name: String
    public var dataType: SchemaDataType
    public var isNotNull: Bool
    public var isPrimaryKey: Bool

    public init(
        name: String,
        dataType: SchemaDataType,
        isNotNull: Bool = true,
        isPrimaryKey: Bool = false
    ) {
        self.name = name
        self.dataType = dataType
        self.isNotNull = isNotNull
        self.isPrimaryKey = isPrimaryKey
    }
}

public enum SchemaDataType {
    case character(Int)
    case varchar(Int)
    case binary(Int)
    case boolean
    case varbinary(Int)
    case integer(Int)
    case decimal(Int, Int)
    case float(Int)
    case date
    case time
    case timestamp
    case interval
    case array
    case multiset
    case xml
    case custom(String)
}
