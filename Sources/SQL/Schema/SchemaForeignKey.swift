public struct SchemaForeignKey {
    public var name: String
    public var local: DataColumn
    public var foreign: DataColumn

    public init(name: String, local: DataColumn, foreign: DataColumn) {
        self.name = name
        self.local = local
        self.foreign = foreign
    }
}
