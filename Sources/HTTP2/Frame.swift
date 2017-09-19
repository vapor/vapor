import Foundation

public struct Frame {
    public enum FrameType: UInt8 {
        case a = 0
    }
    
    public struct Flags: OptionSet {
        public var rawValue: UInt8
        
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
        
        public static func ==(lhs: Frame.Flags, rhs: Frame.Flags) -> Bool {
            return lhs.rawValue == rhs.rawValue
        }
    }
    
    public private(set) var length: UInt32
    public private(set) var type: FrameType
    public private(set) var flags: Flags
    public private(set) var streamIdentifier: UInt32
    public private(set) var payload: Data
}


