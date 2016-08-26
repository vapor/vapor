/**
    RouteGroups store a prefix map, hard coded path,
    and value map that are added to the underlying
    RouteBuilder when used.
*/
public class RouteGroup<Wrapped, Builder: RouteBuilder> where Builder.Value == Wrapped {
    /**
        A closure that maps values
        to other values, useful for middleware.
    */
    public typealias Map = (Value) -> (Value)

    /**
        The underlying RouteBuilder.
        All route building calls sent to 
        the group will end up here.
    */
    public let builder: Builder

    /**
        An optional array of strings
        for overriding parts of the path.
    */
    public let prefix: [String?]

    /**
        An array of Strings the will
        be added between the prefix
        and the incoming paths.
    */
    public let path: [String]

    /**
        An optional value map.
    */
    public let map: Map?

    /**
        Creates a RouteGroup. This should normally
        be done using the `.group` or `.grouped`
        calls on `RouteBuilder`.
    */
    init(
        builder: Builder,
        prefix: [String?],
        path: [String],
        map: Map?
    ) {
        self.builder = builder
        self.prefix = prefix
        self.path = path
        self.map = map
    }
}
