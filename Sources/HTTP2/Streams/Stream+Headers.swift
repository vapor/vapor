import HTTP
import Pufferfish

extension HTTPRequest {
    func headerFrames(for stream: HTTP2Stream) throws -> [Frame] {
        // TODO: Support Padding, Stream Dependencies and priorities
        
        return try stream.context.remoteHeaders.encode(
            request: self,
            chunksOf: numericCast(stream.context.parser.settings.maxFrameSize), // TODO: 32-bit systems?
            streamID: stream.identifier
        )
    }
}
