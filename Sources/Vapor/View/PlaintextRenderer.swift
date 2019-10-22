public struct PlaintextRenderer: ViewRenderer {
    public let eventLoopGroup: EventLoopGroup
    private let fileio: NonBlockingFileIO
    private let viewsDirectory: String

    public init(
        threadPool: NIOThreadPool,
        viewsDirectory: String,
        eventLoopGroup: EventLoopGroup
    ) {
        self.fileio = .init(threadPool: threadPool)
        self.viewsDirectory = viewsDirectory.finished(with: "/")
        self.eventLoopGroup = eventLoopGroup
    }

    public func render<E>(_ name: String, _ context: E) -> EventLoopFuture<View>
        where E: Encodable
    {
        let eventLoop = self.eventLoopGroup.next()
        let path = name.hasPrefix("/")
            ? name
            : self.viewsDirectory + name
        return self.fileio.openFile(path: path, eventLoop: eventLoop).flatMap { (handle, region) in
            return self.fileio.read(fileRegion: region, allocator: .init(), eventLoop: eventLoop).flatMapThrowing { buffer in
                try handle.close()
                return buffer
            }
        }.map { data in
            return View(data: data)
        }
    }
}
