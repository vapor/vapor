import Core

public final class Embed: Tag {
    public init() {}
    public func render(parsed: ParsedTag, context: inout Context, renderer: Renderer) throws -> Future<Context?> {
        try parsed.requireParameterCount(1)
        let name = parsed.parameters[0].string ?? ""
        let copy = context

        let promise = Promise(Context?.self)

        renderer.render(path: name, context: copy, on: parsed.queue).then { data in
            promise.complete(.data(data))
        }.catch { error in
            promise.fail(error)
        }

        return promise.future
    }
}


