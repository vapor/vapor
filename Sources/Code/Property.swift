public struct Property: Encodable {
    public var name: String
    public var typeName: String
    public var isInstance: Bool
    public var comment: Comment?

    init(name: String, typeName: String, isInstance: Bool, comment: Comment?) {
        self.name = name
        self.typeName = typeName
        self.isInstance = isInstance
        self.comment = comment
    }
}
