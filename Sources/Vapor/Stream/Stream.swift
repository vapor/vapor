public protocol Stream: class, SendingStream {
    var timeout: Double { get set }

    var closed: Bool { get }
    func close() throws

    func send(_ bytes: Bytes) throws
    func flush() throws

    func receive(max: Int) throws -> Bytes
    func receive() throws -> Byte?
}

extension Stream {
	/**
        Reads and filters non-valid ASCII characters
        from the stream until a new line character is returned.
    */
    func receiveLine() throws -> Bytes {
        var line: Bytes = []

        var lastByte: Byte? = nil

        while let byte = try receive() {
            // Continues until a `crlf` sequence is found
            if byte == .newLine && lastByte == .carriageReturn {
                break
            }

            // Skip over any non-valid ASCII characters
            if byte > .carriageReturn {
                line += byte
            }

            lastByte = byte
        }

        return line
    }

    /**
        Default implementation of receive grabs a one
        byte array from the stream and returns the first.
     
        This can be overridden with something more performant.
    */
    func receive() throws -> Byte? {
        return try receive(max: 1).first
    }
}

extension Stream {
    func send(_ byte: Byte) throws {
        try send([byte])
    }

    func send(_ string: String) throws {
        try send(string.bytes)
    }
}

extension Stream {
    func sendLine() throws {
        try send([.carriageReturn, .newLine])
    }
}


extension Stream {
    public func send(_ data: Data, timingOut deadline: Double) throws {
        timeout = deadline
        try send(data.bytes)
    }

    public func flush(timingOut deadline: Double) throws {
        timeout = deadline
        try flush()
    }
}

