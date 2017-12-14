import Async
import Dispatch
import Foundation

/// Serializes parsed Leaf ASTs into view bytes.
public final class Serializer {
    let ast: [Syntax]
    var context: LeafContext
    let renderer: LeafRenderer
    let eventLoop: EventLoop

    /// Creates a new Serializer.
    public init(ast: [Syntax], renderer: LeafRenderer,  context: LeafContext, on eventLoop: EventLoop) {
        self.ast = ast
        self.context = context
        self.renderer = renderer
        self.eventLoop = eventLoop
    }

    /// Serializes the AST into Bytes.
    func serialize() -> Future<Data> {
        var parts: [Future<Data>] = []

        for syntax in ast {
            let promise = Promise(Data.self)
            switch syntax.kind {
            case .raw(let data):
                promise.complete(data)
            case .tag(let name, let parameters, let body, let chained):
                renderTag(
                    name: name,
                    parameters: parameters,
                    body: body,
                    chained: chained,
                    source: syntax.source
                ).do { context in
                    guard let context = context else {
                        promise.complete(Data())
                        return
                    }

                    guard let data = context.data else {
                        promise.fail(SerializerError.unexpectedTagData(name: name, source: syntax.source))
                        return
                    }

                    promise.complete(data)
                }.catch { error in
                    promise.fail(error)
                }
            default:
                promise.fail(SerializerError.unexpectedSyntax(syntax))
            }
            parts.append(promise.future)
        }
        
        return parts.map(to: Data.self) { data in
            return Data(data.joined())
        }
    }

    // MARK: private

    // renders a tag using the supplied context
    private func renderTag(
        name: String,
        parameters: [Syntax],
        body: [Syntax]?,
        chained: Syntax?,
        source: Source
    ) -> Future<LeafData?> {
        return Future<LeafData?> {
            guard let tag = self.renderer.tags[name] else {
                throw SerializerError.unknownTag(name: name, source: source)
            }

            let inputFutures: [Future<LeafData>] = parameters.map { parameter in
                let inputPromise = Promise(LeafData.self)
                self.resolveSyntax(parameter).do { input in
                    inputPromise.complete(input ?? .null)
                }.catch { error in
                    inputPromise.fail(error)
                }
                return inputPromise.future
            }

            return inputFutures.flatMap(to: LeafData?.self) { inputs in
                let parsed = ParsedTag(
                    name: name,
                    parameters: inputs,
                    body: body,
                    source: source,
                    on: self.eventLoop
                )
                
                return try tag.render(
                    parsed: parsed,
                    context: self.context,
                    renderer: self.renderer
                ).flatMap(to: LeafData?.self) { data in
                    if let data = data {
                        return Future(data)
                    } else if let chained = chained {
                        switch chained.kind {
                        case .tag(let name, let params, let body, let c):
                            return self.renderTag(
                                name: name,
                                parameters: params,
                                body: body,
                                chained: c,
                                source: chained.source
                            )
                        default:
                            throw SerializerError.unexpectedSyntax(chained)
                        }
                    } else {
                        return Future(nil)
                    }
                }
            }
        }
    }

    // resolves a constant to data
    private func resolveConstant(_ const: Constant) -> Future<LeafData> {
        let promise = Promise(LeafData.self)
        switch const {
        case .bool(let bool):
            promise.complete(.bool(bool))
        case .double(let double):
            promise.complete(.double(double))
        case .int(let int):
            promise.complete(.int(int))
        case .string(let ast):
            let serializer = Serializer(
                ast: ast,
                renderer: renderer,
                context: context,
                on: eventLoop
            )
            serializer.serialize().do { bytes in
                promise.complete(.data(bytes))
            }.catch { error in
                promise.fail(error)
            }
        }
        return promise.future
    }

    // resolves an expression to data
    private func resolveExpression(_ op: Operator, left: Syntax, right: Syntax) -> Future<LeafData> {
        let l = resolveSyntax(left)
        let r = resolveSyntax(right)

        let promise = Promise(LeafData.self)

        switch op {
        case .equal:
            return l.flatMap(to: LeafData.self) { l in
                return r.map(to: LeafData.self) { r in
                    return .bool(l == r)
                }
            }
        case .notEqual:
            l.do { l in
                r.do { r in
                    promise.complete(.bool(l != r))
                }.catch { error in
                    promise.fail(error)
                }
            }.catch { error in
                promise.fail(error)
            }
        case .and:
            l.do { l in
                r.do { r in
                    promise.complete(.bool(l?.bool != false && r?.bool != false))
                }.catch { error in
                    promise.fail(error)
                }
            }.catch { error in
                promise.fail(error)
            }
        case .or:
            r.do { r in
                l.do { l in
                    promise.complete(.bool(l?.bool != false || r?.bool != false))
                }.catch { error in
                    promise.fail(error)
                }
            }.catch { error in
                promise.fail(error)
            }
        default:
            l.do { l in
                r.do { r in
                    if let leftDouble = l?.double, let rightDouble = r?.double {
                        switch op {
                        case .add:
                            promise.complete(.double(leftDouble + rightDouble))
                        case .subtract:
                            promise.complete(.double(leftDouble - rightDouble))
                        case .greaterThan:
                            promise.complete(.bool(leftDouble > rightDouble))
                        case .lessThan:
                            promise.complete(.bool(leftDouble < rightDouble))
                        case .multiply:
                            promise.complete(.double(leftDouble * rightDouble))
                        case .divide:
                            promise.complete(.double(leftDouble / rightDouble))
                        default:
                            promise.complete(.bool(false))
                        }
                    } else {
                        promise.complete(.bool(false))
                    }
                }.catch { error in
                    promise.fail(error)
                }
            }.catch { error in
                promise.fail(error)
            }
        }

        return promise.future
    }

    // resolves syntax to data (or fails)
    private func resolveSyntax(_ syntax: Syntax) -> Future<LeafData?> {
        let promise = Promise(LeafData?.self)

        switch syntax.kind {
        case .constant(let constant):
            resolveConstant(constant).do { data in
                promise.complete(data)
            }.catch { error in
                promise.fail(error)
            }
        case .expression(let op, let left, let right):
            resolveExpression(op, left: left, right: right).do { data in
                promise.complete(data)
            }.catch { error in
                promise.fail(error)
            }
        case .identifier(let id):
            contextFetch(path: id).do { value in
                promise.complete(value ?? .null)
            }.catch { error in
                promise.fail(error)
            }
        case .tag(let name, let parameters, let body, let chained):
            return renderTag(
                name: name,
                parameters: parameters,
                body: body,
                chained: chained,
                source: syntax.source
            )
        case .not(let syntax):
            switch syntax.kind {
            case .identifier(let id):
                let promise = Promise(LeafData?.self)
                contextFetch(path: id).do { data in
                    promise.complete(.bool(data?.bool == true))
                }.catch { error in
                    promise.fail(error)
                }
            case .constant(let c):
                switch c {
                case .bool(let bool):
                    promise.complete(.bool(!bool))
                case .double(let double):
                    promise.complete(.bool( double != 1))
                case .int(let int):
                    promise.complete(.bool(int != 1))
                case .string(_):
                    promise.fail(SerializerError.unexpectedSyntax(syntax))
                }
            default:
                promise.fail(SerializerError.unexpectedSyntax(syntax))
            }
        default:
            promise.fail(SerializerError.unexpectedSyntax(syntax))
        }

        return promise.future
    }

    // fetches data from the context
    private func contextFetch(path: [String]) -> Future<LeafData?> {
        var promise = Promise(LeafData?.self)

        var current = context.data
        var iterator = path.makeIterator()

        func handle(_ path: String) {
            switch current {
            case .dictionary(let dict):
                if let value = dict[path] {
                    current = value
                    if let next = iterator.next() {
                        handle(next)
                    } else {
                        promise.complete(current)
                    }
                } else {
                    promise.complete(nil)
                }
            case .future(let fut):
                fut.do { value in
                    current = value
                    handle(path)
                }.catch { error in
                    promise.fail(error)
                }
            default:
                promise.complete(nil)
            }
        }

        if let first = iterator.next() {
            handle(first)
        } else {
            promise.complete(current)
        }

        return promise.future
    }
}

