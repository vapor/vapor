public extension Environment {

    /// Reads a file content for a secret. The secret key represents the name of the environment variable that holds the path for the file containing the secret
    /// - Parameter key: Environment name for the path to the file containing the secret
    /// - Parameter fileIO: FileIO handler provided by NIO
    /// - Parameter on: EventLoop to operate on while opening the file
    /// - Throws: Error.environmentVariableNotFound if the environment variable with the key name does not exist
    static func secret(key: String, fileIO: NonBlockingFileIO, on eventLoop: EventLoop) throws -> EventLoopFuture<String> {
        guard let filePath = self.get(key) else { throw Error.environmentVariableNotFound }
        return try secret(path: filePath, fileIO: fileIO, on: eventLoop)
    }


    /// Reads a file content for a secret. The path is a file path to the file that contains the secret in plain text
    /// - Parameter path: Path to the file that contains the secret
    /// - Parameter fileIO: FileIO handler provided by NIO
    /// - Parameter on: EventLoop to operate on while opening the file
    /// - Throws: Error.environmentVariableNotFound if the environment variable with the key name does not exist
    static func secret(path: String, fileIO: NonBlockingFileIO, on eventLoop: EventLoop) throws -> EventLoopFuture<String> {
        return fileIO
            .openFile(path: path, eventLoop: eventLoop)
            .flatMap({ (arg) -> EventLoopFuture<ByteBuffer> in
                return fileIO
                    .read(fileRegion: arg.1, allocator: .init(), eventLoop: eventLoop)
                    .map({ (buffer) -> ByteBuffer in
                        try? arg.0.close()
                        return buffer
                    })
            })
            .map({ (buffer) -> (String) in
                var buffer = buffer
                return buffer.readString(length: buffer.writerIndex) ?? ""
            })
    }

    enum Error: Swift.Error {
        case environmentVariableNotFound
    }
}

