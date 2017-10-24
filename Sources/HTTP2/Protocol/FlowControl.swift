/// Updates the maximum window size I.E. maximum amount of bytes sent by the client
///
/// The server manages how much data the client is able to send/upload
struct WindowUpdate {
    init(frame: Frame, errorsTo serializer: FrameSerializer) throws {
        guard frame.payload.data.count == 4 else {
            serializer.inputStream(
                ResetFrame(code: .frameSizeError, stream: frame.streamIdentifier).frame
            )
            
            throw Error(.invalidSettingsFrame(frame))
        }
        
        self.windowSize = frame.payload.data.withUnsafeBytes { (pointer: UnsafePointer<Int32>) in
            return pointer.pointee
        }
        
        guard self.windowSize > 0 else {
            serializer.inputStream(
                ResetFrame(code: .protocolError, stream: frame.streamIdentifier).frame
            )
            
            throw Error(.invalidFrameReceived)
        }
    }
    
    /// The additional data that can be sent (in payloads) since the previous frame
    var windowSize: Int32
}
