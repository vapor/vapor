import Async

public final class IfElse: LeafTag {
    public init() {}

    public func render(parsed: ParsedTag, context: inout LeafData, renderer: LeafRenderer) throws -> Future<LeafData?> {
        try parsed.requireParameterCount(1)
        let body = try parsed.requireBody()
        let expr = parsed.parameters[0]

        let promise = Promise(LeafData?.self)
        if expr.bool != false {
            let serializer = Serializer(
                ast: body,
                renderer: renderer,
                context: context,
                serviceContext: parsed.serviceContext
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
