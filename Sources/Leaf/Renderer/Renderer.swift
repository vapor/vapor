import Async
import Core
import Dispatch
import Foundation

/// Renders Leaf templates using the Leaf parser and serializer.
public final class Renderer {
    /// The tags available to this renderer.
    public let tags: [String: Tag]

    /// The renderer will use this to read files for
    /// tags that require it (such as #embed)
    private var _files: [Int: FileReader & FileCache]

    /// Create a file reader & cache for the supplied queue
    public typealias FileFactory = (DispatchQueue) -> (FileReader & FileCache)
    private let fileFactory: FileFactory

    /// Create a new Leaf renderer.
    public init(tags: [String: Tag], fileFactory: @escaping FileFactory) {
        self.tags = tags
        self._files = [:]
        self.fileFactory = fileFactory
    }

    // ASTs only need to be parsed once
    private var _cachedASTs: [Int: [Syntax]] = [:]

    /// Renders the supplied template bytes into a view
    /// using the supplied context.
    public func render(template: Data, context: LeafData, on worker: Worker) -> Future<Data> {
        let hash = template.hashValue

        let promise = Promise(Data.self)

        let ast: [Syntax]
        if let cached = _cachedASTs[hash] {
            ast = cached
        } else {
            let parser = Parser(data: template)
            do {
                ast = try parser.parse()
            } catch let error as ParserError {
                promise.fail(RenderError(source: error.source, reason: error.reason, error: error))
                return promise.future
            } catch {
                promise.fail(error)
                return promise.future
            }
            _cachedASTs[hash] = ast
        }


        let serializer = Serializer(
            ast: ast,
            renderer: self,
            context: context,
            worker: worker
        )

        serializer.serialize().then { data in
            promise.complete(data)
        }.catch { err in
            if let serr = err as? SerializerError {
                promise.fail(RenderError(source: serr.source, reason: serr.reason, error: serr))
            } else if let terr = err as? TagError {
                promise.fail(RenderError(source: terr.source, reason: terr.reason, error: terr))
            } else {
                promise.fail(err)
            }
        }

        return promise.future
    }
}

// MARK: View

extension Renderer: ViewRenderer {
    /// See ViewRenderer.make
    public func make(_ path: String, context: Encodable, on worker: Worker) throws -> Future<View> {
        let encoder = LeafDataEncoder()
        try context.encode(to: encoder)
        return render(path: path, context: encoder.context, on: worker).map { data in
            return View(data: data)
        }
    }
}

// MARK: Convenience

extension Renderer {
    /// Loads the leaf template from the supplied path.
    public func render(path: String, context: LeafData, on worker: Worker) -> Future<Data> {
        let path = path.hasSuffix(".leaf") ? path : path + ".leaf"
        let promise = Promise(Data.self)

        let file: FileReader & FileCache
        if let existing = _files[worker.eventLoop.queue.label.hashValue] {
            file = existing
        } else {
            file = fileFactory(worker.eventLoop.queue)
            _files[worker.eventLoop.queue.label.hashValue] = file
        }

        file.cachedRead(at: path).then { view in
            self.render(template: view, context: context, on: worker).then { data in
                promise.complete(data)
            }.catch { error in
                if var error = error as? RenderError {
                    error.path = path
                    promise.fail(error)
                } else {
                    promise.fail(error)
                }
            }
        }.catch { error in
            promise.fail(error)
        }

        return promise.future
    }

    /// Renders a string template and returns a string.
    public func render(_ view: String, context: LeafData, on worker: Worker) -> Future<String> {
        let promise = Promise(String.self)

        do {
            guard let data = view.data(using: .utf8) else {
                throw RenderError(
                    source: Source(line: 0, column: 0, range: 0..<view.characters.count),
                    reason: "Could not convert view String to Data."
                )
            }

            render(template: data, context: context, on: worker).then { rendered in
                do {
                    guard let string = String(data: rendered, encoding: .utf8) else {
                        throw RenderError(
                            source: Source(line: 0, column: 0, range: 0..<data.count),
                            reason: "Could not convert rendered template to String."
                        )
                    }

                    promise.complete(string)
                } catch {
                    promise.fail(error)
                }
            }.catch { error in
                promise.fail(error)
            }
        } catch {
            promise.fail(error)
        }

        return promise.future
    }
}
