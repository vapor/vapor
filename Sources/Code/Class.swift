public class Class: Encodable {
    public let name: String
    public var properties: [Property]
    public var methods: [Method]
    public var inheritedTypes: [String]
    public var comment: Comment?

    init(
        name: String,
        properties: [Property],
        methods: [Method],
        inheritedTypes: [String],
        comment: Comment?
    ) {
        self.name = name
        self.properties = properties
        self.methods = methods
        self.inheritedTypes = inheritedTypes
        self.comment = comment
    }
}

extension Class: CustomStringConvertible {
    /// See CustomStringConvertible.description
    public var description: String {
        return "class \(name) { }"
    }
}
