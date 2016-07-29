public class RouteGroup<Wrapped, Builder: RouteBuilder where Builder.Value == Wrapped> {
    public typealias Filter = (Value) -> (Value)

    public let builder: Builder
    public let prefix: [String?]
    public let path: [String]
    public let filter: Filter?

    init(
        builder: Builder,
        prefix: [String?],
        path: [String],
        filter: Filter?
    ) {
        self.builder = builder
        self.prefix = prefix
        self.path = path
        self.filter = filter
    }
}
