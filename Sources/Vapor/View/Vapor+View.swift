public protocol ViewRenderer {
    var eventLoop: EventLoop { get }
    func render<E>(_ name: String, _ context: E) -> EventLoopFuture<View>
        where E: Encodable
}

extension ViewRenderer {
    public func render(_ name: String) -> EventLoopFuture<View> {
        return self.render(name, [String: String]())
    }
}

public struct View: ResponseEncodable {
    public var data: ByteBuffer

    public init(data: ByteBuffer) {
        self.data = data
    }

    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let response = Response()
        response.headers.contentType = .html
        response.body = .init(buffer: self.data)
        return request.eventLoop.makeSucceededFuture(response)
    }
}

public struct PlaintextRenderer: ViewRenderer {
    public let eventLoop: EventLoop
    private let fileio: NonBlockingFileIO
    private let viewsDirectory: String

    public init(
        threadPool: NIOThreadPool,
        viewsDirectory: String,
        eventLoop: EventLoop
    ) {
        self.fileio = .init(threadPool: threadPool)
        self.viewsDirectory = viewsDirectory.finished(with: "/")
        self.eventLoop = eventLoop
    }

    public func render<E>(_ name: String, _ context: E) -> EventLoopFuture<View>
        where E: Encodable
    {
        let path = name.hasPrefix("/")
            ? name
            : self.viewsDirectory + name
        return self.fileio.openFile(path: path, eventLoop: self.eventLoop).flatMap { (handle, region) in
            return self.fileio.read(fileRegion: region, allocator: .init(), eventLoop: self.eventLoop)
        }.map { data in
            return View(data: data)
        }
    }
}
