import Async

public final class Var: Tag {
    public init() {}

    public func render(parsed: ParsedTag, context: inout Context, renderer: Renderer) throws -> Future<Context?> {
        let promise = Promise(Context?.self)

        func updateContext(with c: Context) {
            context = c
        }

        if case .dictionary(var dict) = context {
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
                    queue: parsed.queue
                )
                try serializer.serialize().then { rendered in
                    dict[key] = .data(rendered)
                    updateContext(with: .dictionary(dict))
                    promise.complete(nil)
                }.catch { error in
                    promise.fail(error)
                }
            case 2:
                guard let key = parsed.parameters[0].string else {
                    throw parsed.error(reason: "Unsupported key type")
                }
                dict[key] = parsed.parameters[1]
                updateContext(with: .dictionary(dict))
                promise.complete(nil)
            default:
                try parsed.requireParameterCount(2)
            }
        } else {
            promise.complete(nil)
        }

        return promise.future
    }
}
