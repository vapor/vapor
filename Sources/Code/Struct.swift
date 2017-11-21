public class Struct: Encodable {
    public var name: String
    public var properties: [Property]
    public var methods: [Method]

    init(name: String, properties: [Property], methods: [Method]) {
        self.name = name
        self.properties = properties
        self.methods = methods
    }
}
