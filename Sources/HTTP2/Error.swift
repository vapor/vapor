import Bits
import Foundation

struct HTTP2Error: Swift.Error {
    let problem: Problem
    
    init(_ problem: Problem) {
        self.problem = problem
    }
    
    enum Problem {
        case unexpectedEOF
        case invalidFrameReceived
        case invalidSettingsFrame(Frame)
        case invalidPrefixSize(Int)
        case invalidUTF8String
        case alpnNotSupported
        case invalidUpgrade
        case clientError
        case tooManyConnectionReuses
        case invalidStreamIdentifier
        case maxHeaderTableSizeOverridden(max: Int, updatedTo: Int)
        case invalidTableIndex(Int)
    }
}

struct ResetFrame {
    enum ErrorCode: Int32 {
        case noError = 0
        case protocolError = 1
        case internalError = 2
        case flowControlError = 3
        case settingsTimeout = 4
        case streamClosed = 5
        case frameSizeError = 6
        /// http://httpwg.org/specs/rfc7540.html#Reliability
        case refusedStream = 7
        case cancel = 8
        case compressionError = 9
        case connectError = 10
        case enhanceYourCalm = 11
        case inadequateSecurity = 12
        case http11Required = 13
    }
    
    var code: ErrorCode
    var streamID: Int32
    
    init(code: ErrorCode, stream: Int32) {
        self.code = code
        self.streamID = stream
    }
    
    var frame: Frame {
        var data = Data([0,0,0,0])
        var id = streamID
        
        data.withUnsafeMutableBytes { pointer in
            _ = memcpy(pointer, &id, 4)
        }
        
        return Frame(type: .reset, payload: Payload(data: data), streamID: streamID)
    }
}
