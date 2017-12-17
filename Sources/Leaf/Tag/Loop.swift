import Async
import Foundation

public final class Loop: LeafTag {
    public init() {}
    public func render(parsed: ParsedTag, context: LeafContext, renderer: LeafRenderer) throws -> Future<LeafData?> {
        let promise = Promise(LeafData?.self)

        if case .dictionary(var dict) = context.data {
            let body = try parsed.requireBody()
            try parsed.requireParameterCount(2)
            let array = parsed.parameters[0].array ?? []
            let key = parsed.parameters[1].string ?? ""

            var results: [Future<Data>] = []

            // store the previous values of loop and key
            // so we can restore them once the loop is finished
            let prevLoop = dict["loop"]
            let prevKey = dict[key]

            for (i, item) in array.enumerated() {
                let isLast = i == array.count - 1
                let loop = LeafData.dictionary([
                    "index": .int(i),
                    "isFirst": .bool(i == 0),
                    "isLast": .bool(isLast)
                    ])
                dict["loop"] = loop
                dict[key] = item
                context.data = .dictionary(dict)
                let serializer = Serializer(
                    ast: body,
                    renderer: renderer,
                    context: context,
                    on: parsed.Worker
                )
                let subpromise = Promise(Data.self)
                serializer.serialize().do { bytes in
                    subpromise.complete(bytes)
                }.catch { error in
                    promise.fail(error)
                }
                results.append(subpromise.future)
            }

            results.flatten().do { datas in
                let data = Data(datas.joined())
                dict["loop"] = prevLoop
                dict[key] = prevKey
                context.data = .dictionary(dict)
                promise.complete(.data(data))
            }.catch { error in
                promise.fail(error)
            }
        } else {
            promise.complete(nil)
        }

        return promise.future
    }
}
