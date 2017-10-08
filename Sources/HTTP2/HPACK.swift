
import HTTP
import Foundation

public final class Packet {
    var data: Data
    var bytePosition = 0
    var bitPosition = 0
    
    init(data: Data = Data()) {
        self.data = data
    }
}

public final class HPACK {
    public func inputStream(_ packet: Packet) throws {
        
    }
}

struct Error: Swift.Error {
    let problem: Problem
    
    init(_ problem: Problem) {
        self.problem = problem
    }
    
    enum Problem {
        case unexpectedEOF
        case invalidPrefixSize(Int)
    }
}
