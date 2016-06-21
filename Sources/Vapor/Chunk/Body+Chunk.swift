extension  HTTPBody {
    public init(_ chunker: (ChunkStream) throws -> Void) {
        self = .chunked(chunker)
    }
}
