public class Enum: Encodable {
    public var name: String
    public var cases: [EnumCase]

    public init(name: String, cases: [EnumCase]) {
        self.name = name
        self.cases = cases
    }
}


public struct EnumCase: Encodable {
    public var name: String
}
