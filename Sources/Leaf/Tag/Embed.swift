import Async

public final class Embed: LeafTag {
    public init() {}
    public func render(parsed: ParsedTag, context: LeafContext, renderer: LeafRenderer) throws -> Future<LeafData?> {
        try parsed.requireParameterCount(1)
        let name = parsed.parameters[0].string ?? ""
        let copy = context

        let promise = Promise(LeafData?.self)

        renderer.render(path: name, context: copy).do { data in
            promise.complete(.data(data))
        }.catch { error in
            promise.fail(error)
        }

        return promise.future
    }
}


