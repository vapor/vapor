public struct SchemaColumn {
    public var name: String
    public var dataType: String
    public var isNotNull: Bool
    public var isPrimaryKey: Bool

    public init(
        name: String,
        dataType: String,
        isNotNull: Bool = true,
        isPrimaryKey: Bool = false
    ) {
        self.name = name
        self.dataType = dataType
        self.isNotNull = isNotNull
        self.isPrimaryKey = isPrimaryKey
    }
}
