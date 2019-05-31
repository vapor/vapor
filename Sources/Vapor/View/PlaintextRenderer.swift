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
            return self.fileio.read(fileRegion: region, allocator: .init(), eventLoop: self.eventLoop).flatMapThrowing { buffer in
                try handle.close()
                return buffer
            }
            }.map { data in
                return View(data: data)
        }
    }
}
