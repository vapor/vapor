public struct File: Service {
    let io: NonBlockingFileIO
    let eventLoop: EventLoop

    init(io: NonBlockingFileIO, on worker: Worker) {
        self.io = io
        self.eventLoop = worker.eventLoop
    }

    public func read(file: String, chunkSize: Int = NonBlockingFileIO.defaultChunkSize, onRead: @escaping (ByteBuffer) -> Future<Void>) -> Future<Void> {
        return Future.flatMap(on: eventLoop) {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: file), let fileSize = attributes[.size] as? NSNumber else {
                throw VaporError(identifier: "fileSize", reason: "Could not determine file size of: \(file)", source: .capture())
            }

            // FIXME: don't create a new allocator each time, use the one from this pipeline
            let _tmp = ByteBufferAllocator()

            let fd = try FileHandle(path: file)
            let done = self.io.readChunked(
                fileHandle: fd,
                byteCount: fileSize.intValue,
                chunkSize: chunkSize,
                allocator: _tmp,
                eventLoop: self.eventLoop
            ) { chunk in
                return onRead(chunk)
            }

            done.always {
                try? fd.close()
            }

            return done
        }
    }

    public func chunkedStream(file: String, chunkSize: Int = NonBlockingFileIO.defaultChunkSize) -> HTTPBody {
        let chunkStream = HTTPChunkedStream(on: eventLoop)
        read(file: file, chunkSize: chunkSize) { chunk in
            return chunkStream.write(.chunk(chunk))
        }.flatMap(to: Void.self) {
            return chunkStream.write(.end)
        }.catch { error in
            // we can't wait for the error
            _ = chunkStream.write(.error(error))
        }
        return HTTPBody(chunked: chunkStream)
    }
}
