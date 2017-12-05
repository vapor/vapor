import Async

public final class Var: LeafTag {
    public init() {}

    public func render(parsed: ParsedTag, context: LeafContext, renderer: LeafRenderer) throws -> Future<LeafData?> {
        let promise = Promise(LeafData?.self)

        var dict = context.data.dictionary ?? [:]
        switch parsed.parameters.count {
        case 1:
            let body = try parsed.requireBody()
            guard let key = parsed.parameters[0].string else {
                throw parsed.error(reason: "Unsupported key type")
            }

            let serializer = Serializer(
                ast: body,
                renderer: renderer,
                context: context,
                on: parsed.eventLoop
            )
            serializer.serialize().do { rendered in
                dict[key] = .data(rendered)
                context.data = .dictionary(dict)
                promise.complete(nil)
            }.catch { error in
                promise.fail(error)
            }
        case 2:
            guard let key = parsed.parameters[0].string else {
                throw parsed.error(reason: "Unsupported key type")
            }
            dict[key] = parsed.parameters[1]
            context.data = .dictionary(dict)
            promise.complete(nil)
        default:
            try parsed.requireParameterCount(2)
        }

        return promise.future
    }
}
