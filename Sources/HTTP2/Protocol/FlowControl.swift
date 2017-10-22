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
    
    var windowSize: Int32
}
