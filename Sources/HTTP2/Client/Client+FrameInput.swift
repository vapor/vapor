extension HTTP2Client {
    /// Updates the frame's contents as settings, sends an acknowledgement
    ///
    /// TODO: Settings changed in the middle of the stream affecting the context
    /// TODO: Pause streams from processing?
    func processSettings(from frame: Frame) throws {
        guard frame.streamIdentifier == 0 else {
            throw HTTP2Error(.invalidStreamIdentifier)
        }
        
        if frame.flags & 0x01 == 0x01 {
            // Acknowledgement
            self.updatingSettings = false
            
            if !self.future.isCompleted {
                self.promise.complete(self)
            }
        } else {
            do {
                try self.remoteSettings.update(to: frame)
            } catch {
                self.context.serializer.onInput(ResetFrame(code: .frameSizeError, stream: frame.streamIdentifier).frame)
                return
            }
            self.context.serializer.onInput(HTTP2Settings.acknowledgeFrame)
        }
    }
    
    /// Processes frames targeted at the stream ID `0`, which is the global context
    func processTopLevelStream(from frame: Frame) throws {
        guard
            frame.type == .settings || frame.type == .ping  ||
            frame.type == .priority || frame.type == .reset ||
            frame.type == .goAway   || frame.type == .windowUpdate
        else {
            throw HTTP2Error(.invalidStreamIdentifier)
        }
        
        switch frame.type {
        case .settings:
            try self.processSettings(from: frame)
        case .ping:
            frame.flags = 0x01
            self.context.serializer.onInput(frame)
        case .priority:
            // TODO: In the future this can be used for processing order
            break
        case .reset:
            self.close()
        case .goAway:
            // TODO: Continue streams below treshold
            self.close()
        case .windowUpdate:
            let update = try WindowUpdate(frame: frame, errorsTo: self.context.serializer)
            
            if let windowSize = context.windowSize {
                context.windowSize = windowSize &+ numericCast(update.windowSize) as UInt64
            } else {
                context.windowSize = numericCast(update.windowSize)
            }
        default:
            throw HTTP2Error(.invalidStreamIdentifier)
        }
    }
}
