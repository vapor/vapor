import Core

public final class Lowercase: Leaf.Tag {
    public init() {}
    public func render(parsed: ParsedTag, context: inout Context, renderer: Renderer) throws -> Future<Context?> {
        try parsed.requireParameterCount(1)
        let string = parsed.parameters[0].string?.lowercased() ?? ""

        let promise = Promise(Context?.self)
        promise.complete(.string(string))
        return promise.future
    }
}
