import Leaf

public final class LocalizeTag: Tag {
    public let name = "localize"
    
    public func run(
        stem: Stem,
        context: Context,
        tagTemplate: TagTemplate,
        arguments: [Argument]) throws -> Node? {
        // temporary escaping mechanism.
        // ALL tags are interpreted, use `*()` to have an empty `*` rendered
        if arguments.isEmpty { return .string([TOKEN].string) }
        guard arguments.count == 1 else { throw Error.expectedOneArgument }
        return arguments[0].value
    }
}
