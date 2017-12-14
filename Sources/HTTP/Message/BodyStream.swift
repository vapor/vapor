import Async
import Bits

/// A stream of Bytes used for HTTP bodies
///
/// In HTTP/1 this becomes chunk encoded data
public typealias BodyStream = BasicStream<ByteBuffer>

