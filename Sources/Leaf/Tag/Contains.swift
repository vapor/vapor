import Core

public final class Contains: Leaf.Tag {
    public func render(parsed: ParsedTag, context: inout Context, renderer: Renderer) throws -> Future<Context?> {
        let promise = Promise(Context?.self)

        try parsed.requireParameterCount(2)

        if let array = parsed.parameters[0].array {
            let compare = parsed.parameters[1]
            promise.complete(.bool(array.contains(compare)))
        } else {
            promise.complete(.bool(false))
        }

        return promise.future
    }
}
