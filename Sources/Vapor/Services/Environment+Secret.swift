public extension Environment {

    /// Reads a file content for a secret. The secret key represents the name of the environment variable that holds the path for the file containing the secret
    /// - Parameter key: Environment name for the path to the file containing the secret
    /// - Parameter container: Container for handling the file reading and event loop
    /// - Throws: Error.environmentVariableNotFound if the environment variable with the key name does not exist
    static func secret(key: String, container: Container) throws -> EventLoopFuture<String> {
        guard let filePath = self.get(key) else { throw Error.environmentVariableNotFound }
        return try secret(path: filePath, container: container)
    }


    /// Reads a file content for a secret. The path is a file path to the file that contains the secret in plain text
    /// - Parameter path: Path to the file that contains the secret
    /// - Parameter container: Container for handling the file reading and event loop
    /// - Throws: Error.environmentVariableNotFound if the environment variable with the key name does not exist
    static func secret(path: String, container: Container) throws -> EventLoopFuture<String> {
        let fileio = try container.make(NonBlockingFileIO.self)
        let eventLoop = container.eventLoop
        return fileio
            .openFile(path: path, eventLoop: eventLoop)
            .flatMap({ (arg) -> EventLoopFuture<ByteBuffer> in
                return fileio
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

