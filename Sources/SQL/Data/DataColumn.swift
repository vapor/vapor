public struct DataColumn {
    public let table: String?
    public let name: String

    public init(table: String? = nil, name: String) {
        self.table = table
        self.name = name
    }
}
