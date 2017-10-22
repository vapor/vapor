import HTTP
import Pufferfish

extension Request {
    func headerFrames(for stream: HTTP2Stream) -> [Frame] {
        // TODO: Support Padding, Stream Dependencies and priorities
        
        var frames = [Frame]()
        
        HuffmanEncoder.hpack.encode(data: <#T##Data#>)
    }
}
