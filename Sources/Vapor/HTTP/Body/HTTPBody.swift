public enum HTTPBody {
    case data(Bytes)
    case chunked((ChunkStream) throws -> Void)
}
