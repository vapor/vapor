public struct Structure {
    public var name: String
    public var kind: StructureKind
    public var subStructures: [Structure]
    public var accessibility: Accessibility
    public var inheritedTypes: [String]
    public var comments: [String]?

    init(
        name: String,
        kind: StructureKind,
        subStructures: [Structure],
        accessibility: Accessibility,
        inheritedTypes: [String],
        comments: [String]?
    ) {
        self.name = name
        self.kind = kind
        self.subStructures = subStructures
        self.inheritedTypes = inheritedTypes
        self.accessibility = accessibility
        self.comments = comments
    }
}

public enum StructureKind {
    case `enum`
    case `class`
    case `struct`
    case `extension`
    case `var`(typeName: String, isInstance: Bool)
    case method(isInstance: Bool)
    case enumcase
    case enumelement
}

public enum Accessibility {
    case `private`
    case `internal`
    case `public`
}
