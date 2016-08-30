@_exported import Polymorphic

extension Config: Polymorphic {
    public var isNull: Bool { return node.isNull }
    public var bool: Bool? { return node.bool }
    public var double: Double? { return node.double }
    public var int: Int? { return node.int }
    public var string: String? { return node.string }
    public var array: [Polymorphic]? { return node.array }
    public var object: [String: Polymorphic]? { return node.object }
}
