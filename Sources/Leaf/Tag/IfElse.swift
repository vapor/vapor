import Async

public final class IfElse: Tag {
    public init() {}

    public func render(parsed: ParsedTag, context: inout LeafData, renderer: Renderer) throws -> Future<LeafData?> {
        try parsed.requireParameterCount(1)
        let body = try parsed.requireBody()
        let expr = parsed.parameters[0]

        let promise = Promise(LeafData?.self)
        if expr.bool != false {
            let serializer = Serializer(
                ast: body,
                renderer: renderer,
                context: context,
                worker: parsed.worker
            )
            serializer.serialize().do { bytes in
                promise.complete(.data(bytes))
            }.catch { error in
                promise.fail(error)
            }
        } else {
            promise.complete(nil)
        }

        return promise.future
    }
}
