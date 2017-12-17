public struct SchemaForeignKey {
    public var name: String
    public var local: DataColumn
    public var foreign: DataColumn
    public var onUpdate: String
    public var onDelete: String

    public init(name: String, local: DataColumn, foreign: DataColumn, onUpdate: String, onDelete: String) {
        self.name = name
        self.local = local
        self.foreign = foreign
        self.onUpdate = onUpdate
        self.onDelete = onDelete
    }
}
