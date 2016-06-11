extension Stream {
	/**
        Reads and filters non-valid ASCII characters
        from the stream until a new line character is returned.
    */
    func nextLine() throws -> Bytes {
        var line: Bytes = []

        var lastByte: Byte? = nil

        while let byte = try next() {
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
		Receives a chunk from the stream of a certain length.
    */
    func next(chunk size: Int) throws -> Bytes {
        var bytes: Bytes = []

        for _ in 0 ..< size {
            if let byte = try next() {
                bytes += byte
            }
        }

        return bytes
    }

    public func next() throws -> Byte? {
    	return try receive(upTo: 1).first
    }

}
