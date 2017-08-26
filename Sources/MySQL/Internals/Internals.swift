/// Keeps track of capabilities. Which can be the server's, client's or combined capabilities
struct Capabilities : OptionSet, ExpressibleByIntegerLiteral {
    var rawValue: UInt32
    
    static let protocol41: Capabilities = 0x0200
    static let longFlag: Capabilities = 0x0004
    static let connectWithDB: Capabilities = 0x0008
    static let secureConnection: Capabilities = 0x8000
    
    init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    init(integerLiteral value: UInt32) {
        self.rawValue = value
    }
}
