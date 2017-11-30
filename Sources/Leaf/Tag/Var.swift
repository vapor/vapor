import Async

public final class Var: LeafTag {
    public init() {}

    public func render(parsed: ParsedTag, context: inout LeafData, renderer: LeafRenderer) throws -> Future<LeafData?> {
        let promise = Promise(LeafData?.self)

        func updateContext(with c: LeafData) {
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
                    serviceContext: parsed.serviceContext
                )
                serializer.serialize().do { rendered in
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
