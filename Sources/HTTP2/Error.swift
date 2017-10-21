struct Error: Swift.Error {
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
        case invalidUpgrade
        case invalidStreamIdentifier
        case maxHeaderTableSizeOverridden(max: Int, updatedTo: Int)
        case invalidStaticTableIndex(Int)
    }
}
