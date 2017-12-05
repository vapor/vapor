public class Extension {
    public let typeName: String
    public var properties: [Property]
    public var methods: [Method]
    public var inheritedTypes: [String]
    public var comment: Comment?

    init(
        typeName: String,
        properties: [Property],
        methods: [Method],
        inheritedTypes: [String],
        comment: Comment?
    ) {
        self.typeName = typeName
        self.properties = properties
        self.methods = methods
        self.inheritedTypes = inheritedTypes
        self.comment = comment
    }
}

