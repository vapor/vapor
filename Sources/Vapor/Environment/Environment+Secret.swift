extension Environment {
    /// Reads a file content for a secret. The secret key represents the name of the environment variable that holds the path for the file containing the secret
    /// - Parameters:
    ///     - key: Environment name for the path to the file containing the secret
    ///     - fileIO: FileIO handler provided by NIO
    ///     - on: EventLoop to operate on while opening the file
    /// - Throws: Error.environmentVariableNotFound if the environment variable with the key name does not exist
    public static func secret(key: String, fileIO: NonBlockingFileIO, on eventLoop: EventLoop) -> EventLoopFuture<String?> {
        guard let filePath = self.get(key) else { return eventLoop.future(nil) }
        return self.secret(path: filePath, fileIO: fileIO, on: eventLoop)
    }


    /// Reads a file content for a secret. The path is a file path to the file that contains the secret in plain text
    /// - Parameters:
    ///     - path: Path to the file that contains the secret
    ///     - fileIO: FileIO handler provided by NIO
    ///     - on: EventLoop to operate on while opening the file
    /// - Throws: Error.environmentVariableNotFound if the environment variable with the key name does not exist
    public static func secret(path: String, fileIO: NonBlockingFileIO, on eventLoop: EventLoop) -> EventLoopFuture<String?> {
        return fileIO
            .openFile(path: path, eventLoop: eventLoop)
            .flatMap({ (arg) -> EventLoopFuture<ByteBuffer> in
                return fileIO
                    .read(fileRegion: arg.1, allocator: .init(), eventLoop: eventLoop)
                    .flatMapThrowing({ (buffer) -> ByteBuffer in
                        try arg.0.close()
                        return buffer
                    })
            })
            .map({ (buffer) -> (String) in
                var buffer = buffer
                return buffer.readString(length: buffer.writerIndex) ?? ""
            })
            .map({ (secret) -> (String) in
                secret.trimmingCharacters(in: .whitespacesAndNewlines)
            })
            .recover ({ (_) -> String? in
                nil
            })
    }
}

